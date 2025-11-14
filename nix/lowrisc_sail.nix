# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Override the upstream sail package definition to use the lowRISC fork
{
  pkgs,
  src,
}:

pkgs.ocaml-ng.ocamlPackages_5_1.sail.overrideAttrs (prev: {
  pname = "lowrisc_sail";
  inherit src;

  # The lowRISC fork is older than upstream, and requires additional dependencies
  # from those specified upsteam to build. Add them here.
  propagatedBuildInputs =
    prev.propagatedBuildInputs ++ (with pkgs; [
      z3
    ]);
})
