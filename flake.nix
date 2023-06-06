{
  description = "delroth's personal website (https://delroth.net)";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";

  outputs = { self, nixpkgs, flake-utils }: {
    overlay = final: prev: {
      delroth-net-website = prev.callPackage ./default.nix {};
    };
  } // (flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlay ];
      };
    in rec {
      packages.delroth-net-website = pkgs.delroth-net-website;
      defaultPackage = pkgs.delroth-net-website;

      devShells.default = with pkgs; mkShell {
        buildInputs = [ go hugo ];
      };
    }
  ));
}
