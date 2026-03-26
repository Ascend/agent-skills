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
import re
import argparse


def match_op_proto(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    op_def_pattern = re.compile(r"REG_OP\((.+)\).*OP_END_FACTORY_REG\(\1\)", re.DOTALL)
    match = op_def_pattern.search(content)

    if match:
        op_name = match.group(1)
        op_def = match.group(0)
        return op_name, op_def
    else:
        return None, None


# 收集op_proto_extend.h中的原型定义，可能有多个，返回数组
def match_op_proto_extend(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    op_def_pattern = re.compile(r"REG_OP\((.+)\).*OP_END_FACTORY_REG\(\1\)", re.DOTALL)
    matches = op_def_pattern.finditer(content)

    results = []
    for match in matches:
        op_name = match.group(1)
        op_def = match.group(0)
        results.append((op_name, op_def))
    return results


def merge_op_proto(protos_path, output_file):
    op_defs = []
    for proto_path in protos_path:
        print(f"proto_path: {proto_path}")
        if proto_path.endswith("_proto.h"):
            _, op_def = match_op_proto(proto_path)
            if op_def:
                op_defs.append(op_def)
        if proto_path.endswith("_proto_extend.h"):
            results = match_op_proto_extend(proto_path)
            for _, op_def in results:
                op_defs.append(op_def)

    # merge op_proto
    merged_content = f"""#ifndef OP_MATH_PROTO_H_
#define OP_MATH_PROTO_H_

#include "graph/operator_reg.h"
#include "register/op_impl_registry.h"

namespace ge{{

{os.linesep.join([f'{op_def}{os.linesep}' for op_def in op_defs])}
}}  // namespace ge

#endif // OP_MATH_PROTO_H_
"""

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(merged_content)

    print(f"merged op math proto file: {output_file}")


def parse_args(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("protos", nargs='+')
    parser.add_argument("--output-file", nargs=1, default=None)
    return parser.parse_args(argv)


if __name__ == "__main__":
    args = parse_args(sys.argv)
    
    protos_path = args.protos[1:]
    output_file = args.output_file[0]
    merge_op_proto(protos_path, output_file)