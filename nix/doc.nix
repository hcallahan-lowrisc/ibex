# Build the ibex documentation site

{inputs, pkgs, ...}: let
  inherit (pkgs) lib;
  fs = pkgs.lib.fileset;

  root = ./..;
  doc_root = root + "/doc/";

  python = pkgs.python313;
  pythonPackages = pkgs.python313Packages; # Only used for some overrides

  # Load a uv workspace from the workspace root.
  workspace = inputs.uv2nix.lib.workspace.loadWorkspace { workspaceRoot = doc_root; };
  # Create package overlay from workspace.
  uvLockedOverlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };
  # Construct package set from uv.lock
  pythonSet' =
    # Use base package set from pyproject.nix builders
    (pkgs.callPackage inputs.pyproject-nix.build.packages { inherit python; }).overrideScope uvLockedOverlay;
  # Create overrides from the nixpkgs package definitions
  pyprojectOverrides = final: prev:
    let
      hacks = pkgs.callPackage inputs.pyproject-nix.build.hacks {};
      nixpkgsPrebuiltTransformer = pkg : hacks.nixpkgsPrebuilt {
        from = pythonPackages.${pkg};
        prev = prev.${pkg};
      };
    in {
      # Adopt some package builds from nixpkgs
      # The uv2nix_hammer overrides allow the packages to build, but give runtime errors when trying to use sphinx-build
      # cairocffi - OSError: no library called "cairo-2" was found
      # xcffib - OSError: cannot load library 'libxcb.so'
      cairocffi = nixpkgsPrebuiltTransformer "cairocffi";
      xcffib = nixpkgsPrebuiltTransformer "xcffib";
    };
  # Apply overlay(s) to fix any build issues
  pythonSet =
    pythonSet'.pythonPkgsHostHost.overrideScope
      (
        lib.composeManyExtensions [
          inputs.pyproject-build-systems.overlays.default
          (inputs.uv2nix_hammer_overrides.overrides pkgs)
          pyprojectOverrides
        ]
      );

  virtualenv = pythonSet.mkVirtualEnv "env" workspace.deps.default;
  virtualenv-dev = pythonSet.mkVirtualEnv "env-dev" workspace.deps.all; # include dev-dependencies

in rec {

  inherit virtualenv;
  inherit virtualenv-dev;

  site = pkgs.stdenv.mkDerivation {
    name = "ibex-docs-site";
    src = fs.toSource rec {
      inherit root;
      fileset = fs.unions (builtins.map (rp: root + rp) [
        "/doc/"
        "/util/"
        "/tool_requirements.py"
      ]);
    };
    env.SETUPTOOLS_SCM_PRETEND_VERSION =
      if (inputs.self ? rev)
      then inputs.self.shortRev
      else inputs.self.dirtyShortRev;
    dontFixup = true;
    buildPhase = ''
      ${virtualenv}/bin/sphinx-build -b html ./doc ./_build/html
    '';
    installPhase = ''
      mkdir -p $out
      cp --no-preserve=mode -r _build/html/. $out/
    '';
  };

  serve = pkgs.writeShellApplication {
    name = "serve";
    text = ''
      echo "##############################"
      echo "#     Serving site demo      #"
      echo "##############################"
      ${pkgs.lib.getExe python} -m http.server -d ${site} 9000
    '';
  };

  autobuild = pkgs.writeShellApplication {
    name = "autobuild";
    text = ''
      ROOT_PATH=$(${pkgs.lib.getExe pkgs.git} rev-parse --show-toplevel)
      ${virtualenv-dev}/bin/sphinx-autobuild -b html "$ROOT_PATH"/doc "$ROOT_PATH"/_build/html
    '';
  };

}
