{
  description = "Build and run Ibex Simple_System simulation declaratively using Nix!";

  inputs = {
    mach-nix.url = "mach-nix/3.4.0";

    lrfusesoc = {
     url = "git+https://github.com/lowRISC/fusesoc?ref=ot";
     flake = false;
    };
    lredalize = {
     url = "git+https://github.com/lowRISC/edalize?ref=ot";
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
            fusesoc = mach-nix.lib.x86_64-linux.buildPythonPackage {
              src = lrfusesoc;
              version = "0.3.3";
              SETUPTOOLS_SCM_PRETEND_VERSION = "0.3.3";
            };
            edalize = mach-nix.lib.x86_64-linux.buildPythonPackage {
              src = lredalize;
              version = "0.3.3";
            };
          })
        ];
        requirements = ''
          ##IBEX##
          fusesoc=0.3.3
          edalize=0.3.3
          pyyaml
          Mako
          junit-xml
          hjson
          mistletoe # >= 0.7.2
          premailer # <  3.9.0

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

        # defaultPackage.x86_64-linux = simple_system;
        devShell.x86_64-linux = pkgs.mkShell {
          name = "simple_system";
          version = "0.1.0";
          src = ./.;
          inherit buildInputs;
        };

      };
}
