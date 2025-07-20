# Run NixOS on a Lima VM

A NixOS flake for building a [Lima](https://lima-vm.io)-compatible system image.

This is a based on [kasuboski/nixos-lima](https://github.com/kasuboski/nixos-lima) and there are about a half-dozen [forks](https://github.com/kasuboski/nixos-lima/forks) of that repo, but none of them (yet) seem to be making much of an effort to be generic/reusable, accept contributions, create documentation, etc. So I created this repo to try to create something that multiple developers can use and contribute to. (So now there are a _half-dozen plus one_ projects 🤣  -- see [xkcd "Standards"](https://xkcd.com/927/))

There has been ongoing discussion in https://github.com/lima-vm/lima/discussions/430, and I have proposed there to create a "unified" project. If you have input or want to collaborate, please comment there or open an issue or pull request here. I'm also happy to archive this project and contribute to another one if other collaborators think that is a better path forward.

Currently, this flake supports building and booting a Lima NixOS image on both Linux and macOS and rebuilding NixOS from inside the VM. (I have not tested on x86, but it should work with minor tweaks.) Several of the existing forks contain features I would like to see integrated.

## Design Goals

The following are the design goals that I think are important, but I'm definitely open to suggestions for changing these. (Just open an issue.)

1. Nix flake that can build a bootable NixOS Lima-compatible image
2. Be as generic and reusable by others as possible
3. Nix modules for the systemd services that initialize and configure the system
4. User customization of NixOS Lima instance is done separately from initial image creation
5. Track the current nixos-unstable branch in Nix

## Prerequisites

A working Nix installation capable of building Linux systems. This includes:

* Linux system with Nix installed
* Linux VM with Nix installed (e.g. under macOS)
* macOS system with [linux-builder](https://nixos.org/manual/nixpkgs/unstable/#sec-darwin-builder) installed via [Nix Darwin](https://github.com/LnL7/nix-darwin)

Flakes must be enabled.


## Generating the image

```bash
nix build .#packages.aarch64-linux.img
```

If you built the image on another system:

```bash
mkdir result
# copy image to result/nixos.img
```

## Running NixOS

```bash
limactl start --vm-type qemu --name=nixos nixos.yaml

limactl shell nixos
```

## Rebuilding NixOS inside the Lima instance

```bash
# Using a VM shell, cd to this repository directory
nixos-rebuild switch --flake .#nixos --use-remote-sudo
```
  
## Managing your NiXOS Lima VM instance

See the [NixOS Lima VM Config Sample](https://github.com/nixos-lima/nixos-lima-config-sample).

Fork and clone that repository, check it out either to your macOS host or to a directory within your NixOS VM instance. Then use:

```bash
nixos-rebuild switch --flake .#sample --use-remote-sudo
```

Or change the name `sample` to match the hostname of your NixOS Lima guest.

## References

* [NixOS Dev Environment on Mac](https://www.joshkasuboski.com/posts/nix-dev-environment/) January, 24 2023 by [Josh Kasuboski](https://www.joshkasuboski.com)

## Credits

* Forked from: [kasuboski/nixos-lima](https://github.com/kasuboski/nixos-lima)
* Heavily inspired by: [patryk4815/ctftools](https://github.com/patryk4815/ctftools/tree/master/lima-vm)

The unmodified, upstream README is in `README_upstream.md`.

Fixes/patches from:

* [unidevel/nixos-lima](https://github.com/unidevel/nixos-lima)
* [lima-vm/alpine-lima](https://github.com/lima-vm/alpine-lima)
