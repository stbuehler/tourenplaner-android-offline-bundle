#!/bin/sh

set -e

self=$(readlink -f "$0")
base=$(dirname "${self}")

(
	echo "Building"
	cd tourenplaner-android-offline
	ant release
)

src="tourenplaner-android-offline/bin/OfflineTourNPlaner-release-unsigned.apk"
unaligned="tourenplaner-android-offline/bin/OfflineTourNPlaner-release-unaligned.apk"
out="OfflineTourNPlaner-release.apk"

ANDROID_SDK="${ANDROID_SDK:-/opt/android-sdk/}"
ZIPALIGN="${ANDROID_SDK}/tools/zipalign"

if [ ! -x "${ZIPALIGN}" ]; then
	ZIPALIGN="$(which zipalign)"
fi

if [ -e "${src}" -a -x "${ZIPALIGN}" ]; then
	echo "Signing"

	jarsigner -sigalg MD5withRSA -digestalg SHA1 -signedjar "${unaligned}" "${src}" "${KEYALIAS:-stbuehler}"

	echo "Aligning"

	"${ZIPALIGN}" -f 4 "${unaligned}" "${out}"
fi
