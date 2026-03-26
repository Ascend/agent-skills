#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
# -----------------------------------------------------------------------------------------------------------
# Copyright (c) 2025 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
# -----------------------------------------------------------------------------------------------------------

"""合并算子binary_info_config.json。"""

import argparse
import json
import os
import sys
from typing import List


def load_json_file(json_file: str):
    """加载json文件。"""
    with open(json_file, encoding='utf-8') as file:
        json_content = json.load(file)
    return json_content


def save_json_file(output_file: str, content):
    """保存json文件。"""
    output_dir = os.path.dirname(output_file)
    if not os.path.exists(output_dir):
        os.makedirs(output_dir, exist_ok=True)

    with open(output_file, 'w', encoding='utf-8') as file:
        json.dump(content, file, ensure_ascii=True, indent=2)


def update_config(base_content, update_content):
    """合并配置。"""
    merged = {}
    base_ops = list(base_content)
    update_ops = list(update_content)
    all_ops = list(dict.fromkeys(base_ops + update_ops))

    for op in all_ops:
        base_op = base_content.get(op, {})
        update_op = update_content.get(op, {})
        is_base_dict = isinstance(base_op, dict)
        is_update_dict = isinstance(update_op, dict)

        if not (is_base_dict and is_update_dict):
            merged[op] = _select_value(update_content, base_content, op)
            continue

        merged[op] = _merge_operator_config(base_op, update_op)

    return merged


def _select_value(update_content, base_content, key):
    """选择 update 或 base 中的值。"""
    if key in update_content:
        return update_content[key]
    return base_content.get(key)


def _merge_operator_config(base_op, update_op):
    """合并单个算子的配置，保留字段顺序并拼接 binaryList。"""
    base_fields = list(base_op)
    update_fields = list(update_op)
    fields_order = list(dict.fromkeys(base_fields + update_fields))
    new_op = {}

    has_binary_list = ("binaryList" in base_op) or ("binaryList" in update_op)

    if has_binary_list:
        combined_bl = _merge_binary_list(base_op, update_op)
        for field in fields_order:
            if field == "binaryList":
                new_op[field] = combined_bl
            else:
                new_op[field] = _get_merged_field_value(update_op, base_op, field)
    else:
        for field in fields_order:
            new_op[field] = _get_merged_field_value(update_op, base_op, field)

    return new_op


def _merge_binary_list(base_op, update_op):
    """拼接 binaryList，保持 base 在前、update 在后。"""
    base_bl = base_op.get("binaryList")
    update_bl = update_op.get("binaryList")
    base_list = base_bl if isinstance(base_bl, list) else []
    update_list = update_bl if isinstance(update_bl, list) else []
    return base_list + update_list


def _get_merged_field_value(update_op, base_op, field):
    """获取字段合并后的值：update 优先，fallback 到 base。"""
    if field in update_op:
        return update_op[field]
    return base_op.get(field)


def parse_args(argv: List[str]):
    """入参解析。"""
    parser = argparse.ArgumentParser()
    parser.add_argument('--base-file',
                        required=True,
                        help='the basic binary_info_config file')
    parser.add_argument('--update-file',
                        required=True,
                        help='the update binary_info_config file')
    parser.add_argument('--output-file',
                        required=True,
                        type=os.path.realpath,
                        help='the output binary_info_config file')
    args = parser.parse_args(argv)
    return args


def main(argv: List[str]) -> bool:
    """主流程。"""
    args = parse_args(argv)
    base_content = load_json_file(args.base_file)
    update_content = load_json_file(args.update_file)
    result = update_config(base_content, update_content)
    save_json_file(args.output_file, result)
    return True


if __name__ == '__main__':
    if not main(sys.argv[1:]):  # pragma: no cover
        sys.exit(1)  # pragma: no cover