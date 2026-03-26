#!/bin/bash
# ----------------------------------------------------------------------------
# Copyright (c) 2025 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
# ----------------------------------------------------------------------------

function get_thread_num() {
  local _thread_num=1
  _thread_num=$(cat /proc/cpuinfo | grep "processor" | wc -l)
  if [ "${_thread_num}" == "" ]; then
     return 1
  fi
  return ${_thread_num}
}

function get_thread_num_with_json_config() {
  local _thread_num=1
  local _binary_config_full_path=$1
  local _core_num=$(cat /proc/cpuinfo | grep "processor" | wc -l)
  _thread_num=$(cat ${_binary_config_full_path} | grep bin_filename | wc -l)
  if [ "${_thread_num}" == "" ]; then
     return 1
  fi
  if [ ${_thread_num} -gt ${_core_num} ]; then
     return ${_core_num}
  fi
  return ${_thread_num}
}
