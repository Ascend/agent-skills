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
SCRIPT_NAME_OF_GEN_OPINFO="gen_opinfo_json_from_ini.sh"
SCRIPT_NAME_OF_GEN_OPCINFO="gen_opcinfo_from_opinfo.py"
FILE_NAME="$(basename $0)"

main() {
  echo "[INFO]excute file: $0"
  if [ $# -ne 2 ]; then
    echo "[ERROR] ${FILE_NAME}: input error"
    echo "[ERROR] bash $0 soc_version out_opcinfo_csv_file"
    exit 1
  fi
  local soc_version=$1
  local out_opcinfo_csv_file=$2
  echo "[INFO] ${FILE_NAME}: arg1: ${soc_version}"
  echo "[INFO] ${FILE_NAME}: arg2: ${out_opcinfo_csv_file}"
  # check
  if [ -e ${out_opcinfo_csv_file} ]; then
    echo "[INFO] opcinfo exists: ${out_opcinfo_csv_file}"
    exit 0
  fi
  local output_file_extrnsion=${out_opcinfo_csv_file##*.}
  if [ "${output_file_extrnsion}" != "csv" ]; then
    echo "[ERROR]the output must be .csv, but is ${output_file_extrnsion}"
    exit 1
  fi
  local soc_version_lower=${soc_version,,}
  local workdir=$(
            cd $(dirname $0)
            pwd
  )
  local topdir=$(readlink -f ${workdir}/../../..)
  local binary_temp_conf_dir=${topdir}/build/tbe/temp
  local script_file0="${workdir}/${SCRIPT_NAME_OF_GEN_OPINFO}"
  echo "[INFO] ${FILE_NAME}: gen opinfo script path: ${script_file0}"
  if [ ! -f "${script_file0}" ]; then
    echo "[ERROR] ${FILE_NAME}: gen opinfo script path is not exited, return fail"
    exit 1
  fi
  local script_file1="${workdir}/${SCRIPT_NAME_OF_GEN_OPCINFO}"
  echo "[INFO] gen opcinfo script path: ${script_file1}"
  if [ ! -f "${script_file1}" ]; then
    echo "[ERROR] ${FILE_NAME}: gen opcinfo script path is not exited, return fail"
    exit 1
  fi
  # step 1. gen opinfo json from ini opinfo with script gen_opinfo_json_from_ini.sh
  local workspace_json_file="${binary_temp_conf_dir}/_${soc_version_lower}.json"
  local gen_cmd="bash ${script_file0} ${soc_version} ${workspace_json_file}"
  ${gen_cmd}
  if [ $? -ne 0 ]; then
    echo "[ERROR]exe failed"
    exit 1
  fi

  # step2. gen opcinfo csv with script gen_opcinfo_from_opinfo.py
  python_arg=${HI_PYTHON}
  if [ "${python_arg}" = "" ]; then
    python_arg="python3"
  fi
  local cann_pkg_json_file=${ASCEND_OPP_PATH}/built-in/op_impl/ai_core/tbe/config/${soc_version_lower}/aic-${soc_version_lower}-ops-info.json
  if ! test -f ${cann_pkg_json_file}; then
    cann_pkg_json_file=""
  fi
  local parer_cmd="${python_arg} ${script_file1} ${workspace_json_file} ${cann_pkg_json_file} ${out_opcinfo_csv_file}"
  echo "[INFO] parser cmd: ${parer_cmd}"
  ${parer_cmd}
}
set -o pipefail
main "$@" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}'
