{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "";
      };
    };
  };

  outputs = { self, nixpkgs, zig, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    zig-dev = zig.packages.${system}."0.13.0";
  in {
    packages.${system} = {
      default = self.packages.${system}.vbox-manager-api-release;

      vbox-manager-api-release = pkgs.callPackage ./nix/package.nix {
        inherit (pkgs) zig_0_13;
        optimize = "ReleaseFast";
      };

      vbox-manager-api-debug = pkgs.callPackage ./nix/package.nix {
        inherit (pkgs) zig_0_13;
        optimize = "Debug";
      };
    };

    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [
        self.packages.${system}.vbox-manager-api-debug
        zig-dev
      ];
    };
  };
}
