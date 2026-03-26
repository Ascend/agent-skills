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
gen_output_json.py
"""
import argparse
import copy
import json
import os
import sys
from pathlib import Path

from binary_util.util import wr_json
from binary_util.util import generate_op_static_key

DATA_TYPE_DICT = {
    'float32': 0,
    'float16': 1,
    'int8': 2,
    'int32': 3,
    'uint8': 4,
    'int16': 6,
    'uint16': 7,
    'uint32': 8,
    'int64': 9,
    'uint64': 10,
    'double': 11,
    'float64': 11,
    'bool': 12,
    'complex64': 16,
    'complex128': 17,
    'qint8': 18,
    'qint16': 19,
    'qint32': 20,
    'quint8': 21,
    'quint16': 22,
    'resource': 23,
    'dual': 25,
    'variant': 26,
    'bf16': 27,
    'bfloat16': 27,
    'int4': 29,
    'uint1': 30,
    'int2': 31,
    'uint2': 32
}
BFLOAT16_SUPPORT_MAP = {
    "All": ["ascend950", "ascend910b", "ascend910_93", "ascend310b"],
    "Conv2DBackpropFilter": ["ascend910b", "ascend910_93", "ascend950"],
    "Conv3DBackpropFilter": ["ascend910b", "ascend910_93", "ascend950"],
    "MatMul": ["ascend910b", "ascend910_93", "ascend950"]
}
OPS_REUSE_BINARY = ["Conv2DBackpropFilter", "Conv3DBackpropFilter"]
ReuseBinary = [
    # Note: Only define one reuse rule Per number in this list.
    {"opp": "SplitV", "new_dtype": "int64", "reuse_dtype": "int32",
     "input_args": [2],  # the input argument which need replace
     "output_args": [],  # the output argument which need replace
     "support_map": ["ascend950", "ascend910_93", "ascend910b", "ascend910", "ascend310p"]}
]


def generate_operator_json_content(input_json, kernel_output, json_content):
    """
    gen output json by input_json and opc json file
    """
    with open(input_json, "r") as file_wr:
        binary_json = json.load(file_wr)

    op_type = binary_json.get("op_type")
    for item in binary_json.get("op_list"):
        opc_json_file_name = item.get("bin_filename")
        expect_outputs = [f"{kernel_output}{opc_json_file_name}.json",
                          f"{kernel_output}{opc_json_file_name}_deterministic.json"]
        opc_json_outputs = list(filter(lambda fname: os.path.isfile(fname), expect_outputs))
        if len(opc_json_outputs) == 0:
            print(f"[WARNING]the kernel {opc_json_file_name} not generate output json")
            print(f"[WARNING]the kernel {opc_json_file_name} is {item}")

            failed_json_file_name = opc_json_file_name + "_failed"
            failed_json_file = kernel_output + failed_json_file_name + ".json"
            if os.path.exists(failed_json_file):
                os.remove(failed_json_file)
            continue
        for opc_json_file_path in opc_json_outputs:
            with open(opc_json_file_path, "r") as file_opc:
                opc_info_json = json.load(file_opc)
            # adjust delimiter depends on binary path
            json_file_path = opc_json_file_path.split("/bin/")[-1]
            one_binary_case_info = opc_info_json.get("supportInfo")
            one_binary_case_info["binInfo"] = {"jsonFilePath": json_file_path}
            json_content.get("binList").append(one_binary_case_info)
            platform_name = json_file_path.split("/")[0]
            if ("MatMulV2" in opc_json_file_name
                    and platform_name in BFLOAT16_SUPPORT_MAP.get("MatMul", BFLOAT16_SUPPORT_MAP.get("All"))):
                bf16_reuse_fp16(one_binary_case_info, json_content, input_num=2, output_num=1)
            elif (op_type in OPS_REUSE_BINARY
                  and platform_name in BFLOAT16_SUPPORT_MAP.get(op_type, BFLOAT16_SUPPORT_MAP.get("All"))):
                bf16_reuse_fp16(one_binary_case_info, json_content, input_num=3, output_num=1)
            binary_dtype_reuse(platform_name, op_type, one_binary_case_info, json_content)


def bf16_reuse_fp16(src_info, new_info, input_num, output_num):
    need_insert_json_block = False
    new_support_info = copy.deepcopy(src_info)
    new_support_info.pop("staticKey")
    for index in range(input_num):
        if src_info["inputs"][index]["dtype"] == "float16":
            new_support_info["inputs"][index]["dtype"] = "bfloat16"
            need_insert_json_block = True
    for index in range(output_num):
        if src_info["outputs"][index]["dtype"] == "float16":
            new_support_info["outputs"][index]["dtype"] = "bfloat16"
            need_insert_json_block = True
    if need_insert_json_block:
        new_info.get("binList").append(new_support_info)


def binary_dtype_reuse(platform_name, op_type, src_info, new_info) -> None:
    """
    Construct a new binary json file/node with reuse_info, only handle dtype
    """

    def _get_offset(args_lists) -> int:
        offset = 0
        for s in reversed(args_lists):
            if s.find("=") >= 0:
                break
            offset = offset + 1
        return offset

    def _update_simplified_key(key_lists, dtype_new) -> list:
        new_keys = []
        for args_keys in key_lists:
            args_list = args_keys.split("/")
            args_offset = len(args_list) - _get_offset(args_list)
            _, f_idx = args_list[args_offset + index].split(",")
            args_list[args_offset + index] = f"{DATA_TYPE_DICT[dtype_new]}" + "," + f"{f_idx}"
            new_keys.append('/'.join(args_list))
        return new_keys

    for reuse_info in ReuseBinary:
        if reuse_info.get("opp") != op_type or platform_name not in reuse_info.get("support_map"):
            continue
        new_dtype = reuse_info.get("new_dtype")
        reuse_dtype = reuse_info.get("reuse_dtype")
        input_args = reuse_info.get("input_args")
        output_args = reuse_info.get("output_args")

        need_insert_json_block: bool = False
        new_support_info = copy.deepcopy(src_info)
        for index in input_args:
            if src_info["inputs"][index]["dtype"] == reuse_dtype:
                ori_keys = new_support_info.get("simplifiedKey")
                new_support_info.update({"simplifiedKey": _update_simplified_key(ori_keys, new_dtype)})
                new_support_info["inputs"][index]["dtype"] = new_dtype
                need_insert_json_block = True
        for index in output_args:
            if src_info["outputs"][index]["dtype"] == reuse_dtype:
                new_support_info["outputs"][index]["dtype"] = new_dtype
                need_insert_json_block = True
        if need_insert_json_block:
            static_key = generate_op_static_key(new_support_info)
            new_support_info.update({"staticKey": static_key})
            new_info.get("binList").append(new_support_info)


def main(binary_file, kernel_output, output_json, number):
    """
    gen output json by binary_file and opc json file
    """
    if not os.path.exists(kernel_output):
        print(f"[ERROR] the kernel_output {kernel_output} doesnt exist")
        return

    output_json_path = Path(output_json)
    if output_json_path.is_file():
        json_content = json.loads(output_json_path.read_text())
    else:
        json_content = dict()
        json_content["binList"] = []

    input_jsons = []
    if number != 0:
        input_jsons = [f"{binary_file}_{i}" for i in range(number)]
    else:
        input_jsons.append(binary_file)

    for input_json in input_jsons:
        generate_operator_json_content(input_json, kernel_output, json_content)

    output_json_path = Path(output_json)
    wr_json(json_content, output_json)


def parse_args(argv):
    """Command line parameter parsing"""
    parser = argparse.ArgumentParser()
    parser.add_argument('argv', nargs='+')
    parser.add_argument('-n',
                        '--dtype-num',
                        nargs='?',
                        type=int,
                        default=0)
    return parser.parse_args(argv)


if __name__ == '__main__':
    args = parse_args(sys.argv)
    main(args.argv[1], args.argv[2], args.argv[3], args.dtype_num)
