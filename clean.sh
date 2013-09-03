#!/bin/sh

set -e

self=$(readlink -f "$0")
base=$(dirname "${self}")

# remove all build results in the submodules
# downloads/ are kept

git submodule foreach --recursive git clean -f -x -d
