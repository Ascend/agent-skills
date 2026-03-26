#!/bin/bash
# ----------------------------------------------------------------------------
# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
# ----------------------------------------------------------------------------

FILE_NAME="$(basename $0)"

call_write_scripts() {
  local op_type="$1"
  local soc_version_lower="$2"
  local auto_sync="$3"
  local compute_units="$4"
  local compile_options="$5"

  local rep_cfg='{
    "batch": "",
    "iterate": ""
  }'

  local cfg_dir='{
    "impl_dir": "'"${topdir}/build/tbe/ascendc"'",
    "out_dir": "'"${topdir}/build/tbe/dynamic"'",
    "auto_gen_dir": "'"${topdir}/build/autogen"'"
  }'

  local op_compile_option="{\"$op_type\": {"
  local inner_properties=()
  # auto_sync 默认true
  if [ "$auto_sync" == "false" ]; then
    inner_properties+=("\"auto_sync\": $auto_sync")
  fi
  if [ -n "$compile_options" ]; then
    inner_properties+=("\"compile_options\": $compile_options")
  fi

  if [ ${#inner_properties[@]} -gt 0 ]; then
    local inner_props_str=$(IFS=,; echo "${inner_properties[*]}")
    op_compile_option+="$inner_props_str"
  fi
  op_compile_option+="}}"
  if [ ${#inner_properties[@]} -eq 0 ]; then
    op_compile_option="{\"$op_type\": {}}"
  fi
  
  local op_cfg_path="${topdir}/build/tbe/config"
  local op_cfg_name="aic-${soc_version_lower}-ops-info.ini"
  local op_cfg_file="${op_cfg_path}/${op_cfg_name}"

  if [ ! -f "$op_cfg_file" ]; then
    echo "Warning: Op config file $op_cfg_file not found"
    return 1
  fi

  local UTIL_DIR="${topdir}/scripts/util/"

  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT
  echo "$rep_cfg" > "$TMP_DIR/rep_cfg.json"
  echo "$cfg_dir" > "$TMP_DIR/cfg_dir.json"
  echo "$op_compile_option" > "$TMP_DIR/op_compile_option.txt"

  if [ -n "$op_compile_option" ]; then
    has_op_opt="1"
  else
    has_op_opt=""
  fi

python3 -c "
import sys,json,os
sys.path.insert(0, '''$UTIL_DIR''')
from ascendc_impl_build import write_scripts

tmp_dir = '$TMP_DIR'
op_opt = '$has_op_opt'

def read_file(path):
    with open(path, 'r') as f:
        return f.read()

cfgs_dict = json.loads(read_file(os.path.join(tmp_dir, 'rep_cfg.json')))
dirs_dict = json.loads(read_file(os.path.join(tmp_dir, 'cfg_dir.json')))
op_type_list=['$op_type']

op_compile_list = json.loads(read_file(os.path.join(tmp_dir, 'op_compile_option.txt'))) if op_opt else None

write_scripts(
  '''$op_cfg_file''',
  cfgs_dict,
  dirs_dict,
  op_type_list,
  op_compile_list
)
"
}

main() {
  echo "[INFO]excute file: $0 $*"
  local all_pairs=("$@")
  if [ ${#all_pairs[@]} -eq 0 ]; then
    echo "[WARNING] No op pairs provided"
    exit 0
  fi
  local workdir=$(cd "$(dirname $0)" && pwd)
  local topdir=$(readlink -f ${workdir}/../..)
  local binary_param_dir=${topdir}/build/tbe
  for pair in "${all_pairs[@]}"; do
    if [[ "$pair" != *:* ]]; then
      echo "[ERROR] Invaild format: '$pair'. Expected: op_type:compute_unit"
      continue
    fi
    local op_type="${pair%%:*}"
    local soc_version="${pair#*:}"
    local soc_version_lower=${soc_version,,}

    local ascendc_config_file="${topdir}/scripts/kernel/binary_config/ascendc_config.json"
    local key_word_in_list="\"name\":\s*\"${op_type}\""
    local ascendc_op_conf=$(grep ${key_word_in_list} ${ascendc_config_file} | grep -w $soc_version_lower)

    json_line=$(echo "$ascendc_op_conf" | tr -d '\n\r')

    auto_sync=""
    if [ -n "$json_line" ]; then
      val_part=$(echo "$json_line" | sed -E 's/.*"auto_sync"[[:space:]]*:[[:space:]]*(\{[^}]*\}|true|false).*/\1/')
      if [ "$val_part" = "true" ] || [ "$val_part" = "false" ]; then
        auto_sync="$val_part"
      elif [ "${val_part#*\{}" != "$val_part" ] && [ "${val_part%\}}" != "$val_part" ]; then
        if [ -n "$soc_version_lower" ]; then
          match=$(echo "$val_part" | sed -n "s/.*\"$soc_version_lower\"[[:space:]]*:[[:space:]]*\([a-zA-Z]*\)[,}]*.*/\1/p")
          if [ "$match" = "true" ] || [ "$match" = "false" ]; then
            auto_sync="$match"
          fi
        fi
        auto_sync=${auto_sync:-""}
      fi
    fi

    compute_units=$(echo "$json_line" | awk '
    match($0, /"compute_units"[[:space:]]*:[[:space:]]*\[([^]]*)\]/, arr) {
      str = arr[1]
      gsub(/"/, "", str)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", str)
      gsub(/,[[:space:]]*/, " ", str)
      print str
    }')

    compile_options=$(echo "$json_line" | awk '
    match($0, /"compile_options"[[:space:]]*:[[:space:]]*(\{[^}]*\})/, arr) {
      print arr[1]
    }')

    call_write_scripts "$op_type" "$soc_version_lower" "$auto_sync" "$compute_units" "$compile_options"
  done
  exit 0
}
set -o pipefail
main "$@" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}'
