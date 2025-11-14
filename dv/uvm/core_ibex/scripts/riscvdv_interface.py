"""Defines the interface to riscvdv features for random instruction generation and compilation.

riscv-dv provides both
- a runnable instruction-generator
  (the sv/UVM program that actually generates .S assembly files)

- formatting guidelines for specifying simulators, test commands, optional arguments, etc.
  (testlist.yaml / simulator.yaml)

Provide an interface to get runnable commands from data/configuration specified in
the riscdv way.
"""

# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import re
import shlex
import pathlib3x as pathlib
from typing import Union, List, Dict
from typeguard import typechecked

from metadata import RegressionMetadata

# ibex
from setup_imports import _RISCV_DV, _CORE_IBEX_RISCV_DV_EXTENSION
from scripts_lib import subst_dict, subst_env_vars

# riscv-dv
from lib import read_yaml

import logging
logger = logging.getLogger(__name__)

parameter_format = '<{}>'
parameter_regex = r'(<[\w]+>)'  # Find matches to the above format


@typechecked
def get_run_cmd(verbose: bool) -> List[Union[str, pathlib.Path]]:
    """Return the command parts of a call to riscv-dv's run.py."""
    riscvdv_run_py = _RISCV_DV/'run.py'
    csr_desc = _CORE_IBEX_RISCV_DV_EXTENSION/'csr_description.yaml'
    testlist = _CORE_IBEX_RISCV_DV_EXTENSION/'testlist.yaml'

    cmd = ['python3',
           riscvdv_run_py,
           '--testlist', testlist,
           '--gcc_opts=-mno-strict-align',
           '--custom_target', _CORE_IBEX_RISCV_DV_EXTENSION,
           # '--simulator_yaml', _CORE_IBEX_YAML/'rtl_simulation.yaml',
           '--csr_yaml', csr_desc,
           '--mabi=ilp32']
    if verbose:
        cmd.append('--verbose')

    return cmd


def get_cov_cmd(md: RegressionMetadata) -> List[str]:
    """Return the the command to generate riscv-dv's functional coverage."""
    riscvdv_cov_py = _RISCV_DV/'cov.py'

    cmd = ['python3',
           str(riscvdv_cov_py),
           '--core', 'ibex',
           '--dir', str(md.dir_run),
           '-o', str(md.dir_fcov),
           '--simulator', md.simulator,
           '--opts',
           '--gen_timeout', '1000',
           '--isa', md.isa_ibex,
           '--custom_target', str(md.ibex_riscvdv_customtarget)]
    if md.verbose:
        cmd.append('--verbose')

    return cmd


@typechecked
def get_tool_cmds(yaml_path: pathlib.Path,
                  simulator: str,
                  cmd_type: str, # compile/sim
                  user_enables: Dict[str, bool],
                  user_subst_options: Dict[str, Union[str, pathlib.Path]]) -> List[List[str]]:
    """Substitute options and environment variables to construct a final command.

    Args:
        yaml_path: the path of the riscv-dv .yaml file specifying simulator options
        simulator: the name of the simulator to use.
        cmd_type: Either 'compile' or 'sim', the command we are selecting.
        user_enables: Enables if groups of tool arguments should be added into
            the final command. E.g. Should <wave_opts> be added?
        user_subst_opts: Values to be substitutes for any templated variables <T>.

    Returns:
        Multiple commands for either the 'compile' or 'sim' steps are possible,
        so return all hydrated commands as [str].

    Get the final tool commands by processing the riscv-dv .yaml file according to
    the following algorithm...

    (1) If the yaml key 'tool':'compile/sim' contains K:V pairs with keys other
        than 'cmd', for each of those keys K check if <K> exists in the cmd, and
        if it does, substitute for the value V. Gate each substitution with a
        user-specified enable.
    (2) For any remaining templated values <_> in the cmd, take a user-defined
        dict {K:V} and if <K> matches the templated value, replace <K> by V.
    (3) If the yaml key 'tool' set contains a K:V pair 'env_var':[str],
        then for each str in [str], check if it exists as a templated value <V>
        in the cmd, and if it does, substitute with the environment variable of
        the same name.

    Example:

    # mytools.yaml
    '''yaml
    - tool: vcs
      env_var: TB_DIR
      compile:
        cmd:
          - >-
            vcs
              -full64
              -f <core_ibex>/ibex_dv.f
              -o <TB_DIR>/vcs_simv
              <wave_opts> <cosim_opts>
        wave_opts: >-
          -debug_access+all
        cosim_opts: >-
          -f <core_ibex>/ibex_dv_cosim_dpi.f
    '''

    $ export TB_DIR=scratch/mytb
    $ python -c 'print(get_tool_cmds(
        yaml_path="mytools.yaml",
        simulator="vcs",
        cmd_type="compile"
        user_enables={wave_opts: False, cosim_opts: True},
        user_subst_options={core_ibex: "dv/uvm/core_ibex"}
      ))'
    vcs -full64 -f dv/uvm/core_ibex/ibex_dv.f -o scratch/mytb/vcs_simv -f dv/uvm/core_ibex/ibex_dv_cosim_dpi.f

    """

    simulator_dict = read_yaml(yaml_path)
    simulator_entry = next(filter(
        lambda i: i.get('tool') == simulator,
        simulator_dict))

    if not simulator_entry:
        raise RuntimeError(f"Cannot find RTL simulator '{simulator}'")

    cmds = []

    for cmd in simulator_entry[cmd_type]['cmd']:
        logger.debug(f"Unformatted command :\n{cmd}")
        formatted_cmd = cmd

        # (1)
        # Get all k:v pairs which are not 'cmd'
        # If the parameter is disabled by a user_enable, drop it.
        cmd_opts_dict = {
            k: (v.strip() if user_enables.get(k) else '')
            for k, v in simulator_entry[cmd_type].items()
            if k != 'cmd'
        }
        # Substitute with the matching parameters in the command
        if cmd_opts_dict != {}:
            formatted_cmd = subst_dict(formatted_cmd, cmd_opts_dict)
        logger.debug(f"After #1 :\n{formatted_cmd}")

        # (2)
        if user_subst_options != {}:
            formatted_cmd = subst_dict(formatted_cmd, user_subst_options)
        logger.debug(f"After #2 :\n{formatted_cmd}")

        # (3)
        if 'env_var' in simulator_entry.keys():
            formatted_cmd = subst_env_vars(
                formatted_cmd,
                [i for i in simulator_entry['env_var'].replace(' ', '').split(',')]
            )
        logger.debug(f"After #3 :\n{formatted_cmd}")

        # Finally, check if we have any parameters left which were not filled.
        match = re.findall(parameter_regex, formatted_cmd)
        if match:
            logger.error("Parameters in riscvdv command not substituted!\n"
                        f"Parameters : {match}\n"
                        f"Command :  {formatted_cmd}\n")
            raise RuntimeError

        logger.info(formatted_cmd)
        cmds.append(shlex.split(formatted_cmd))

    return cmds
