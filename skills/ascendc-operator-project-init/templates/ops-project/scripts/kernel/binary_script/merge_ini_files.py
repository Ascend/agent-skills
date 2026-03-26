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
import argparse
import configparser


def merge_ini_files(ini_files, output_file):
    """
    将多个ini文件合并成一个, 如果有重复的section, 则跳过该section
    """
    if not ini_files:
        print("[ERROR] No ini files input.")
        return
    
    merged_config = configparser.RawConfigParser()
    merged_config.optionxform = str

    for ini_file in ini_files:
        if not os.path.exists(ini_file):
            print(f"[Warnig] ini file {ini_file} not exist, skip")
            continue

        try:
            temp_config = configparser.RawConfigParser()
            temp_config.optionxform = str
            temp_config.read(ini_file, encoding='utf-8')

            for section in temp_config.sections():
                if not merged_config.has_section(section):
                    merged_config.add_section(section)
                    for key, value in temp_config.items(section):
                        merged_config.set(section, key, value)
                else:
                    print(f"[Info] ini file {ini_file} section {section} has existed, skip")
        except Exception as e:
            print(f"[ERROR] read ini file {ini_file} failed, skip")
            continue

    try:
        with open(output_file, "w", encoding='utf-8') as f:
            merged_config.write(f)
        print(f"[Info] ini files success merged to {output_file}")
    except Exception as e:
        print(f"[ERROR] merge ini files failed: {e}")


def parse_args(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("argv", nargs='+')
    parser.add_argument("--output-file", nargs=1, default=None)
    return parser.parse_args(argv)

if __name__ == "__main__":
    args = parse_args(sys.argv)

    if len(args.argv) <= 1:
        raise RuntimeError("ini files must greater equal than 1")
    
    ini_files = args.argv[1:]
    output_file = args.output_file[0]
    merge_ini_files(ini_files, output_file)
