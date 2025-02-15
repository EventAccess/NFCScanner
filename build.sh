#!/bin/bash

# Get git tag, and massage into something semver-ish
# v1.0.0 if tag exactly, potentially v1.0.0+{n-commits-since-tag}.{commit-hash}.{dirty}
GIT_DESCRIPTION="$(git describe --tags --always --match 'v*' --dirty)"
GIT_DESCRIPTION="${GIT_DESCRIPTION/v}"
GIT_DESCRIPTION="${GIT_DESCRIPTION/-/+}"
GIT_DESCRIPTION="${GIT_DESCRIPTION//-/.}"

#DATETIME=$(date --utc '+%Y-%m-%d %H:%M:%S %Z')
VERSION="${GIT_DESCRIPTION}"

arduino-cli compile --output-dir artifacts/ -b rp2040:rp2040:challenger_2040_nfc src \
    --build-property "build.extra_flags=\"-DNFCSCANNER_VERSION=${VERSION}\""
