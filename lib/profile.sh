#!/bin/bash
# Tested SteamOS profile. A different kernel needs a new build and validation.
expected_kernel=7.2.0-g344f27110f05
source_commit=344f27110f059d0520c9dbbafc503d4bbc6c1f68
source_url=https://github.com/evlaV/deckard-linux-no-oopsies.git
headers_package=linux-72-deckard-headers
headers_version=7.2.0+g344f27110f05-1
headers_sha256=56b3f7a22f4a656bdfcd3ad6adbe88f9b85544650d12aabb69aee30d96ae752c
pahole_version=1:1.31-4
pahole_sha256=3b1a8c5119ed4cffa1aa8fc165f3bc547e523883f9c122dc0b39ce4b5ce0d8a8
wpa_version=2.12
wpa_sha256=08e23937e16d0155e55cab2b51f51fbe10d80a1aa91c4e15442645059b737ef6
# The driver/supplicant comparison must be completed before public release.
use_new_supplicant=yes
