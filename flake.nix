{
  description = "Build and run Ibex Simple_System simulation declaratively using Nix!";

  inputs = { };

  outputs = { self, nixpkgs, }: 
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      riscv_gcc_toolchain = pkgs.callPackage ./nix/riscv_gcc_lowrisc.nix {};
    in
      {

        defaultPackage.x86_64-linux = riscv_gcc_toolchain;

      };
}
