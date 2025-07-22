#!/bin/sh
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <tag>"
  exit 1
fi
NIXOS_LIMA_TAG=$1
JOBID=`gh run list --branch v0.0.1 --limit 1 --json databaseId | jq '.[0].databaseId'`
IMAGEDIR=release-$NIXOS_LIMA_TAG-images
mkdir -p $IMAGEDIR
echo Downloading nixos-lima-unstable-aarch64...
gh run download $RUN_ID --name nixos-lima-unstable-aarch64 --dir $IMAGEDIR
echo Downloading nixos-lima-unstable-x86_64...
gh run download $RUN_ID --name nixos-lima-unstable-x86_64  --dir $IMAGEDIR
mv $IMAGEDIR/nixos-lima-unstable-aarch64.qcow2 $IMAGEDIR/nixos-lima-$NIXOS_LIMA_TAG-aarch64.qcow2  
mv $IMAGEDIR/nixos-lima-unstable-x86_64.qcow2 $IMAGEDIR/nixos-lima-$NIXOS_LIMA_TAG-x86_64.qcow2  
