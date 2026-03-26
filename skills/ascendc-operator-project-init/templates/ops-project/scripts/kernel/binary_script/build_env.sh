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

declare -A SOC_MAP
SOC_MAP=([Ascend310P]="Ascend310P3"
          [Ascend310B]="Ascend310B1"
          [Ascend910]="Ascend910A"
          [Ascend910B]="Ascend910B1"
          [Ascend910_93]="Ascend910_9391"
          [Ascend950]="Ascend950PR_9599"
          [KirinX90]="KirinX90"
          [Kirin9030]="Kirin9030"
)

OPC_TASK_NAME="opc_cmd.sh"
OUT_TASK_NAME="out_cmd.sh"
OP_CATEGORY_LIST="ops"

function trans_soc() {
  local _soc_input=$1
  local _soc_input_lower=${_soc_input,,}
  for key in ${!SOC_MAP[*]}; do
    key_lower=${key,,}
    if [ "${_soc_input_lower}" == "${key_lower}" ]; then
      echo ${SOC_MAP[$key]}
      return
    fi
  done

  echo ${_soc_input}
}
