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

set -e

main() {
  echo "[INFO]excute file: $0"
  if [ $# -lt 2 ]; then
    echo "[ERROR]input error"
    echo "[ERROR]bash $0 {out_path} {task_id}"
    exit 1
  fi
  local output_path="$1"
  local idx="$2"
  local workdir=$(
    cd $(dirname $0)
    pwd
  )
  local task_path=$output_path/opc_cmd
  mkdir -p $output_path/build_logs/
  source build_env.sh
  opc_cmd_file="${task_path}/${OPC_TASK_NAME}"
  out_cmd_file="${task_path}/${OUT_TASK_NAME}"
  echo "[INFO]exe_task: opc_cmd_file = ${opc_cmd_file}"
  echo "[INFO]exe_task: out_cmd_file = ${out_cmd_file}"
  if [ ! -f ${opc_cmd_file} ]; then
    return
  fi

  # step1: do compile kernel
  set +e
  cmd_task=$(sed -n ''${idx}'p;' ${opc_cmd_file})
  key=$(echo "${cmd_task}" | grep -oP '\w*\.json_\d*')
  echo "[INFO]exe_task: begin to build kernel with cmd: ${cmd_task}."
  start_time=$(date +%s)
  log_file="${output_path}/build_logs/${key}.log"

  start_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$start_timestamp] Build started: ${cmd_task}" > "$log_file"
  timeout 7200 ${cmd_task} >> "${log_file}" 2>&1
  compile_rc=$?
  set -e  

  end_time=$(date +%s)
  exe_time=$((end_time - start_time))
  end_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$end_timestamp] exe_time: $exe_time s" >> "$log_file"
  if [ ${compile_rc} -ne 0 ]; then
    cat ${log_file}
    if [ ${compile_rc} -eq 124 ]; then
      echo "[ERROR]exe_task: build kernel TIMEOUT, exe_time: ${exe_time}. Run this command again for debug: ${cmd_task}."
    else
      echo "[ERROR]exe_task: build kernel FAILED, exe_time: ${exe_time}. Run this command again for debug: ${cmd_task}."
    fi
    exit ${compile_rc}
  fi
  echo "[INFO]exe_task: end to build kernel with cmd: ${cmd_task} --exe_time=${exe_time}"
}
set -o pipefail
main "$@" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}'
