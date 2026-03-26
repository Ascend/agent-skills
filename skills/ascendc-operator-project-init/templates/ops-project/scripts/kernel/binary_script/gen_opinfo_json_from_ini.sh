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
FILE_NAME="$(basename $0)"

main() {
  echo "[INFO]excute file: $0"
  if [ $# != 2 ]; then
    echo "[ERROR] ${FILE_NAME}:input error"
    echo "[ERROR] bash $0 soc_version output_json_file"
    exit 1
  fi
  soc_version=$1
  output_file=$2
  echo "[INFO] ${FILE_NAME}: arg1: ${soc_version}"
  echo "[INFO] ${FILE_NAME}: arg2: ${output_file}"
  # check
  local output_file_suffix=${output_file##*.}
  if [ "${output_file_suffix}" != "json" ]; then
    echo "[ERROR] ${FILE_NAME}: the output must be .json, but is ${output_file_suffix}"
    exit 1
  fi
  soc_version_lower=${soc_version,,}
  workdir=$(
            cd $(dirname $0)
            pwd
  )
  local topdir=$(readlink -f ${workdir}/../../..)
  local binary_config_dir=${topdir}/build/tbe/config
  ini_file="${binary_config_dir}/aic-${soc_version_lower}-ops-info.ini"  # modify ini path
  echo "[INFO]op ini path: ${ini_file}"
  if [ ! -f "${ini_file}" ]; then
    echo "[ERROR] ${FILE_NAME}: the ops ini file in env is not exited, return fail"
    exit 1
  fi

  parer_python_file="${workdir}/parser_ini.py"
  if [ ! -f "$parer_python_file" ]; then
    echo "[ERROR] ${FILE_NAME}: the ops parser file in env is not exited, return fail"
    exit 1
  fi
  python_arg=${HI_PYTHON}
  if [ "${python_arg}" = "" ]; then
    python_arg="python3"
  fi
  parer_cmd="${python_arg} ${parer_python_file} ${ini_file} ${output_file}"
  echo "[INFO]parser cmd: ${parer_cmd}"
  ${parer_cmd}
}
set -o pipefail
main "$@" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}'
