#!/bin/sh
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <tag>"
  exit 1
fi
NIXOS_LIMA_TAG=$1
mkdir -p tmp
gh release download --repo nixos-lima/nixos-lima -D tmp --pattern "*.qcow2" $NIXOS_LIMA_TAG

