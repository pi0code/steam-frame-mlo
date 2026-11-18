#!/usr/bin/env python3
"""Run synthetic SERVICE_READY_EXT2 events through the ath12k source under test."""

import errno
import pathlib
import re
import struct
import subprocess
import sys
import tempfile


def declaration(source, name):
    start = re.search(r"^" + re.escape(name) + r" \{", source, re.MULTILINE).start()
    end = re.search(r"^\}(?: __packed)?;", source[start:], re.MULTILINE).end()
    return source[start:start + end]


def function(source, name):
    start = source.index(name + "(")
    end = source.index("\n}", start) + 2
    return "static int " + source[start:end]


# The unrelated device state, logging, and firmware capability handlers are
# stand-ins. The tag enum, wire structs, ext2 parse state, and parsers come
# directly from the supplied wmi.c and its matching wmi.h.
preamble = r"""
#include <endian.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint32_t __le32;
#define __packed __attribute__((packed))
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define WMI_TLV_TAG 0xffff0000U
#define WMI_TLV_LEN 0x0000ffffU
#define WMI_MAX_EHTCAP_MAC_SIZE 2
#define WMI_TARGET_CAP_FLAGS_RX_PEER_METADATA_VERSION 3U
#define le32_to_cpu(v) le32toh(v)
#define __le32_to_cpu(v) le32_to_cpu(v)
#define u32_get_bits(v, mask) (((v) & (mask)) >> __builtin_ctz(mask))
#define le32_get_bits(v, mask) u32_get_bits(le32_to_cpu(v), mask)

struct ath12k_wmi_pdev { unsigned int unused; };
struct ath12k_base {
    struct {
        struct ath12k_wmi_pdev wmi[1];
        u32 sbs_lower_band_end_freq;
        u8 dp_peer_meta_data_ver;
    } wmi_ab;
    unsigned int mode_list_updates;
    unsigned int parse_warnings;
};
static const struct { size_t min_len; } ath12k_wmi_tlv_policies[1];

static void ath12k_err(struct ath12k_base *ab, const char *fmt, ...) {}
static void ath12k_warn(struct ath12k_base *ab, const char *fmt, ...)
{
    ab->parse_warnings++;
}
#define ath12k_dbg(ab, mask, ...) ath12k_err(ab, __VA_ARGS__)

static int ath12k_pull_svc_ready_ext2(struct ath12k_wmi_pdev *pdev,
                                     const void *ptr, void *arg) { return 0; }
static int ath12k_wmi_dma_ring_caps(struct ath12k_base *ab, u16 len,
                                    const void *ptr, void *data) { return 0; }
static int ath12k_wmi_tlv_mac_phy_caps_ext(struct ath12k_base *ab, u16 tag,
                                          u16 len, const void *ptr, void *data)
{
    /* The MAC/PHY array in these fixtures is empty. */
    return -EPROTO;
}
static int ath12k_wmi_update_hw_mode_list(struct ath12k_base *ab)
{
    ab->mode_list_updates++;
    return 0;
}
"""

main = r"""
int main(void)
{
    struct ath12k_wmi_svc_rdy_ext2_parse parse = {};
    struct ath12k_base ab = { .wmi_ab.sbs_lower_band_end_freq = 1234 };
    u8 event[1024];
    size_t len = fread(event, 1, sizeof(event), stdin);
    int ret;

    if (ferror(stdin) || len == sizeof(event))
        return 1;

    ret = ath12k_wmi_tlv_iter(&ab, event, len, ath12k_wmi_svc_rdy_ext2_parse, &parse);
    printf("%d %u %u %u %u\n", ret, ab.wmi_ab.sbs_lower_band_end_freq,
           (unsigned int)parse.dbs_or_sbs_cap_ext_done, ab.mode_list_updates,
           ab.parse_warnings);
    return 0;
}
"""


def tlv(tag, payload):
    return struct.pack("<HH", len(payload), tag) + payload


def caps(mode, cutoff, *tail):
    words = (mode, cutoff, *tail)
    return tlv(0x400, struct.pack(f"<{len(words)}I", *words))


def event(records):
    # The DBS/SBS member is the eighth ARRAY_STRUCT in SERVICE_READY_EXT2.
    # A subsequent array makes accidental reads past an empty member visible.
    return (tlv(0x334, bytes(52)) + tlv(18, b"") * 7 + tlv(18, records)
            + tlv(18, tlv(0x402, bytes(8))))


frame = caps(5, 5900)
other = caps(3, 5500)
zero = caps(5, 0)
wrong_tag = tlv(0x401, struct.pack("<II", 5, 5900))
short = tlv(0x400, struct.pack("<I", 5))
cases = [
    ("Frame mode 5, cutoff 5900", frame, 0, 5900),
    ("short nested header", frame[:2], -errno.EINVAL, 1234),
    ("truncated nested payload", frame[:-1], -errno.EINVAL, 1234),
    ("short capability", short, -errno.EPROTO, 1234),
    ("wrong tag with full payload", wrong_tag, -errno.EPROTO, 1234),
    ("empty capability payload", tlv(0x400, b""), -errno.EPROTO, 1234),
    ("empty array clears previous cutoff", b"", 0, 0),
    ("explicit zero cutoff", zero, 0, 0),
    ("extended payload with mid-band cutoff", caps(5, 5900, 6100), 0, 5900),
    ("two distinct modes and cutoffs", frame + other, 0, 5900),
    ("two distinct modes in reverse order", other + frame, 0, 5500),
    ("first zero and second nonzero", zero + frame, 0, 0),
    ("valid then wrong tag", frame + wrong_tag, -errno.EPROTO, 1234),
    ("valid then partial header", frame + frame[:1], -errno.EINVAL, 1234),
    ("valid then short capability", frame + short, -errno.EPROTO, 1234),
]

if len(sys.argv) != 2:
    raise SystemExit(f"Usage: {sys.argv[0]} /path/to/ath12k/wmi.c")

source_path = pathlib.Path(sys.argv[1])
source = source_path.read_text()
header = source_path.with_name("wmi.h").read_text()
parts = [
    preamble,
    declaration(header, "enum wmi_tlv_tag"),
    declaration(header, "struct wmi_tlv"),
    declaration(header, "struct ath12k_wmi_dbs_or_sbs_cap_params"),
    declaration(source, "struct ath12k_wmi_dma_ring_caps_parse"),
    declaration(source, "struct ath12k_wmi_svc_rdy_ext2_arg"),
    declaration(source, "struct ath12k_wmi_svc_rdy_ext2_parse"),
    function(source, "ath12k_wmi_tlv_iter"),
]
# This also allows the unpatched source to run the same first regression case.
if "ath12k_wmi_tlv_dbs_sbs_caps(" in source:
    parts.append(function(source, "ath12k_wmi_tlv_dbs_sbs_caps"))
has_caps_helper = "ath12k_wmi_dbs_sbs_caps(" in source
if has_caps_helper:
    parts.append(function(source, "ath12k_wmi_dbs_sbs_caps"))
parts.extend([function(source, "ath12k_wmi_svc_rdy_ext2_parse"), main])

with tempfile.TemporaryDirectory(prefix="frame-mlo-parser-") as tmp:
    c_file = pathlib.Path(tmp) / "test.c"
    binary = pathlib.Path(tmp) / "test"
    c_file.write_text("\n".join(parts))
    subprocess.run(["gcc", "-std=gnu11", "-Wall", "-Wextra", "-Werror",
                    "-Wno-unused-parameter", "-fsanitize=address,undefined",
                    "-fno-sanitize-recover=all", "-fno-omit-frame-pointer", "-g",
                    str(c_file), "-o", str(binary)], check=True)
    for name, records, ret, cutoff in cases:
        result = subprocess.run([str(binary)], input=event(records),
                                stdout=subprocess.PIPE, check=True)
        actual = tuple(map(int, result.stdout.split()))
        expected = (ret, cutoff, int(ret == 0), int(ret == 0),
                    int(has_caps_helper and ret != 0))
        if actual != expected:
            raise SystemExit(f"FAIL: {name}: got {actual}, expected {expected} "
                             "(return, cutoff, array done, mode list updates, warnings)")
        print(f"PASS: {name}")
    print(f"{len(cases)} parser cases passed")
