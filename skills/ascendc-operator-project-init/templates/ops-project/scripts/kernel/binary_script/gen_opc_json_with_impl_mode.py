#!/usr/bin/env python3
# -*- coding: utf-8 -*-
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
gen_opc_json_with_impl_mode.py
"""
import sys
import os
import json
from binary_util.util import wr_json


def main(ori_json, new_json, impl_mole):
    """
    gen output json by binary_file and opc json file
    """
    if not os.path.exists(ori_json):
        print("[ERROR]the ori_json doesnt exist")
        return False
    with open(ori_json, "r") as file_wr:
        binary_json = json.load(file_wr)

    op_list = binary_json.get("op_list", list())
    for idx, bin_list_info in enumerate(op_list):
        bin_filename = bin_list_info.get("bin_filename")
        if bin_filename is None:
            continue
        bin_filename = bin_filename + "_" + impl_mole
        binary_json["op_list"][idx]["bin_filename"] = bin_filename

    wr_json(binary_json, new_json)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3])

