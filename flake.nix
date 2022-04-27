{
  description = "Build and run Ibex Simple_System simulation declaratively using Nix!";

  inputs = { };

  outputs = { self, nixpkgs, }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      riscv_gcc_toolchain = pkgs.callPackage ./nix/riscv_gcc_lowrisc.nix {};
      simple_system = pkgs.mkShell rec {
        name = "simple_system";
        version = "0.1.0";
        src = ./.;
        buildInputs = with pkgs; [ verilator ] ++
                      [ riscv_gcc_toolchain ];

        # dontBuild = true;
        # dontInstall = true;
      };
    in
      {

        # defaultPackage.x86_64-linux = simple_system;
        devShell.x86_64-linux = simple_system;

      };
}
