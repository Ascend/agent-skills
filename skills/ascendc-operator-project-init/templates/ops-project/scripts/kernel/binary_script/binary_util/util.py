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
util.py
"""
import os
import json
import stat
import hashlib
import logging


class CompileParam:
    # op compile key
    SOC_INFO = "SocInfo"  # Camel keep History of code
    OP_LIST = "op_list"
    NAME = "name"
    DTYPE = "dtype"
    FORMAT = "format"
    SUB_FORMAT = "sub_format"
    SHAPE = "shape"
    INPUT = "input"
    ORI_SHAPE = "ori_shape"
    ORI_FORMAT = "ori_format"
    VALUE_LIST = "value_list"
    VALUE_RANGE = "value_range"
    RANGE_MODE = "range_mode"
    SIMPLE_KEY = "simplified_key"
    DTYPE_MATCH_MODE = "dtype_match_mode"
    FORMAT_MATCH_MODE = "format_match_mode"
    FORMAT_MODE = "formatMode"

    ID = "id"
    TYPE = "type"
    PATTERN = "pattern"
    OP_TYPE = "op_type"
    VALUE = "value"
    LIST = "list"
    LIST_LIST_INT = "list_list_int"
    DYNAMIC_IMPL = "is_dynamic_impl"
    INPUTS = "inputs"
    OUTPUTS = "outputs"
    ATTRS = "attrs"  # all attrs in ir graph, include op attrs and other information expressed using attrs
    ATTR = "attr"  # unuse
    RANGE = "range"
    ORI_RANGE = "ori_range"
    SHAPE_RANGE = "shape_range"
    OUTPUT_INDEX = "output_index"
    OP_ATTRS = "op_attrs"  # op real attrs
    OP_ATTRS_DESC = "attr_desc"  # op real attrs value list

    ADDR_TYPE = "addr_type"
    VALID_SHAPE = "valid_shape"
    SLICE_OFFSET = "slice_offset"
    L1_FUSION_TYPE = "L1_fusion_type"
    L1_ADDR_FLAG = "L1_addr_flag"
    L1_ADDR_OFFSET = "L1_addr_offset"
    L1_VALID_SIZE = "L1_valid_size"
    CONST_VALUE = "const_value"
    TOTAL_SHAPE = "total_shape"
    DYN_INDEX = "dyn_index"
    USE_L1_WORKSPACE = "use_L1_workspace"
    L1_WORKSPACE_SIZE = "L1_workspace_size"
    SPLIT_INDEX = "split_index"
    IS_FIRST_LAYER = "is_first_layer"

    GRAPH_PATTERN = "graph_pattern"
    INT64_MODE = "int64mode"
    L1_FUSION = "l1Fusion"
    L2_FUSION = "l2Fusion"
    L2_MODE = "l2Mode"
    L1_SIZE = "l1_size"
    OP_L1_SPACE = "op_L1_space"
    FUSION_OP_NAME = "fusion_op_name"
    STATUS_CHECK = "status_check"
    PARAM_TYPE = "paramType"


def wr_json(json_obj, json_file):
    flags = os.O_WRONLY | os.O_CREAT
    modes = stat.S_IWUSR | stat.S_IRUSR
    with os.fdopen(os.open(json_file, flags, modes), "w") as f:
        json.dump(json_obj, f, indent=2)


def generate_single_tensor_supportinfo(index, desc, is_inputs, is_support_info):
    """
    generate_single_tensor_supportinfo
    """
    op = {}
    if index != "" and is_support_info:
        op["id"] = index
    # "tensor field": if need to check is_support_info
    tensor_list = {
        CompileParam.DTYPE: False,
        CompileParam.FORMAT: False,
        CompileParam.ORI_FORMAT: True,
        CompileParam.SHAPE: False,
        CompileParam.ORI_SHAPE: True,
        CompileParam.RANGE: True,
        CompileParam.ORI_RANGE: True,
        CompileParam.ADDR_TYPE: True,
        CompileParam.USE_L1_WORKSPACE: True,
        CompileParam.L1_ADDR_FLAG: True,
        CompileParam.L1_FUSION_TYPE: True,
        CompileParam.SPLIT_INDEX: True,
        CompileParam.L1_WORKSPACE_SIZE: True,
        CompileParam.L1_ADDR_OFFSET: True,
        CompileParam.L1_VALID_SIZE: True,
        CompileParam.IS_FIRST_LAYER: True,
        CompileParam.SLICE_OFFSET: True,
        CompileParam.VALID_SHAPE: True,
        CompileParam.TOTAL_SHAPE: True,
    }
    for key in tensor_list:
        value = desc.get(key)
        if value is None:
            continue
        need_check_is_support_info = tensor_list.get(key)
        if need_check_is_support_info:
            if is_support_info:
                op[key] = value
        else:
            op[key] = value

    if is_inputs and is_support_info is False and op.get("dtype") == "bool":
        logging.debug("Change inputs dtype from bool to int8 when generate static key")
        op["dtype"] = "int8"
    logging.debug("generate single tensor: {}".format(str(op)))
    return op


def generate_op_attrs_static_key(op_info):
    """
    generate_op_attrs_static_key
    """
    attrs_list = []
    attrs = op_info.get("attrs")
    if attrs is None:
        return None
    for attr_val in attrs:
        attr = {}
        dtype = attr_val.get("dtype")
        value = attr_val.get("value")
        if dtype is not None:
            attr["dtype"] = dtype
        if dtype in ("bool", "string"):
            if value is not None:
                attr["value"] = value
        attrs_list.append(attr)
    logging.debug("Generate op static key attr is {}".format(str(attrs_list)))
    return attrs_list


def generate_op_inputs_or_outputs_supportinfo(op_info, is_inputs, is_support_info):
    """
    generate single op inputs or outputs supportinfo
    """

    def _get_tensor_info(tensor, is_inputs, is_support_info, inputs_or_output):
        index = ""
        info = generate_single_tensor_supportinfo(index, tensor, is_inputs, is_support_info)
        inputs_or_output.append(info)

    if op_info is None:
        return None
    inputs_or_outputs = []
    for op in op_info:
        if op is None:
            logging.debug("Op is none. Add none to inputs_or_outputs.")
            inputs_or_outputs.append(None)
            continue
        if isinstance(op, list):
            inputs_or_output = []
            for item in op:
                _get_tensor_info(item, is_inputs, is_support_info, inputs_or_output)
            inputs_or_outputs.append(inputs_or_output)
        else:
            _get_tensor_info(op, is_inputs, is_support_info, inputs_or_outputs)
    return inputs_or_outputs


def gen_notnone_param(support_info, key, value):
    """
    gen_notnone_param
    """
    support_info[key] = value


def generate_op_static_key(op_info):
    """
    generate_op_static_key
    """
    static_key_json = {}
    attrs = generate_op_attrs_static_key(op_info)
    gen_notnone_param(static_key_json, "attrs", attrs)
    inputs = generate_op_inputs_or_outputs_supportinfo(op_info.get("inputs"), True, False)
    gen_notnone_param(static_key_json, "inputs", inputs)
    outputs = generate_op_inputs_or_outputs_supportinfo(op_info.get("outputs"), False, True)
    gen_notnone_param(static_key_json, "outputs", outputs)
    static_key_json_str = json.dumps(static_key_json, separators=(',', ':'))
    static_key = hashlib.sha256(str(static_key_json_str).encode("utf-8")).hexdigest()
    debug_mes = "Generate op(Binfilename={}) static key is {}. static_key json is {}".format(
        op_info.get("bin_filename"), str(static_key), str(static_key_json_str))
    logging.debug(debug_mes)
    return static_key


def sha256_files(binary_file, json_obj):
    om_file_path = binary_file.split('json')[0] + 'om'
    with open(om_file_path, "rb") as f:
        sha256obj = hashlib.sha256()
        sha256obj.update(f.read())
        hash_value = sha256obj.hexdigest()
    json_obj["sha256"] = hash_value
    if "omKeyId" not in json_obj["supportInfo"]:
        static_key = generate_op_static_key(json_obj["supportInfo"])
        json_obj["supportInfo"]["implMode"] = "high_performance"
        json_obj["supportInfo"]["static_key"] = static_key
    return json_obj
