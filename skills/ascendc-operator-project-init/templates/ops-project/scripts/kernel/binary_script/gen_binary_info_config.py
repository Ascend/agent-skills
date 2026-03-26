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

import os
import sys
import json
import glob
import stat
from typing import List
from typing import Dict
from copy import copy

WFLAGS = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
WMODES = stat.S_IWUSR | stat.S_IRUSR
CORE_TYPE = {'MIX': 0, 'AiCore': 1, 'VectorCore': 2, 'MIX_AICORE': 3, 'MIX_VECTOR_CORE': 4, 'MIX_AIV': 4}

need_to_cut_op = []
optional_op = []
no_simpliy_key_op = []
optional_op_dict = {}
simplified_mode_not_same_op = []
optional_mode_not_same_op = []


def load_json(json_file: str):
    with open(json_file, encoding='utf-8') as file:
        json_content = json.load(file)
    return json_content


def get_specified_suffix_file(root_dir, suffix):
    specified_suffix = os.path.join(root_dir, '**/*{}'.format(suffix))
    all_suffix_files = glob.glob(specified_suffix, recursive=True)
    return all_suffix_files


def gen_notnone_param(support_info, key, value):
    '''
    gen not none param to supportInfo
    '''
    if value is None:
        return
    support_info[key] = value


def correct_format_mode(format_mode):
    if format_mode == 'FormatDefault':
        return 'nd_agnostic'
    if format_mode == 'FormatAgnostic':
        return 'static_nd_agnostic'
    if format_mode == 'FormatFixed':
        return 'normal'
    return format_mode


def gen_input_or_output_config(in_or_out):
    in_dict = {}
    name = in_or_out.get('name')
    index = in_or_out.get('index')
    param_type = in_or_out.get('paramType')
    dtype_mode = in_or_out.get('dtype_match_mode')
    format_mode = in_or_out.get('format_match_mode')
    if dtype_mode == 'DtypeByte':
        dtype_mode = 'bit'
    format_mode = correct_format_mode(format_mode)
    gen_notnone_param(in_dict, 'name', name)
    gen_notnone_param(in_dict, 'index', index)
    gen_notnone_param(in_dict, 'paramType', param_type)
    gen_notnone_param(in_dict, 'dtypeMode', dtype_mode)
    gen_notnone_param(in_dict, 'formatMode', format_mode)
    return in_dict


def gen_inputs_or_outputs_config(op_type, inputs_or_outputs):
    if inputs_or_outputs is None:
        return None
    inputs_or_outputs_list = []
    tmp_list = []
    for in_or_out in inputs_or_outputs:
        if in_or_out is None:
            if op_type not in optional_op:
                optional_op.append(op_type)
            return ['optional']
        if isinstance(in_or_out, dict):
            in_dict = gen_input_or_output_config(in_or_out)
            inputs_or_outputs_list.append(in_dict)
        if isinstance(in_or_out, list):
            io = in_or_out[0]
            param_type = io.get('paramType')
            if param_type == 'dynamic':
                in_dict = gen_input_or_output_config(io)
                tmp_list.append(in_dict)
                inputs_or_outputs_list.append(tmp_list)
    return inputs_or_outputs_list


def gen_attrs_config(attrs):
    if attrs is None:
        return None
    attrs_list = []
    for attr in attrs:
        attrs_dict = {}
        if attr is None:
            attrs_list.append(None)
            continue
        name = attr.get('name')
        mode = attr.get('mode')
        gen_notnone_param(attrs_dict, 'name', name)
        gen_notnone_param(attrs_dict, 'mode', mode)
        attrs_list.append(attrs_dict)
    return attrs_list


def gen_params_config(op_type, support_info):
    params_dict = {}
    inputs = support_info.get('inputs')
    outputs = support_info.get('outputs')
    attrs = support_info.get('attrs')
    inputs_list = gen_inputs_or_outputs_config(op_type, inputs)
    outputs_list = gen_inputs_or_outputs_config(op_type, outputs)
    attrs_list = gen_attrs_config(attrs)
    gen_notnone_param(params_dict, 'inputs', inputs_list)
    gen_notnone_param(params_dict, 'outputs', outputs_list)
    gen_notnone_param(params_dict, 'attrs', attrs_list)
    flag = inputs_list != ['optional'] and outputs_list != ['optional'] and attrs_list != ['optional']
    if flag:
        optional_op_dict[op_type] = params_dict
    return params_dict


def judge_params_info(old_params_dict, params_dict):
    if old_params_dict == params_dict:
        return True

    for key in old_params_dict.keys():
        info1 = old_params_dict.get(key)
        info2 = params_dict.get(key)
        if len(info1) != len(info2):
            return False
        if key == "attrs":
            continue
        for i, _ in enumerate(info1):
            if isinstance(info1[i], dict):
                differ = set(info1[i].items()) ^ set(info2[i].items())
                if differ != {('formatMode', 'normal')} and differ:
                    return False
            if isinstance(info1[i], list):
                differ1 = set(info1[i][0].items()) ^ set(info2[i][0].items())
                if differ1 != {('formatMode', 'normal')} and differ1:
                    return False
    return True


def add_simplified_config(op_type, core_type, task_ration, support_info, bin_path, config):
    op_cfg = config.get(op_type)
    key_mode = support_info.get('simplifiedKeyMode')
    optional_input_mode = support_info.get('optionalInputMode')
    optional_output_mode = support_info.get('optionalOutputMode')
    params_dict = gen_params_config(op_type, support_info)
    json_path = bin_path.split('.')[0] + '.json'
    if op_cfg:
        old_key_mode = op_cfg.get('simplifiedKeyMode')
        old_params_dict = op_cfg.get('params')
        old_optional_input_mode = op_cfg.get('optionalInputMode')
        old_optional_output_mode = op_cfg.get('optionalOutputMode')
        if key_mode != old_key_mode and op_type not in simplified_mode_not_same_op:
            print('[WARNING] op_type {} old simplifiedKeyMode is {}, new simplifiedKeyMode \
                  is {}'.format(op_type, old_key_mode, key_mode))
            simplified_mode_not_same_op.append(op_type)
        flag = (op_cfg.get('params') is not None) and (op_type not in optional_op) and (op_type not in need_to_cut_op)
        params_flag = judge_params_info(old_params_dict, params_dict)
        if flag and not params_flag:
            print('[WARNING] op_type is {}, old_params_dict is {}, new_params_dict \
                  is {}'.format(op_type, op_cfg.get('params'), params_dict))
            need_to_cut_op.append(op_type)
        if (optional_input_mode != old_optional_input_mode or optional_output_mode != old_optional_output_mode) and \
            op_type not in optional_mode_not_same_op:
            print('[WARNING] op_type {} old optionalInputMode is {}, new optionalInputMode \
                    is {}, old optionalOutputMode is {}, new optionalOutputMode is {}'.format( \
                    op_type, old_optional_input_mode, optional_input_mode, \
                    old_optional_output_mode, optional_output_mode))
            optional_mode_not_same_op.append(op_type)
    else:
        op_cfg = {}
        gen_notnone_param(op_cfg, 'dynamicRankSupport', True)
        gen_notnone_param(op_cfg, 'simplifiedKeyMode', key_mode)
        gen_notnone_param(op_cfg, 'optionalInputMode', optional_input_mode)
        if optional_output_mode is not None:
            gen_notnone_param(op_cfg, 'optionalOutputMode', optional_output_mode)
        gen_notnone_param(op_cfg, 'params', params_dict)
        op_cfg['binaryList'] = []
        config[op_type] = op_cfg
    bin_list = op_cfg.get('binaryList')
    simlified_key = support_info.get('simplifiedKey')
    if core_type == 0 and task_ration == "tilingKey":
        bin_list.append({'coreType': core_type, 'simplifiedKey': simlified_key, 'multiKernelType': 1,
                         'binPath': bin_path, 'jsonPath': json_path})
    else:
        bin_list.append({'coreType': core_type, 'simplifiedKey': simlified_key,
                         'binPath': bin_path, 'jsonPath': json_path})


def gen_ops_config(json_file, soc, config):
    contents = load_json(json_file)
    if ('binFileName' not in contents) or ('supportInfo' not in contents):
        print("[gen_binary_info_config][gen_ops_config] binFileName or supportInfo is None")
        return
    op_dir = os.path.basename(os.path.dirname(json_file))
    support_info = contents.get('supportInfo')
    bin_name = contents.get('binFileName')
    bin_suffix = contents.get('binFileSuffix')
    core_type = contents.get("coreType")
    task_ration = contents.get("taskRation")
    core_type = CORE_TYPE.get(core_type, -1)
    bin_file_name = bin_name + bin_suffix
    bin_path = os.path.join(soc, op_dir, bin_file_name)
    op_type = bin_name.split('_')[0]
    if support_info.get('simplifiedKey') is not None:
        add_simplified_config(op_type, core_type, task_ration, support_info, bin_path, config)
    else:
        if op_type not in no_simpliy_key_op:
            no_simpliy_key_op.append(op_type)


def del_params_info_not_same_op(config):
    if not need_to_cut_op:
        return
    print(f'[WARNING] op_type[{need_to_cut_op}] params info is not same, cannot be write into binary_info_config.json')
    for op in need_to_cut_op:
        if config.get(op) is not None:
            del config[op]


def del_simply_mode_not_same(config):
    if not simplified_mode_not_same_op:
        return
    print(f'[WARNING] op_type[{simplified_mode_not_same_op}] simplifiedKeyMode is not same, '
          'cannot be write into binary_info_config.json')
    for op in simplified_mode_not_same_op:
        if config.get(op) is not None:
            del config[op]


def del_null_simply_key_op(config):
    if not no_simpliy_key_op:
        return
    print(f'[WARNING] op_type[{no_simpliy_key_op}] simplifiedKey is none, cannot be write into binary_info_config.json')
    for op in no_simpliy_key_op:
        if config.get(op) is not None:
            del config[op]


def correct_optional_op_params_info(config):
    for op_type in optional_op:
        if op_type not in optional_op_dict.keys():
            print(f'[WARNING] op_type[{op_type}] contain null inputs/output/attrs, '
                  'cannot be written into binary_info_config.json')
            if config.get(op_type) is not None:
                del config[op_type]
        else:
            if config.get(op_type) is not None and config.get(op_type).get('params') is not None:
                try:
                    config[op_type]['params'] = optional_op_dict[op_type]
                except KeyError:
                    print('op_type[{}] do not have key: params'.format(op_type))


def del_optional_mode_not_same_op(config):
    if not optional_mode_not_same_op:
        return
    print(f'[WARNING] op_type[{optional_mode_not_same_op}] optionalInputMode is none, '
          'cannot be write into binary_info_config.json')
    for op in optional_mode_not_same_op:
        if config.get(op) is not None:
            del config[op]


def modify_binary_list_with_config(binary_cfg: dict, cfg_dir: str):
    def _update_binary_list(config_json, update_json) -> bool:
        update_flags = False
        json_file_path = config_json.get("binInfo").get("jsonFilePath")
        for bin_json in binary_list:
            if json_file_path != bin_json.get("jsonPath") or \
                    config_json.get("simplifiedKey") == bin_json.get("simplifiedKey"):
                continue
            _tmp_json = copy(bin_json)
            _tmp_json.update({"simplifiedKey": config_json.get("simplifiedKey")})
            update_json.append(_tmp_json)
            update_flags = True
        return update_flags

    for optype in binary_cfg.keys():
        binary_list: List[Dict] = binary_cfg.get(optype).get("binaryList")
        if not binary_list:
            continue
        ops_cfg_file = os.path.join(cfg_dir,
                                    f"{binary_list[0].get('jsonPath').split('/')[1]}.json")
        if not os.path.exists(ops_cfg_file):
            continue
        ops_cfg_json: dict = load_json(ops_cfg_file)
        if len(ops_cfg_json.get("binList")) == len(binary_cfg.get(optype).get("binaryList")):
            continue
        attach_json: List[Dict] = copy(binary_list)
        binary_list_update_flags = False
        cfg_json_binlist = copy(ops_cfg_json.get("binList"))
        while cfg_json_binlist:
            cfg_json = cfg_json_binlist.pop()
            if _update_binary_list(cfg_json, attach_json):
                binary_list_update_flags = True
        if binary_list_update_flags:
            binary_cfg[optype].update({"binaryList": attach_json})


def gen_binary_info_config(kernel_dir, soc):
    config = {}
    bin_dir = os.path.join(kernel_dir, soc)
    cfg_dir = os.path.join(kernel_dir, 'config', soc)
    all_jsons = get_specified_suffix_file(bin_dir, '.json')
    relocatable_jsons = get_specified_suffix_file(bin_dir, '_relocatable.json')
    normal_jsons = list(set(all_jsons) - set(relocatable_jsons))
    normal_jsons.sort()

    for _json in normal_jsons:
        if "fusion_ops" in _json:
            continue
        gen_ops_config(_json, soc, config)
    print("[gen_binary_info_config] config.keys is ", config.keys())
    modify_binary_list_with_config(config, cfg_dir)
    del_params_info_not_same_op(config)
    del_simply_mode_not_same(config)
    correct_optional_op_params_info(config)
    del_null_simply_key_op(config)
    del_optional_mode_not_same_op(config)
    config = dict(sorted(config.items()))
    for op, info in config.items():
        bin_list = info.get('binaryList')
        bin_list = sorted(bin_list, key=lambda x: x['binPath'])
        info['binaryList'] = bin_list

    cfg_file = os.path.join(cfg_dir, 'binary_info_config.json')
    if len(config.keys()) <= 0:
        print('[WARNING]no simplified key found', soc)
        return
    print('write', cfg_file)
    with os.fdopen(os.open(cfg_file, WFLAGS, WMODES), 'w') as fd:
        json.dump(config, fd, indent='  ')


if __name__ == '__main__':
    if len(sys.argv) <= 2:
        raise RuntimeError('arguments must greater equal than 2')
    gen_binary_info_config(sys.argv[1], sys.argv[2])
