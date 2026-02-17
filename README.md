# Run NixOS on a Lima VM

Run NixOS guest VMs using [Lima](https://lima-vm.io). **nixos-lima** is a Nix flake that generates Lima-compatible system images and provides a NixOS module for Lima boot-time and runtime support. The NixOS module runs in a Lima guest VM and configures the machine at boot-time using Lima configuration _userdata_ and runs the `lima-guestagent` daemon as a `systemd` service.

By using the released system image and using the provided NixOS module, you can create your own custom configuration.

## Design Goals

The following are the design goals that I think are important, but I'm definitely open to suggestions for changing these. (Just open an issue.)

1. Nix flake that can build a bootable NixOS Lima-compatible image
2. Nix modules for the systemd services that initialize and configure the system
3. User customization of NixOS Lima instance is done separately from initial image creation
4. Keep the base image and Nix services module as generic and reusable by others as possible
5. Track `nixpkgs/nixos-unstable` and switch to `nixpkgs/nixos-25.11` when it is branched off.

## Quickstart

If you want to quickly start a NixOS guest using Lima, you can use the [nixos.yaml](https://github.com/nixos-lima/nixos-lima/blob/master/nixos.yaml) template via `https://`. You do not need a Nix installation on your host machine, only a Lima installation. 

1. Install Lima
2. Run the following command to start a NixOS guest with the latest released nixos-lima system image:

```bash
limactl start --yes https://raw.githubusercontent.com/nixos-lima/nixos-lima/master/nixos.yaml
```
    
3. See [NixOS Lima VM Config Sample](https://github.com/nixos-lima/nixos-lima-config-sample) for an example of how to maintain the NixOS system configuration (and optionally Home Manager) in your NixOS guest VM.

### Quickstart with Lima 2.0+ Template URLs

If you have Lima 2.0.0 or later installed you can use the (experimental) GitHub Template URLs feature to use a more compact `start` command:

```bash
limactl start --yes github:nixos-lima
```


## Using the nixos-lima Module in Your Own Configuration

In your `flake.nix`, include `nixos-lima` as a flake input:

```
  inputs = {
    ...
    nixos-lima.url = "github:nixos-lima/nixos-lima/"
    ...
  };
```

In your system configuration, include:

```
  services.lima.enable = true;
```

For a complete, working example see: [nixos-lima/nixos-lima-config-sample](https://github.com/nixos-lima/nixos-lima-config-sample)

## Using nixos-rebuild To Customize and Update Your Guest Instance

There are at least three ways of managing the NixOS configuration of your image:

1. From inside the instance use `git` to check out a configuration repository and use `nixos-rebuild`.
2. From inside the instance, use `nixos-rebuild` on a configuration directory mounted from the host.
3. Push a configuration to the instance using the `--target` option of `nixos-rebuild` or using a remote deploy tool like [deploy-rs](https://github.com/serokell/deploy-rs).

For an example of (1) see [nixos-lima/nixos-lima-config-sample](https://github.com/nixos-lima/nixos-lima-config-sample).

## Building and Testing the System Image

If you want to build your own `nixos-lima` or contribute to this project, you can check out this repository and build the system image locally.

### Prerequisites

A working Nix installation capable of building Linux systems. This includes:

* Linux system with Nix installed
* Linux VM with Nix installed (e.g. under macOS)
* macOS system with [linux-builder](https://nixos.org/manual/nixpkgs/unstable/#sec-darwin-builder) installed via [Nix Darwin](https://github.com/LnL7/nix-darwin)
* macOS system with [nix-rosetta-builder](https://github.com/cpick/nix-rosetta-builder)

Flakes must be enabled.

### Generating the image
  
This example is for `aarch64`, but you can replace `aarch64` with `x86_64` if you are on an x86_64 Linux or macOS system.

```bash
nix build .#packages.aarch64-linux.img --out-link result-aarch64
```

If you built the image on another system:

```bash
mkdir result-aarch64
# copy image to result-aarch64/nixos.qcow2
```

### Running NixOS

Once you've built or copied an image into the `result-aarch64` directory, the `nixos-result.yml` template locates the images via a relative filesystem path:

```bash
limactl start --yes --name=nixos nixos-result.yaml

limactl shell nixos
```

### Rebuilding NixOS inside the Lima instance

If your Lima YAML file mounts your home directory (since `limactl shell` by default preserves
the current directory) you can invoke `nixos-rebuild` inside the VM using a `flake.nix` in a
directory on the host. The following command can be used on the host to rebuild NixOS in the guest from the `flake.nix` in the current directory:

```bash
limactl shell nixos -- nixos-rebuild boot --flake .#nixos-aarch64 --sudo
limactl restart nixos
```

## History

This is based on [kasuboski/nixos-lima](https://github.com/kasuboski/nixos-lima) and there were about a half-dozen [forks](https://github.com/kasuboski/nixos-lima/forks) of that repo, but none of them seemed to be making an effort to be generic/reusable, accept contributions, create documentation, etc. So I created this repo to try to create something that multiple developers can use and contribute to. (So now there are a _half-dozen plus one_ projects 🤣  -- see [xkcd "Standards"](https://xkcd.com/927/))

## References

* Lima discussion topic: [NixOS guest? #430](https://github.com/lima-vm/lima/discussions/430)
* Lima issue: [Template for nixOS #3688](https://github.com/lima-vm/lima/issues/3688)
* [NixOS Dev Environment on Mac](https://www.joshkasuboski.com/posts/nix-dev-environment/) January, 24 2023 by [Josh Kasuboski](https://www.joshkasuboski.com)

## Credits

* Forked from: [kasuboski/nixos-lima](https://github.com/kasuboski/nixos-lima)
* Heavily inspired by: [patryk4815/ctftools](https://github.com/patryk4815/ctftools/tree/master/lima-vm)

The unmodified, upstream README is in `README_upstream.md`.

Fixes/patches from:

* [unidevel/nixos-lima](https://github.com/unidevel/nixos-lima)
* [lima-vm/alpine-lima](https://github.com/lima-vm/alpine-lima)
