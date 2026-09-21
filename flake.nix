{
  description = "High Order Company's software";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
    ];

    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    # hvm1-src = { url = "github:higherorderco/hvm1/master"; flake = false; };
    # hvm2-src = { url = "github:higherorderco/hvm2/main"; flake = false; };
    # hvm3-src = { url = "github:higherorderco/hvm3/main"; flake = false; };
    # hvm4-src = { url = "github:higherorderco/hvm4/main"; flake = false; };
    # kind1-src = { url = "github:higherorderco/kind-legacy/master"; flake = false; };
    # kind2-src = { url = "github:higherorderco/kind/master"; flake = false; };
    # bend1-src = { url = "github:higherorderco/bend1/main"; flake = false; };
    # bend2-src = { url = "github:bendlang/bend/main"; flake = false; };
  };

  outputs = (inputs@{
    self
    , nixpkgs
    , systems
    , flake-parts
    , treefmt-nix
    , ...
  }:
    (flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.treefmt-nix.flakeModule
      ];

      systems = import systems;

      perSystem = { self', system, lib, config, pkgs, ... }: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        packages = {
          # hvm2 = pkgs.callPackage ./pkgs/hvm2/package.nix { };
          kind2 = pkgs.callPackage ./pkgs/kind2/package.nix { };
          bend = pkgs.callPackage ./pkgs/bend2/package.nix { };
          bend2 = pkgs.callPackage ./pkgs/bend2/package.nix { };
        };

        # Devshell factory. It lives in legacyPackages (rather than a plain
        # `let`) so the command line can call it too — legacyPackages is the one
        # flake output `nix flake check` and `nix flake show` leave alone, so
        # non-derivation values like functions are allowed there.
        legacyPackages = {
          mkBend2Shell =
            { name ? "bend2", bend2 ? self'.packages.bend2 }:
            pkgs.mkShell {
              inherit name;
              meta.description = "Bend 2 development environment";

              # The wrapped `bend` binary itself, on PATH.
              packages = [ bend2 ];

              # Pulls in every buildInput / nativeBuildInput of the bend
              # package: bun, typst, clang, makeWrapper, libx11.dev,
              # xorgproto, alsa-lib.dev, cudatoolkit, cuda_nvcc, ...
              inputsFrom = [ bend2 ];

              # The same environment the `bend` wrapper script sets up:
              # CPATH, LIBRARY_PATH, LD_LIBRARY_PATH, CUDA_HOME and
              # BEND_NO_TELEMETRY (mirrors the makeWrapper flags).
              env = bend2.passthru.runtimeEnv;

              # -l flags from the package: -lX11/-lasound follow enableX /
              # enableAlsa (Linux by default), -lcuda/-lnvrtc follow enableCuda.
              shellHook = ''
                export NIX_LDFLAGS="$NIX_LDFLAGS ${lib.concatStringsSep " " bend2.passthru.linkFlags}"
              '';
            };
        };

        # nix develop
        devShells = {
          bend2 = self'.legacyPackages.mkBend2Shell { };

          bend2-nocuda = self'.legacyPackages.mkBend2Shell {
            name = "bend2-nocuda";
            bend2 = self'.packages.bend2.override { enableCuda = false; };
          };

          default = self'.devShells.bend2;
        };
      };
    })
  );
}
