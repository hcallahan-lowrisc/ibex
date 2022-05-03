{
  description = "Build and run Ibex Simple_System simulation declaratively using Nix!";

  inputs = {
    mach-nix.url = "mach-nix/3.4.0";
    fetchPypi = {
      url = "git+https://github.com/DavHau/nix-pypi-fetcher";
    };

    # name = "nix-pypi-fetcher";
    # url = "https://github.com/DavHau/nix-pypi-fetcher/tarball/${commit}";
    # # Hash obtained using `nix-prefetch-url --unpack <url>`
    # sha256 = "1c06574aznhkzvricgy5xbkyfs33kpln7fb41h8ijhib60nharnp";

    lrfusesoc = {
     url = "path:/home/harrycallahan/projects/fusesoc/";
     # url = "github:lowRISC/fusesoc?ref=ot-0.2";
     flake = false;
    };
    lredalize = {
     url = "github:lowRISC/edalize?ref=ot-0.2";
     flake = false;
    };
    # simplesat = {
    #   url = ;
    #   flake = false;
    # }
  };

  outputs = { self, nixpkgs, mach-nix, lrfusesoc, lredalize }:
    let
      system = "x86_64-linux";

      my_fusesoc = pkgs.python3Packages.buildPythonPackage rec {
        src = lrfusesoc;
        version = "0.3.3.dev";
        SETUPTOOLS_SCM_PRETEND_VERSION = "${version}";
        nativeBuildInputs = with pkgs.python3.pkgs; [ setuptools_scm ];
        propagatedBuildInputs = with pkgs.python3.pkgs; [ pyparsing pyyaml simplesat ];
      };

      my_edalize = pkgs.python3Packages.buildPythonPackage rec {
        src = lredalize;
        version = "0.3.3.dev";
        SETUPTOOLS_SCM_PRETEND_VERSION = "${version}";
        propagatedBuildInputs = with pkgs.python3.pkgs; [ jinja2 ];
        dontTest = true;
      };

      my_simplesat = pkgs.python3Packages.buildPythonPackage rec {
        pname = "simplesat";
        version = "0.8.2";
        src = pkgs.python3Packages.fetchPypi {
          inherit pname version;
          sha256 = "0000000000000000000000000000000000000000000000000000";
        };
        propagatedBuildInputs = with pkgs.python3.pkgs; [ attrs okonomiyaki six ];
      };

      my_overlay = final: prev: {
        python3 = prev.python3.override {
          packageOverrides = pfinal: pprev: {
            fusesoc = my_fusesoc;
            edalize = my_edalize;
            simplesat = my_simplesat;
          };
        };
      };

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ my_overlay ];
      };

      my_env = pkgs.python3.withPackages(
        p: with p; [ fusesoc edalize ]
      );


      riscv_gcc_toolchain = pkgs.callPackage ./nix/riscv_gcc_lowrisc.nix {};

      requirements_ibex = ''
          ##IBEX##
          fusesoc<0.4.3.dev
          edalize<0.4.3.dev
          pyyaml
          Mako
          junit-xml
          hjson
          mistletoe>=0.7.2
          premailer<3.9.0
      '';
       requirements_riscvdv = ''
          bitstring
          sphinx
          pallets-sphinx-themes
          sphinxcontrib-log-cabinet
          sphinx-issues
          sphinx_rtd_theme
          rst2pdf
          flake8
          pyvsc
          tabulate
          pandas
      '';

      # pyenv = mach-nix.lib.x86_64-linux.mkPython {
      #   requirements = ''
      #     fusesoc=0.3.3.dev
      #   '';
      #   overridesPre = [
      #     (final: prev: {
      #       fusesoc = my_fusesoc;
      #       edalize = my_edalize;
      #     })
      #   ];
      # };

      buildInputs = with pkgs;
        [ verilator libelf srecord ] ++
        [ riscv_gcc_toolchain my_env ];

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
      #   devShells.x86_64-linux.fusesoc = pkgs.mkShell {
      #     name = "fusesoc";
      #     version = "0.1.0";
      #     buildInputs = [ fusesoc_deps ];
      #     # inputsFrom = [ my_fusesoc ]; # Use special "inputsFrom" to get the buildInputs from derivations
      #   };
      };
}
