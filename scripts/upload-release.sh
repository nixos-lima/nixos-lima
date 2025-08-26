#!/bin/sh
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <tag>"
  exit 1
fi
NIXOS_LIMA_TAG=$1
IMAGEDIR=release-$NIXOS_LIMA_TAG-images
RELEASE_FILES="$IMAGEDIR/nixos-lima-$NIXOS_LIMA_TAG-aarch64.qcow2 $IMAGEDIR/nixos-lima-$NIXOS_LIMA_TAG-x86_64.qcow2"
echo Uploading $RELEASE_FILES
gh release upload $NIXOS_LIMA_TAG $RELEASE_FILES
