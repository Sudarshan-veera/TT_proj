{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/cee01fe2c16da2d972b56c595d96b53fdd8ecc3f.tar.gz")
    { }
,
}:

let
  # KLayout 0.30.8 is required by the latest gf180mcu rule-framework DRC deck
  # (it uses LayoutToNetlist#copy, which older KLayout lacks). Pinned
  # separately so magic-vlsi keeps coming from the base nixpkgs above.
  klayoutPkgs = import
    (fetchTarball
      "https://github.com/NixOS/nixpkgs/archive/ffa10e26ae11d676b2db836259889f1f571cb14f.tar.gz")
    { };
in
pkgs.mkShell {
  buildInputs = [
    klayoutPkgs.klayout
    pkgs.magic-vlsi
  ];
}
