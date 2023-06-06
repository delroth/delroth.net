{
  description = "delroth's personal website (https://delroth.net)";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";

  outputs = { self, nixpkgs, flake-utils }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
    in rec {
      packages.delroth-net-website = pkgs.callPackage ./default.nix {};
      defaultPackage = packages.delroth-net-website;

      devShells.default = with pkgs; mkShell {
        buildInputs = [ go hugo ];
      };
    }
  );
}
