{
  description = "ARTIQ build environment with OpenOCD";

  inputs.artiq.url = "git+https://git.m-labs.hk/M-Labs/artiq.git?ref=release-9";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, artiq, nixpkgs }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = [
          artiq.packages.x86_64-linux.artiq
          artiq.packages.x86_64-linux.openocd-bscanspi
          pkgs.python3Packages.packaging
        ];

        shellHook = ''
          source /tools/Xilinx/Vivado/2024.2/settings64.sh
        '';
      };
    };
}
