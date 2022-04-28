{
  description = "Build and run Ibex Simple_System simulation declaratively using Nix!";

  inputs = {
    mach-nix.url = "mach-nix/3.4.0";

    lrfusesoc = {
     url = "github:lowRISC/fusesoc?ref=ot-0.2";
     flake = false;
    };
    lredalize = {
     url = "github:lowRISC/edalize?ref=ot-0.2";
     flake = false;
    };
  };

  outputs = { self, nixpkgs, mach-nix, lrfusesoc, lredalize }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      riscv_gcc_toolchain = pkgs.callPackage ./nix/riscv_gcc_lowrisc.nix {};

      pyenv = mach-nix.lib.x86_64-linux.mkPython {
        overridesPre = [
          (final: prev: {
            fusesoc = mach-nix.lib.x86_64-linux.buildPythonPackage rec {
              src = lrfusesoc;
              version = "0.3.3.dev";
              SETUPTOOLS_SCM_PRETEND_VERSION = "${version}";
            };
            edalize = mach-nix.lib.x86_64-linux.buildPythonPackage {
              src = lredalize;
              version = "0.3.3.dev";
            };
          })
        ];
        requirements = ''
          ##IBEX##
          fusesoc=0.3.3.dev
          edalize<0.4.3.dev
          pyyaml
          Mako
          junit-xml
          hjson
          mistletoe>=0.7.2
          premailer<3.9.0

          ## riscv-dv ##
          bitstring
          sphinx
          # pallets-sphinx-themes
          # sphinxcontrib-log-cabinet
          # sphinx-issues
          # sphinx_rtd_theme
          # rst2pdf
          flake8
          pyvsc
          tabulate
          pandas

          pip
        '';
      };

      buildInputs = with pkgs;
        [ verilator libelf srecord ] ++
        [ riscv_gcc_toolchain pyenv ];

    in
      {

        ### from... ibex/examples/simple_system/README.md

        # fusesoc --cores-root=. run --target=sim --setup --build lowrisc:ibex:ibex_simple_system --RV32E=0 --RV32M=ibex_pkg::RV32MFast
        # make -C examples/sw/simple_system/hello_test
        # ./build/lowrisc_ibex_ibex_simple_system_0/sim-verilator/Vibex_simple_system [-t] --meminit=ram,./examples/sw/simple_system/hello_test/hello_test.elf

        # defaultPackage.x86_64-linux = simple_system;
        # Construct a shell with all of our dependencies
        devShell.x86_64-linux = pkgs.mkShell {
          name = "simple_system";
          version = "0.1.0";
          src = ./.;
          inherit buildInputs;
        };

      };
}
