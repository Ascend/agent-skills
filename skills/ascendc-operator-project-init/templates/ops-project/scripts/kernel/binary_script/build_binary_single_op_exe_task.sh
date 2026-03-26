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
  if [ $# -lt 3 ]; then
    echo "[ERROR]input error"
    echo "[ERROR]bash $0 {task_path} {compile_thread_num} {out_path}"

    exit 1
  fi
  local task_path=$1
  local compile_thread_num=$2
  if [ ${compile_thread_num} -lt 1 ]; then
    echo "[INFO]will set compile_thread_num = 1, the compile_thread_num < 1"
    compile_thread_num=1
  fi
  local output_path="$3"
  mkdir -p $output_path/build_logs/

  source build_env.sh
  opc_cmd_file="${task_path}/${OPC_TASK_NAME}"
  out_cmd_file="${task_path}/${OUT_TASK_NAME}"
  echo "[INFO]exe_task: opc_cmd_file = ${opc_cmd_file}"
  echo "[INFO]exe_task: out_cmd_file = ${out_cmd_file}"
  echo "[INFO]exe_task: compile_thread_num = ${compile_thread_num}"

  CURRENT_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
  local topdir=$(readlink -f ${workdir}/../../..)
  local op_cache_dir=${topdir}/vendor/hisi/build/scripts/op_cache
  if [ -d "${op_cache_dir}" ] && [ "${OP_CACHE_ENABLE}" == "true" ]; then # not exist
    exist_op_cache=true
    python3 ${op_cache_dir}/op_make_hash.py make_public_hash
  fi
  local error_flag_file="${output_path}/build_logs/.compile_error"
  rm -f "${error_flag_file}"

  # step1: do compile kernel with compile_thread_num
  [ -e /tmp/binary_exe_task ] || mkfifo /tmp/binary_exe_task
  exec 8<> /tmp/binary_exe_task  # 创建文件描述符8
  rm -rf /tmp/binary_exe_task
  for ((i = 1; i <= ${compile_thread_num}; i++)); do
    echo >&8
  done

  opc_list_num=$(cat ${opc_cmd_file} | wc -l)
  random_opc_nums=$(shuf -i  1-${opc_list_num})
  local pids=()
  for i in ${random_opc_nums}; do
    # 如果已有编译失败，跳过剩余任务
    if [ -f "${error_flag_file}" ]; then
      echo "[ERROR]build kernel failed, stop all build"
      break
    fi
    read -u8
    {
      set +e
      if [ -f "${error_flag_file}" ]; then
        echo >&8
        exit 0
      fi
      cmd_task=$(sed -n ''${i}'p;' ${opc_cmd_file})
      key=$(echo "${cmd_task}" | grep -oP '\w*\.json_\d*')
      echo "[INFO]exe_task: begin to build kernel with cmd: ${cmd_task}."
      start_time=$(date +%s)
      # avoid the opc processe from hanging

      if [ "${exist_op_cache}" == "true" ]; then
        echo "python3 ${op_cache_dir}/op_cache.py -- ${cmd_task}" > "${output_path}/build_logs/${key}.log"
        python3 ${op_cache_dir}/op_cache.py -- ${cmd_task} >> "${output_path}/build_logs/${key}.log" 2>&1
      else
        echo ${cmd_task} > "${output_path}/build_logs/${key}.log"
        timeout 7200 ${cmd_task} >> "${output_path}/build_logs/${key}.log" 2>&1
      fi

      if grep -qi 'error:' "${output_path}/build_logs/${key}.log"; then
        # 标记编译失败
        touch "${error_flag_file}"
        
        echo "[ERROR]exe_task: ${cmd_task}"
        echo "[ERROR]exe_task error log: ${output_path}/build_logs/${key}.log"
        echo "[ERROR]exe_task error detail:"
        echo "------------------------------------------------------------"
        cat "${output_path}/build_logs/${key}.log"
        echo "============================================================"
        
        echo >&8
        exit 1
      fi

      end_time=$(date +%s)
      exe_time=$((end_time - start_time))
      echo "[INFO]exe_task: end to build kernel with cmd: ${cmd_task} --exe_time=${exe_time}"
      echo >&8
    } &
    pids+=($!)
  done
  wait  # 等待所有的算子编译结束

  if [ -f "${error_flag_file}" ]; then
    rm -f "${error_flag_file}"
    exit 1
  fi
  # step2: gen output one by one
  cat ${out_cmd_file} | while read cmd_task; do
    echo "[INFO]exe_task: begin to gen kernel list with cmd: ${cmd_task}."
    ${cmd_task}
  done
  rm -f "${error_flag_file}"
}
set -o pipefail
main "$@" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}'
