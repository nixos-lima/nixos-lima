{
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/*";
    flake-utils.url = "https://flakehub.com/f/numtide/flake-utils/*";
    nixos-generators = {
      url = "https://flakehub.com/f/nix-community/nixos-generators/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      nixos-generators,
      determinate,
      ...
    }@attrs:
    # Create system-specific outputs for lima systems
    let
      ful = flake-utils.lib;
    in
    ful.eachSystem [ ful.system.x86_64-linux ful.system.aarch64-linux ] (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages = {
          nixos-image = nixos-generators.nixosGenerate {
            inherit pkgs;
            modules = [
              ./lima.nix
            ];
            format = "qcow-efi";
          };
          nixos-determinate-image = nixos-generators.nixosGenerate {
            inherit pkgs;
            modules = [
              determinate.nixosModules.default
              ./lima.nix
            ];
            format = "qcow-efi";
          };
        };
      }
    )
    // ful.eachSystem [ ful.system.x86_64-linux ful.system.aarch64-linux ful.system.aarch64-darwin ] (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            qemu
            (lima.override {
              withAdditionalGuestAgents = true;
            })
          ];
        };
      }
    )
    // {
      nixosConfigurations.nixos-aarch64 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = attrs;
        modules = [
          ./lima.nix
        ];
      };

      nixosConfigurations.nixos-x86_64 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = attrs;
        modules = [
          ./lima.nix
        ];
      };

      nixosConfigurations.nixos-determinate-aarch64 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = attrs;
        modules = [
          determinate.nixosModules.default
          ./lima.nix
        ];
      };

      nixosConfigurations.nixos-determinate-x86_64 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = attrs;
        modules = [
          determinate.nixosModules.default
          ./lima.nix
        ];
      };

      nixosModules.lima = {
        imports = [ ./lima-init.nix ];
      };

      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-rfc-style;
      formatter.aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.nixfmt-rfc-style;
    };
}
