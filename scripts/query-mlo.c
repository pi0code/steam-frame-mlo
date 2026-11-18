/* Query advertised capabilities without printing network identifiers. */
#include <stdbool.h>
#include <stdio.h>
#include <linux/nl80211.h>
#include <netlink/attr.h>
#include <netlink/genl/ctrl.h>
#include <netlink/genl/genl.h>
#include <netlink/netlink.h>

struct capabilities {
	bool mlo;
	unsigned int parts;
};

static int reply(struct nl_msg *msg, void *arg)
{
	struct capabilities *caps = arg;
	struct nlattr *attrs[NL80211_ATTR_MAX + 1] = {};
	struct genlmsghdr *header = nlmsg_data(nlmsg_hdr(msg));

	if (nla_parse(attrs, NL80211_ATTR_MAX, genlmsg_attrdata(header, 0),
		      genlmsg_attrlen(header, 0), NULL) < 0)
		return NL_SKIP;
	caps->parts++;
	if (attrs[NL80211_ATTR_MLO_SUPPORT])
		caps->mlo = true;
	return NL_OK;
}

int main(void)
{
	struct capabilities caps = {};
	struct nl_sock *sock = nl_socket_alloc();
	struct nl_msg *msg = NULL;
	int family, result = 1;

	if (!sock || genl_connect(sock) < 0)
		goto out;
	family = genl_ctrl_resolve(sock, "nl80211");
	if (family < 0)
		goto out;
	msg = nlmsg_alloc();
	if (!msg || !genlmsg_put(msg, NL_AUTO_PORT, NL_AUTO_SEQ, family, 0,
				NLM_F_DUMP, NL80211_CMD_GET_WIPHY, 0))
		goto out;
	if (nla_put_flag(msg, NL80211_ATTR_SPLIT_WIPHY_DUMP) < 0 ||
	    nl_socket_modify_cb(sock, NL_CB_VALID, NL_CB_CUSTOM, reply, &caps) < 0 ||
	    nl_send_auto(sock, msg) < 0 || nl_recvmsgs_default(sock) < 0 ||
	    !caps.parts)
		goto out;
	printf("Kernel advertises MLO: %s\n", caps.mlo ? "YES" : "NO");
	result = 0;
out:
	if (result)
		fprintf(stderr, "Could not query Wi-Fi capabilities through nl80211.\n");
	if (msg)
		nlmsg_free(msg);
	if (sock)
		nl_socket_free(sock);
	return result;
}
