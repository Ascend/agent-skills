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
IMPL_FILE_NAME="all_ops_impl_mode.ini"
FILE_NAME="$(basename $0)"

source get_threadnum_with_op.sh
source build_env.sh

function get_binary_config_file() {
  if [ $# -ne 4 ]; then
    echo "error invalid param number:$#, must be 4" >&2
    return 1
  fi
  local workdir="$1"
  local soc_version_lower="$2"
  local op_type="$3"
  local op_file_name="$4"
  local topdir=$(readlink -f ${workdir}/../../..)
  local binary_config_dir=${topdir}/build/tbe/config #build dir

  # 检查并处理以 "_apt" 结尾的 op_file_name
  if [[ "$op_file_name" == *_apt ]]; then
    op_file_name="${op_file_name%_apt}"
  fi

  # 优先级1：build/tbe/config路径下，带_binary后缀
  local primary_pattern="${binary_config_dir}/${soc_version_lower}/${op_file_name}/${op_file_name}_binary.json"
  if [ -f "${primary_pattern}" ]; then
    echo "${primary_pattern}"
    return 0
  fi
  # 优先级2：math/{op_file_name}/op_host/config路径下，带_binary后缀
  local binary_config_file=""
  for item in ${OP_CATEGORY_LIST}; do
    local cmd="find ${topdir}/${item} -name ${op_file_name}_binary.json | grep -w ${soc_version_lower}"
    binary_config_file=$(${cmd})
    if [! -z "${binary_config_file}"]; then
      echo "${binary_config_file[0]}"
      return 0
    fi
  done
  echo "${binary_config_file}"
  return 0
}

function get_simplified_key_config_file() {
  if [ $# -ne 4 ]; then
    echo "error invalid param number:$#, must be 4" >&2
    return 1
  fi
  local workdir="$1"
  local op_type="$2"
  local op_file_name="$3"
  local soc_version_lower="$4"
  local topdir=$(readlink -f ${workdir}/../../..)
  local binary_config_dir=${topdir}/build/tbe/config #build dir

  # 检查并处理以 "_apt" 结尾的 op_file_name
  if [[ "$op_file_name" == *_apt ]]; then
    op_file_name="${op_file_name%_apt}"
  fi

  # 优先级1： 搜索build/tbe/config路径，后缀simplified_key.ini
  local primary_pattern="${binary_config_dir}/${soc_version_lower}/${op_file_name}/${op_file_name}_simplified_key.ini"
  if [ -f "${primary_pattern}" ]; then
    echo "${primary_pattern}"
    return 0
  fi
  # 优先级2： 搜索math/{op_file_name}/op_host/config路径，后缀simplified_key.ini
  local simplified_key_config_file=""
  for item in ${OP_CATEGORY_LIST}; do
    local cmd="find ${topdir}/${item} -name ${op_file_name}_simplified_key.ini | grep -w ${soc_version_lower}"
    simplified_key_config_file=$(bash -c "${cmd}")
    if [ ! -z "${simplified_key_config_file}" ]; then
      echo "${simplified_key_config_file[0]}"
      return 0
    fi
  done
  echo "$simplified_key_config_file"
  return 0
}

main() {
  echo "[INFO]excute file: $0"
  if [ $# -lt 9 ]; then
    echo "[ERROR]input error"
    echo "[ERROR]bash $0 {op_type} {soc_version} {output_path} {enable_mssanitizer} {enable_debug} {enable_oom} {enable_dump_cce} bisheng_flags={bisheng_flags} tiling_key={tiling_key}"
    exit 1
  fi

  local workdir=$(
    cd $(dirname $0)
    pwd
  )
  local topdir=$(readlink -f ${workdir}/../../..)
  local binary_param_dir=${topdir}/build/tbe
  local op_type=$1
  local soc_version=$2
  local soc_version_lower=${soc_version,,}
  local output_path=$3
  local enable_mssanitizer=$4
  local enable_debug=$5
  local enable_oom=$6
  local enable_dump_cce=$7
  local bisheng_flags="${8#*=}"
  local tiling_key="${9#*=}"
  local task_path=${output_path}/opc_cmd/
  local is_need_gen_opc_info=TRUE
  local python_arg=${HI_PYTHON}
  if [ "${python_arg}" = "" ]; then
    python_arg="python3"
  fi
  test -d "$task_path/" || mkdir -p $task_path/
  local lock_file="$output_path/.$soc_version.cleaned.lock"
  if [[ ! -f "$lock_file" ]]; then
    rm -f $task_path/*.sh
    touch "$lock_file" || {
      echo "[WARNING] Failed to create lock file"
    }
  fi
  local binary_temp_conf_dir=${binary_param_dir}/temp
  if [ ! -d ${binary_temp_conf_dir} ]; then
    mkdir -p "${binary_temp_conf_dir}"
  fi
  local opc_info_csv="${binary_temp_conf_dir}/_${soc_version_lower}_tmp.csv"

  # step0: gen task
  opc_task_cmd_file="${task_path}/${OPC_TASK_NAME}"
  out_task_cmd_file="${task_path}/${OUT_TASK_NAME}"
  echo "[INFO] op:${op_type}: opc_task_cmd_file=${opc_task_cmd_file}"
  echo "[INFO] op:${op_type}: out_task_cmd_file=${out_task_cmd_file}"

  # step1: get op python file name from opc_info_csv
  cmd="sed -n "/^${op_type},/{p\;q\;}" ${opc_info_csv}"
  local opc_info_list=$(${cmd})
  echo "[INFO] op:${op_type} get the opc info from ${opc_info_csv} is ${opc_info_list}"
  if [ "${opc_info_list}" == "" ]; then
    echo "[WARNING] op:${op_type} do not get the opc info from ${opc_info_csv}, will ignore"
    exit 0
  fi

  # step2: get op function name from opc_info_csv
  local op_python_file=$(echo ${opc_info_list} | awk -F',' 'BEGIN{OFS=",";} { if (NR==1)print $2}' | tr -d '\n' | tr -d '\r')
  local op_func=$(echo ${opc_info_list} | awk -F',' 'BEGIN{OFS=",";} { if (NR==1)print $3}' | tr -d '\n' | tr -d '\r')
  local op_python_path="${binary_param_dir}/${op_python_file}" # generated dynamic python file path
  if ! test -f $op_python_path; then
    echo "[ERROR] op:${op_python_path} do not get python script, will ignore"
    exit 1
  fi
  # step 3: get binary_config_file, file with _binary.json suffix
  local op_file_name=${op_python_path##*/}
  local op_file_name_prefix=${op_file_name%.*}
  local binary_config_file=$(get_binary_config_file ${workdir} ${soc_version_lower} ${op_type} ${op_file_name_prefix})
  local binary_bin_path="${output_path}/${soc_version_lower}/${op_file_name_prefix}/"
  local binary_compile_json_file="${output_path}/config/${soc_version_lower}/${op_file_name_prefix}.json"
  local binary_compile_json_path="${output_path}/config/${soc_version_lower}"
  echo "[INFO] op:${op_type} python path is ${op_python_path}"
  echo "[INFO] op:${op_type} python func is ${op_func}"
  echo "[INFO] op:${op_type} binary config path is ${binary_config_file}"
  echo "[INFO] op:${op_type} binary bin path is ${binary_bin_path}"
  echo "[INFO] op:${op_type} binary json file path is ${binary_compile_json_file}"
  if [ ! -f "${binary_config_file}" ]; then
    echo "[WARNING] ${FILE_NAME} op:${op_type} do not find the binary config file for ${binary_config_file}, will ignore"
    exit 0
  fi
  if [ ! -d "${binary_bin_path}" ]; then
    echo "[INFO] op:${op_type} create binary bin path ${binary_bin_path}"
    mkdir -p ${binary_bin_path}
  fi
  if [ ! -d "${binary_compile_json_path}" ]; then
    echo "[INFO] op:${op_type} create binary json path ${binary_compile_json_path}"
    mkdir -p ${binary_compile_json_path}
  fi
  if [ -f "${binary_compile_json_file}" ]; then
    echo "[WARNING] op:${op_type} will clean ${binary_compile_json_file}"
    rm -f {binary_compile_json_file}
  fi

  # step 4: get simplified_key_mode from binary_simplified_key_mode.ini
  local simplified_key_file=$(get_simplified_key_config_file ${workdir} ${op_type} ${op_file_name_prefix} ${soc_version_lower})
  local key_mode_default=0
  if [ -z ${simplified_key_file} ]; then
    key_mode_default=""
  else
    if [ -f ${simplified_key_file} ]; then
      dos2unix $simplified_key_file >/dev/null 2>&1
      # if no file binary_simplified_key_mode.ini use mode=0
      key_mode_default=$(awk -F "=" '/\['${op_type}'\]/{flag=1;next}/\[/{flag=0} flag && /default/{print $2}' $simplified_key_file)
      key_mode_default=$(echo $key_mode_default | tr -d '[:space:]')
    fi
  fi
  local ascendc_config_file="${workdir}/../binary_config/ascendc_config.json"
  local key_word_in_list="\"name\":\s*\"${op_type}\""
  local ascendc_op_conf=$(grep ${key_word_in_list} ${ascendc_config_file} | grep -w $soc_version_lower)

  if [ "$key_mode_default" != "" ]; then
    key_mode=${key_mode_default}
  else
    key_mode=0
  fi

  if [ "$key_mode" != "None" ]; then
    simplified_key_param="--simplified_key_mode=${key_mode}"
  else
    simplified_key_param=""
  fi

  # step 5: get impl_mode from all_ops_impl_mode.ini
  # ascendc_config.json 配置超过两种以上的implmode使用ascendc_config的配置，否则使用binary_implmode_default
  # 如果都没有配置，默认high_performance
  local impl_mode_full_path="${workdir}/../binary_config/${IMPL_FILE_NAME}"
  local impl_list=$(awk -F '=' '/^'${op_type}'=/{print $2;exit}' ${impl_mode_full_path})
  if [ "${impl_list}" = "" ]; then
    # 默认高性能模式
    impl_list="high_performance"
  fi

  # 获取 impl_mode 默认值
  local val=$(echo ${ascendc_op_conf} | awk -F "\"impl_mode\"" '{print $2}' | awk -F "\"" '{print $2}')
  if [ "${val}" = "" ]; then
    # 默认高性能模式
    val="high_performance"
  fi

  # step 6: do opc compile all kernel
  var_array=(${val//,/ })
  impl_list_array=(${impl_list//,/ })
  if [ ${#var_array[@]} -ge 2 ]; then
    impl_list_array=$val
  fi

  opc_soc_version=$(trans_soc ${soc_version})

  # 所有算子的kernel  onebyone 进行编译
  get_thread_num_with_json_config ${binary_config_file}
  local thread_num=$?
  echo "[INFO] op:${op_type} thread_num = ${thread_num}"

  for impl_mode in ${impl_list_array[@]}; do
    impl_mode_name=$impl_mode
    if [ ${#var_array[@]} -ge 2 ]; then
      impl_mode_name="all"
    fi
    # gen new json file for impl_mode from ${binary_config_file}
    local binary_config_new_path=${binary_config_file%/*}
    local binary_config_name=${binary_config_file##*/}
    local binary_config_name_prefix=${binary_config_name%.*}
    local binary_config_new_full_path="${binary_config_new_path}/${binary_config_name_prefix}_${impl_mode_name}.json"
    ${python_arg} gen_opc_json_with_impl_mode.py ${binary_config_file} ${binary_config_new_full_path} ${impl_mode_name}
    ${python_arg} gen_opc_json_with_threadnum.py ${binary_config_new_full_path} ${thread_num}
    # get new file with thread

    for ((i = 0; i < ${thread_num}; i = i + 1)); do
      {
        new_file="${binary_config_new_full_path}_${i}"
        if [ "${val}" = "${impl_mode}" ]; then
          impl_mode_default="${impl_mode},optional"
          cmd="asc_opc ${op_python_path} --main_func=${op_func} --input_param=${new_file} --soc_version=${opc_soc_version} --output=${binary_bin_path} --impl_mode=${impl_mode_default} ${simplified_key_param} --op_mode=dynamic"
        else
          cmd="asc_opc ${op_python_path} --main_func=${op_func} --input_param=${new_file} --soc_version=${opc_soc_version} --output=${binary_bin_path} --impl_mode=${impl_mode} ${simplified_key_param} --op_mode=dynamic"
        fi

        echo "bisheng_flags is: ${bisheng_flags}"
        if [[ -n "$bisheng_flags" ]]; then
          cmd="${cmd} --op_debug_config=${bisheng_flags}"
        else
          op_debug_configs=()
          if [ "${enable_mssanitizer}" = "TRUE" ]; then
            op_debug_configs+=("sanitizer")
          fi
          if [ "${enable_oom}" = "TRUE" ]; then
            op_debug_configs+=("oom")
          fi
          if [ "${enable_dump_cce}" = "TRUE" ]; then
            op_debug_configs+=("dump_cce")
          fi
          if [ ${#op_debug_configs[@]} -gt 0 ]; then
              OLD_IFS="${IFS}"
              IFS=','
              cmd="${cmd} --op_debug_config=${op_debug_configs[*]}"
              IFS="$OLD_IFS" 
          fi
        fi
        if [[ "$cmd" == *"dump_cce"* ]]; then
          cmd="${cmd} --debug_dir=${output_path}/kernel_metas" 
        fi

        
        if [[ -n "$tiling_key" ]]; then
          echo "tiling_key is: ${tiling_key}"
          cmd="${cmd} --tiling_key=${tiling_key}"
        fi

        echo "[INFO] op:${op_type} do opc cmd is ${cmd}"
        echo ${cmd} >>${opc_task_cmd_file}
        cmd="${python_arg} gen_output_json.py ${new_file} ${binary_bin_path} ${binary_compile_json_file}"
        echo "[INFO] op:${op_type} gen compile json cmd is ${cmd}"
        echo ${cmd} >>${out_task_cmd_file}
      }
    done
  done
}
set -o pipefail
main "$@"
