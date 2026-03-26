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

source get_threadnum_with_op.sh

main() {
  echo "[INFO]excute file: $0"
  if test $# -lt 3; then
    echo "[ERROR]input error"
    echo "[ERROR]bash $0 {op_type} {soc_version} {output_path} {opc_info_csv}(optional)"
    exit 1
  fi
  local op_type=$1
  local soc_version=$2
  local output_path=$3
  local enable_mssanitizer=$4
  local enable_debug=$5
  local enable_oom=$6
  local workdir=$(
    cd $(dirname $0)
    pwd
  )

  local task_path=$output_path/opc_cmd/$op_type
  test -d "$task_path/" || mkdir -p $task_path/
  rm -f $task_path/*

  bash build_binary_single_op_gen_task.sh $op_type $soc_version $output_path $task_path $enable_mssanitizer $enable_debug $enable_oom

  get_thread_num
  thread_num=$?

  bash build_binary_single_op_exe_task.sh $task_path $thread_num $output_path
}
set -o pipefail
main "$@" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}'
