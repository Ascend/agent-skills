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

SCRIPT_NAME_OF_GEN_OPCINFO="gen_opcinfo_for_socversion.sh"
FILE_NAME="$(basename $0)"

source build_env.sh

main() {
  echo "[INFO]excute file: $0"
  if [ $# -lt 1 ]; then
    echo "[ERROR]input error"
    echo "[ERROR]bash $0 {soc_version}"
    exit 1
  fi
  local workdir=$(
    cd $(dirname $0)
    pwd
  )
  local topdir=$(readlink -f ${workdir}/../../..)
  local binary_param_dir=${topdir}/build/tbe
  local soc_version=$1
  local soc_version_lower=${soc_version,,}
  local binary_temp_conf_dir=${binary_param_dir}/temp
  if [ ! -d ${binary_temp_conf_dir} ]; then
    mkdir -p "${binary_temp_conf_dir}"
  fi
  local opc_info_csv="${binary_temp_conf_dir}/_${soc_version_lower}_tmp.csv"
  local gen_file="${workdir}/${SCRIPT_NAME_OF_GEN_OPCINFO}"
  local cmd="bash ${gen_file} ${soc_version} ${opc_info_csv}"
  ${cmd}
  echo "[INFO] end to gen opcinfo use ${SCRIPT_NAME_OF_GEN_OPCINFO}"
  exit 0
}
set -o pipefail
main "$@" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}'
