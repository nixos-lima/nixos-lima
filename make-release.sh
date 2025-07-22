#!/bin/sh
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <tag>"
  exit 1
fi
NIXOS_LIMA_TAG=$1
gh release create $NIXOS_LIMA_TAG \
  --title "Release $NIXOS_LIMA_TAG" \
  --notes "Test release" \
  --prerelease  
