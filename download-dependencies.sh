#!/bin/bash

set -e

self=$(readlink -f "$0")
base=$(dirname "${self}")

cd "${base}"

mkdir -p "downloads"

fetch() {
	local url="$1"
	local fname="$2"

	local dest="downloads/${fname}"

	if [ ! -e "${dest}" ]; then
		echo "Missing ${fname}, downloading from ${url}"
		wget -O "${dest}" "${url}"
	fi
}

unpack() {
	local archive="downloads/$1"
	local filename="$2" # name in archive
	local fname="$3"
	local dest="downloads/${fname}"

	if [ ! -e "${dest}" ]; then
		echo "Unzipping ${filename} to ${fname} from ${archive}"
		unzip -p "${archive}" "${filename}" > "${dest}"
	fi
}

fetch http://labs.carrotsearch.com/download/hppc/0.4.3/hppc-0.4.3.zip hppc-0.4.3.zip
unpack hppc-0.4.3.zip hppc-0.4.3/hppc-0.4.3.jar hppc-0.4.3.jar

# ActionBarSherlock, ...

# get all git submodules
git submodule update --init --recursive
