{
  description = "Build and run Ibex Simple_System simulation declaratively using Nix!";

  inputs = {
    mach-nix = {
      url = "mach-nix/3.4.0";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    deps = {
      url = "path:/home/harry/projects/ibex_flake/dependencies";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    devshell.url = "github:numtide/devshell";

  };

  outputs = { self, nixpkgs,
              mach-nix, flake-utils, devshell,
              deps, ...}:
    let
      system = "x86_64-linux";

      # The upstream nixpkgs.verilator does not include zlib as a run-time dependency
      # It is needed in some use-cases (eg. FST) when building against verilator headers
      verilator_overlay = final: prev: {
        verilator = prev.verilator.overrideAttrs ( oldAttrs : {
          propagatedBuildInputs = [ final.zlib ];
        });
      };

      my_python_env = pkgs.python3.buildEnv.override {
        extraLibs = with pkgs.python3.pkgs; [
          fusesoc edalize
          pyyaml Mako junit-xml hjson mistletoe premailer
          anytree pip ];
      };

      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          devshell.overlay
          deps.overlay_pkgs
          (final: prev: {
            python3 = prev.python3.override {
              packageOverrides = deps.overlay_python;
            };
          })
          verilator_overlay
        ];
      };

      my_build_inputs =
        (with pkgs; [ pkg-config libelf srecord verilator riscv-isa-sim riscv-gcc-toolchain-lowrisc ]) ++
        [ my_python_env ];

      ibex_ss = pkgs.stdenv.mkDerivation {
        pname = "simple_system";
        name = "ss";
        version = "0.1.0";
        src = pkgs.lib.cleanSource ./.;
        packages = my_build_inputs;

        prePatch = ''
          substituteInPlace vendor/lowrisc_ip/dv/tools/ralgen/ralgen.core \
            --replace 'python3' ${my_python_env}/bin/python3
          substituteInPlace vendor/lowrisc_ip/ip/prim/primgen.core \
            --replace 'python3' ${my_python_env}/bin/python3
        '';
        installPhase = ''
          mkdir -p $out
          cp -r * $out
          '';
        };

      # requirements_ibex = ''
      #     ##IBEX##
      #     # These two packages are added at a later stage
      #     fusesoc
      #     edalize
      #     pyyaml
      #     Mako
      #     junit-xml
      #     hjson
      #     mistletoe>=0.7.2
      #     premailer<3.9.0
      # '';
      #  requirements_riscvdv = ''
      #     bitstring
      #     sphinx
      #     pallets-sphinx-themes
      #     sphinxcontrib-log-cabinet
      #     sphinx-issues
      #     sphinx_rtd_theme
      #     rst2pdf
      #     flake8
      #     pyvsc
      #     tabulate
      #     pandas
      # '';

      # Not currently used - though I still think mach-nix may be a better way to do this...
      # pyenv = mach-nix.lib.x86_64-linux.mkPython {
      #   ignoreDataOutdated = true;
      #   requirements = requirements_ibex;
      #   # requirements = requirements_ibex + requirements_riscvdv;
      #   overridesPre = [ deps.overlay_python ];
      #   # packagesExtra = [];
      # };

    in
      {
        packages.x86_64-linux.default = ibex_ss;

        packages.x86_64-linux.dockerImage = pkgs.dockerTools.buildImage {
          name = "simple_system_docker";
          tag = "latest";
          contents = [ pkgs.coreutils my_build_inputs ];
          config.Cmd = [
            "${pkgs.bash}/bin/bash"
          ];
        };

        # Construct a devShell with all of our dependencies (stdenv.mkShell)
        devShell.x86_64-linux = pkgs.mkShell {
          pname = "simple_system";
          name = "ss";
          version = "0.1.0";
          shellHook = ''
            substituteInPlace vendor/lowrisc_ip/dv/tools/ralgen/ralgen.core \
              --replace 'python3' ${my_python_env}/bin/python3
            substituteInPlace vendor/lowrisc_ip/ip/prim/primgen.core \
              --replace 'python3' ${my_python_env}/bin/python3
          '';
          packages = [ my_build_inputs ];
        };

        # Construct a devShell with all of our dependencies (numtide/devshell)
        devShells.x86_64-linux.numtidedevshell = pkgs.devshell.mkShell {
          # pname = "simple_system";
          name = "ibex_simple_system";
          # version = "0.1.0";
          # src = pkgs.lib.cleanSource ./.;
          packages = my_build_inputs;
          # inputsFrom = my_build_inputs;
        };

        # Invoke the devshell with "nix develop -i"
        # And then run.... (from ### ibex/examples/simple_system/README.md ###)
        # fusesoc --cores-root=. run --target=sim --setup --build lowrisc:ibex:ibex_simple_system --RV32E=0 --RV32M=ibex_pkg::RV32MFast
        # make -C /home/harry/projects/ibex/examples/sw/benchmarks/coremark/
        # build/lowrisc_ibex_ibex_simple_system_0/sim-verilator/Vibex_simple_system --meminit=ram,examples/sw/benchmarks/coremark/coremark.elf
      };
}
