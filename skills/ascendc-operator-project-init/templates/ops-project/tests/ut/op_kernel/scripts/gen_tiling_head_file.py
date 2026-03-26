# ----------------------------------------------------------------------------
# Copyright (c) 2025 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
# ----------------------------------------------------------------------------

"""
gen tiling head file for dynamic shape
"""

import ctypes
import json
import os
import stat
import struct
import math
import sys
import subprocess
import re
from pathlib import Path
from collections import namedtuple
import tbe
from tbe.common.platform.platform_info import get_soc_spec
from tbe.common.utils.op_tiling import do_op_tiling, _ASCEND_OPP_PATH_ENV, _ASCEND_OPP_PATH_DEFAULT, \
    _BUILTIN_TILING_PATH, _CUSTOM_TILING_PATH_DEFAULT, so_arch_path2
from tbe.tvm.error_mgr import raise_tbe_python_err, TBE_DEFAULT_PYTHON_ERROR_CODE
import tbe.tikcpp.get_op_tiling as tiling_help

OpInfo = namedtuple('OpInfo', ['kernel_name', 'op_type', 'inputs', 'outputs', 'attrs', 'impl_mode', 'origin_inputs',\
                    'origin_outputs', 'param_type_dynamic', 'mc2_ctx', 'param_type_list', 'init_value_list',\
                    'output_shape_depend_on_compute'])

OpInfo.__new__.__defaults__ = (None, None, None, None, None, None, None, None, None, None, None, None, None)

DEFAULT_TILING_KEY_VALUE = 0
_ASCEND_CUSTOM_OPP_PATH_ENV = "ASCEND_CUSTOM_OPP_PATH"
_TILING_SO_PATH = "op_impl/ai_core/tbe/op_tiling/liboptiling.so"
opp_dir = os.environ.get(_ASCEND_OPP_PATH_ENV, _ASCEND_OPP_PATH_DEFAULT)
config_default = os.path.join(opp_dir, "vendors", "config.ini")


def get_default_optiling_pathlist():
    vendor_list = []
    full_path_list = []
    if not os.path.exists(config_default):
        return full_path_list
    with open(config_default) as f:
        vdr_lst = f.readline().split("=")[1].split(",")
        for vdr in vdr_lst:
            _vendor = vdr.strip()
            if _vendor not in vendor_list:
                vendor_list.append(_vendor)
                full_path = os.path.join(opp_dir, "vendors", _vendor)
                full_path_list.append(full_path)
    return full_path_list


def get_custom_opp_pathlist():
    vendor_list = []
    custom_opp_dir = os.environ.get(_ASCEND_CUSTOM_OPP_PATH_ENV)
    if custom_opp_dir is None:
        return vendor_list
    _path_lst = str(custom_opp_dir).split(":")
    for _path in _path_lst:
        local_path = _path.strip()
        if len(local_path) != 0 and local_path not in vendor_list:
            vendor_list.append(local_path)
    return vendor_list


def load_lib_v2(hight_priority_path:str = None):
    opp_path = Path(os.environ.get(_ASCEND_OPP_PATH_ENV, _ASCEND_OPP_PATH_DEFAULT))
    builtin_optiling_lib_path = opp_path.joinpath(_BUILTIN_TILING_PATH)
    libregister = ctypes.CDLL("libregister.so")

    builtin_optiling_lib_path2 = opp_path.joinpath(so_arch_path2)

    # 2. custom optiling 2.0 regist
    default_lst = get_default_optiling_pathlist()
    if hight_priority_path is not None:
        try:
            custom_opp_so_path = hight_priority_path
            lib_optiling = ctypes.CDLL(custom_opp_so_path)
            custom_opp_so_path_str = str(custom_opp_so_path)
            lib_optiling.TbeLoadSoAndSaveToRegistry(custom_opp_so_path_str.encode('utf_8'))
        except OSError as e:
            # Custom op tiling lib may not exists
            raise e
        return libregister

    custom_opp_list = get_custom_opp_pathlist()
    join_list = custom_opp_list + default_lst
    for _path in join_list:
        try:
            custom_opp_so_path = os.path.join(_path, _TILING_SO_PATH)
            lib_optiling = ctypes.CDLL(custom_opp_so_path)
            custom_opp_so_path_str = str(custom_opp_so_path)
            lib_optiling.TbeLoadSoAndSaveToRegistry(custom_opp_so_path_str.encode('utf_8'))
        except OSError:
            # Custom op tiling lib may not exists
            pass

    # 4.  builtint optiling 2.0 regist
    try:
        if os.path.exists(builtin_optiling_lib_path2):
            lib_optiling_builtin = ctypes.CDLL(builtin_optiling_lib_path2)
            builtin_optiling_lib_path2_str = str(builtin_optiling_lib_path2)
            lib_optiling_builtin.TbeLoadSoAndSaveToRegistry(builtin_optiling_lib_path2_str.encode('utf_8'))
    except AttributeError:
        # ascend c static load builtin opmaster 2.0 so fail, undefined symbol, then use 1.0 way
        pass
    return libregister


def get_default_tiling_struct(opname: str, is_experimental):
    default_tiling_struct = ""
    if not is_experimental:
        new_base_path = (os.path.dirname(os.path.abspath(__file__)) + "/../../../..")
    else:
        new_base_path = (os.path.dirname(os.path.abspath(__file__)) + "/../../../../experimental")
    pattern = f"*/{opname}"
    print("new_base_path", new_base_path)
    new_paths = list(Path(new_base_path).glob(pattern))
    asc_file_path = new_paths
    if len(new_paths) > 0:
        asc_file_path = str(new_paths[0])
    print(f"asc_file_path:{asc_file_path}")
    command = ["grep", "-rnwE", "REGISTER_TILING_DEFAULT|BroadcastSch", asc_file_path]
    print("command:", " ".join(command))
    try:
        result = subprocess.run(command, text=True, capture_output=True, check=True)
        default_tiling_struct = result.stdout
        default_tiling_struct = default_tiling_struct.split(";")[0]
        default_tiling_struct = re.sub(r".*REGISTER_TILING_DEFAULT\(", '', default_tiling_struct)
        default_tiling_struct = default_tiling_struct.replace(')', '')
        default_tiling_struct = default_tiling_struct.strip()
        print("default_tiling_struct:", default_tiling_struct)
        if result.returncode == 0:
            default_tiling_struct = "TestUtDefaultTilingStruct"
    except subprocess.CalledProcessError as e:
        print(e)

    return default_tiling_struct


if __name__ == "__main__":
    if len(sys.argv) <= 2:
        raise RuntimeError("arguments must be greater than 2.")
    op_type = sys.argv[1]
    op_name = sys.argv[2]
    file_name = op_name + "_tiling_data.h"
    so_path = None
    if len(sys.argv) == 4:
        so_path = sys.argv[3]

    tiling_key_list = []
    if len(sys.argv) == 5:
        tiling_key_list = sys.argv[4].split(",")
        print("tiling_key_list:", tiling_key_list)
    tiling_help.load_lib = lambda: load_lib_v2(so_path)
    op_info = OpInfo()
    tiling_info = tiling_help.TilingInfo()
    op_info_dict = op_info._asdict()
    op_info_dict["op_type"] = op_type
    op_info_dict["inputs"] = [{"shape": [-1]}]
    op_info_dict["origin_inputs"] = [{"shape": [-1]}]
    op_info_dict["outputs"] = [{"shape": [-1]}]
    op_info_dict["attrs"] = []
    op_info2 = OpInfo(**op_info_dict)
    with tbe.common.context.op_context.OpContext("dynamic"):
        is_experimental = False
        if so_path and "/experimental/" in so_path:
            is_experimental = True
        tiling_struct = get_default_tiling_struct(op_name, is_experimental)
        if tiling_struct:
            tiling_info.file_content = tiling_help.gen_dynamic_shape_v2(op_name, tiling_struct)
        else:
            tiling_info = tiling_help.get_tiling_info(op_info2, tiling_key_list)

        if not tiling_info.file_content:
            print("ERROR gen tiling head file failed.", flush=True)
        with open(file_name, "w") as file:
            print(tiling_info.file_content, file=file)
