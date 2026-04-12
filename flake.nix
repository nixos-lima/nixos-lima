{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      flake-utils,
      ...
    }@attrs:
    # Create system-specific outputs for lima systems
    let
      ful = flake-utils.lib;
    in
    ful.eachSystem [ ful.system.x86_64-linux ful.system.aarch64-linux ] (system: {
      packages = {
        img =
          let
            base = nixpkgs.lib.nixosSystem {
              modules = [
                { nixpkgs.hostPlatform = system; }
                ./lima.nix
              ];
            };
          in
          (base.extendModules {
            modules = [
              "${nixpkgs}/nixos/modules/virtualisation/disk-image.nix"
              { image.baseName = "nixos"; }
            ];
          }).config.system.build.image;
      };
    })
    // ful.eachSystem [ ful.system.x86_64-linux ful.system.aarch64-linux ful.system.aarch64-darwin ] (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        # Use nixpkgs-unstable to get newer Lima in devShell
        pkgs-unstable = import nixpkgs-unstable { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.qemu
            (pkgs-unstable.lima.override {
              withAdditionalGuestAgents = true;
              qemu = pkgs.qemu;
            })
          ];
        };
        formatter = pkgs.nixfmt-tree;
      }
    )
    // {
      nixosConfigurations.nixos-aarch64 = nixpkgs.lib.nixosSystem {
        specialArgs = attrs;
        modules = [
          { nixpkgs.hostPlatform = "aarch64-linux"; }
          ./lima.nix
        ];
      };
      nixosConfigurations.nixos-x86_64 = nixpkgs.lib.nixosSystem {
        specialArgs = attrs;
        modules = [
          { nixpkgs.hostPlatform = "x86_64-linux"; }
          ./lima.nix
        ];
      };

      nixosModules.lima = {
        imports = [ ./lima-init.nix ];
      };
    };
}
