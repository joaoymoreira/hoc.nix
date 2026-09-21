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
      };
    })
  );
}
