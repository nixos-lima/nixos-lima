{
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/*";
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      determinate,
      ...
    }:
    let
      lib = nixpkgs.lib;

      devSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      pkgsFor = system: nixpkgs.legacyPackages.${system};

      makeImage =
        system: nixosSystem:
        import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
          pkgs = pkgsFor system;
          config = nixosSystem.config;
          inherit lib;
          format = "qcow2-compressed";
          partitionTableType = "efi";
        };

      mkNixosConfig =
        {
          system,
          withDeterminate ? false,
        }:
        lib.nixosSystem {
          inherit system;
          modules = lib.optionals withDeterminate [ determinate.nixosModules.default ] ++ [
            self.nixosModules.lima
            { services.lima.enable = true; }
            ./image.nix
          ];
        };
    in
    {
      packages = {
        aarch64-linux = {
          nixos-image = makeImage "aarch64-linux" self.nixosConfigurations.nixos-aarch64;
          nixos-determinate-image = makeImage "aarch64-linux" self.nixosConfigurations.nixos-determinate-aarch64;
        };
        x86_64-linux = {
          nixos-image = makeImage "x86_64-linux" self.nixosConfigurations.nixos-x86_64;
          nixos-determinate-image = makeImage "x86_64-linux" self.nixosConfigurations.nixos-determinate-x86_64;
        };
      };

      devShells = lib.genAttrs devSystems (
        system:
        let
          pkgs = pkgsFor system;
          # Default arch for image builds: match the host's arch, mapped to Linux
          defaultArch = if lib.hasPrefix "aarch64" system then "aarch64" else "x86_64";
        in
        {
          default = pkgs.mkShellNoCC {
            packages = [
              (pkgs.writeShellApplication {
                name = "apply-nix-config";
                text = ''
                  usage() {
                    echo "Usage: apply-config [--determinate]"
                    echo ""
                    echo "  --determinate        Use Determinate Nix configuration"
                  }
                  variant="nixos"
                  for arg in "$@"; do
                    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
                      usage
                      exit 0
                    elif [[ "$arg" == "--determinate" ]]; then
                      variant="nixos-determinate"
                    else
                      printf 'Error: unexpected argument "%s"\n' "$arg"
                      echo ""
                      usage
                      exit 1
                    fi
                  done
                  sudo nixos-rebuild switch --flake ".#''${variant}-${defaultArch}"
                '';
              })
            ];
          };

          # Tools for building NixOS images
          build-tools = pkgs.mkShellNoCC {
            packages = [
              (pkgs.writeShellApplication {
                name = "build-image";
                runtimeInputs = [
                  pkgs.coreutils
                  pkgs.nix-output-monitor
                ];
                text = ''
                  if [[ $# -eq 0 ]]; then
                    echo "Usage: build-image [aarch64|x86_64] [--determinate]"
                    echo ""
                    echo "  aarch64              Build for ARM64"
                    echo "  x86_64               Build for x86_64"
                    echo "  --determinate        Use Determinate Nix image"
                    exit 1
                  fi
                  arch="$1"
                  shift
                  if [[ "$arch" != "aarch64" && "$arch" != "x86_64" ]]; then
                    printf 'Error: unknown arch "%s" -- expected aarch64 or x86_64\n' "''${arch}"
                    exit 1
                  fi
                  variant="nixos-image"
                  nix_args=()
                  for arg in "$@"; do
                    if [[ "$arg" == "--determinate" ]]; then
                      variant="nixos-determinate-image"
                    elif [[ "$arg" == -* ]]; then
                      nix_args+=("$arg")
                    else
                      printf 'Error: unexpected argument "%s"\n' "$arg"
                      exit 1
                    fi
                  done
                  out=$(nom build ".#packages.''${arch}-linux.''${variant}" "''${nix_args[@]}" --print-out-paths)
                  sha512sum "''${out}/nixos.qcow2"
                '';
              })
            ];
          };

          # Tools for managing Lima VMs
          vm-tools = pkgs.mkShellNoCC {
            packages = [
              pkgs.qemu
              # withAdditionalGuestAgents bundles guest agent binaries for both
              # aarch64 and x86_64, needed to serve the correct binary to each VM.
              (pkgs.lima.override { withAdditionalGuestAgents = true; })
            ];
          };
        }
      );

      nixosConfigurations = {
        nixos-aarch64 = mkNixosConfig { system = "aarch64-linux"; };
        nixos-x86_64 = mkNixosConfig { system = "x86_64-linux"; };
        nixos-determinate-aarch64 = mkNixosConfig {
          system = "aarch64-linux";
          withDeterminate = true;
        };
        nixos-determinate-x86_64 = mkNixosConfig {
          system = "x86_64-linux";
          withDeterminate = true;
        };
      };

      nixosModules.lima = {
        imports = [ ./lima.nix ];
      };

      formatter = lib.genAttrs devSystems (system: (pkgsFor system).nixfmt-tree);
    };
}
