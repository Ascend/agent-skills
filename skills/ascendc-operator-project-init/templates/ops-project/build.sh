#!/bin/bash
# Copyright (c) 2025 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
# ============================================================================

set -e
RELEASE_TARGETS=("ophost" "opapi" "opgraph" "opkernel" "opkernel_aicpu")
UT_TARGETS=("ophost_test" "opapi_test" "opgraph_test" "opkernel_test" "opkernel_aicpu_test")
SUPPORT_COMPUTE_UNIT_SHORT=("ascend910b" "ascend910_93" "ascend950" "ascend310p" "ascend910" "ascend310b" "ascend630" "ascend610lite" "ascend031" "ascend035" "kirinx90"  "kirin9030" "mc62cm12a")
# 所有支持的短选项
SUPPORTED_SHORT_OPTS="hj:vO:uf:-:"

# 所有支持的长选项
SUPPORTED_LONG_OPTS=(
  "help" "ops=" "soc=" "vendor_name=" "debug" "cov" "noexec" "aicpu" "opkernel" "opkernel_aicpu" "jit"
  "pkg" "asan" "valgrind" "make_clean" "static" "build-type=" "no_force"
  "ophost" "opapi" "opgraph" "ophost_test" "opapi_test" "opgraph_test" "opkernel_test" "opkernel_aicpu_test"
  "run_example" "genop=" "genop_aicpu=" "experimental" "cann_3rd_lib_path" "mssanitizer" "oom"
  "dump_cce" "bisheng_flags=" "tiling_key="
)

in_array() {
  local needle="$1"
  shift
  local haystack=("$@")
  for item in "${haystack[@]}"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

check_option_validity() {
  local arg="$1"

  if [[ "$arg" =~ ^-[^-] ]]; then
    local opt_chars=${arg:1}

    local needs_arg_opts=$(echo "$SUPPORTED_SHORT_OPTS" | grep -o "[a-zA-Z]:" | tr -d ':')

    local i=0
    while [ $i -lt ${#opt_chars} ]; do
      local char="${opt_chars:$i:1}"

      if [[ ! "$SUPPORTED_SHORT_OPTS" =~ "$char" ]]; then
        echo "[ERROR] Invalid short option: -$char"
        return 1
      fi

      if [[ "$needs_arg_opts" =~ "$char" ]]; then
        while [ $i -lt ${#opt_chars} ] && [[ "${opt_chars:$i:1}" =~ [0-9a-zA-Z] ]]; do
          i=$((i + 1))
        done
      else
        i=$((i + 1))
      fi
    done
    return 0
  fi

  if [[ "$arg" =~ ^-- ]]; then
    local long_opt="${arg:2}"
    local opt_name="${long_opt%%=*}"

    for supported_opt in "${SUPPORTED_LONG_OPTS[@]}"; do
      # with "=" in long options
      if [[ "$supported_opt" =~ =$ ]]; then
        local base_opt="${supported_opt%=}"
        if [[ "$opt_name" == "$base_opt" ]]; then
          return 0
        fi
      else
        # without "=" in long options
        if [[ "$opt_name" == "$supported_opt" ]]; then
          return 0
        fi
      fi
    done

    echo "[ERROR] Invalid long option: --$opt_name"
    return 1
  fi

  return 0
}

dotted_line="----------------------------------------------------------------"
export BASE_PATH=$(
  cd "$(dirname $0)"
  pwd
)
export BUILD_PATH="${BASE_PATH}/build"
export BUILD_OUT_PATH="${BASE_PATH}/build_out"
REPOSITORY_NAME="math"

CORE_NUMS=$(cat /proc/cpuinfo | grep "processor" | wc -l)
ARCH_INFO=$(uname -m)
CANN_3RD_LIB_PATH="${BASE_PATH}/third_party"

export INCLUDE_PATH="${ASCEND_HOME_PATH}/include"
export ACLNN_INCLUDE_PATH="${INCLUDE_PATH}/aclnn"
export COMPILER_INCLUDE_PATH="${ASCEND_HOME_PATH}/compiler/include"
export GRAPH_INCLUDE_PATH="${INCLUDE_PATH}/graph"
export GE_INCLUDE_PATH="${INCLUDE_PATH}/ge"
export GE_EXTERNAL_INCLUDE_PATH="${INCLUDE_PATH}/external"
export INC_INCLUDE_PATH="${ASCEND_OPP_PATH}/built-in/op_proto/inc"
export EAGER_LIBRARY_PATH="${ASCEND_HOME_PATH}/lib64"
export GRAPH_LIBRARY_PATH="${ASCEND_HOME_PATH}/lib64"
if [[ ! -v ASCEND_SLOG_PRINT_TO_STDOUT ]]; then
  export ASCEND_SLOG_PRINT_TO_STDOUT=1
fi
if [[ ! -v ASCEND_GLOBAL_LOG_LEVEL ]]; then
  export ASCEND_GLOBAL_LOG_LEVEL=1
fi

# print usage message
usage() {
  local specific_help="$1"

  if [[ -n "$specific_help" ]]; then
    case "$specific_help" in
      package)
        echo "Package Build Options:"
        echo $dotted_line
        echo "    --pkg                  Build run package with kernel bin"
        echo "    --static               Build static library package (cannot be used with --jit)"
        echo "    --jit                  Build run package without kernel bin"
        echo "    --soc=soc_version      Compile for specified Ascend SoC"
        echo "    --vendor_name=name     Specify custom operator package vendor name (cannot be used with --jit)"
        echo "    --ops=op1,op2,...      Compile specified operators (comma-separated for multiple) (cannot be used with --jit)"
        echo "    -j[n]                  Compile thread nums, default is 8, eg: -j8"
        echo "    -O[n]                  Compile optimization options, support [O0 O1 O2 O3], eg:-O3"
        echo "    --asan                 Enable ASAN (Address Sanitizer) on the host side"
        echo "    --build-type=<Type>    Specify build-type (Type options: Release/Debug), Default:Release"
        echo "    --experimental         Build experimental version"
        echo "    --cann_3rd_lib_path=<PATH>"
        echo "                           Set ascend third_party package install path, default ./third_party"
        echo "    --mssanitizer          Build with mssanitizer mode on the kernel side, with options: '-g --cce-enable-sanitizer'"
        echo "    --oom                  Build with oom mode on the kernel side, with options: '-g --cce-enable-oom'"
        echo "    --dump_cce             Dump kernel precompiled files"
        echo "    --bisheng_flags=flag1,flag2"
        echo "                           Specify bisheng compiler flags (comma-separated for multiple)"
        echo "    --tiling_key=tilingkey1,tilingkey2"
        echo "                           Specify tiling key (comma-separated for multiple)"
        echo $dotted_line
        echo "Examples:"
        echo "    bash build.sh --pkg --soc=ascend910b --vendor_name=customize -j16 -O3"
        echo "    bash build.sh --pkg --ops=add,sub --build-type=Debug"
        echo "    bash build.sh --pkg --static --soc=ascend910b"
        echo "    bash build.sh --pkg --experimental --soc=ascend910b"
        echo "    bash build.sh --pkg --experimental --soc=ascend910b --ops=abs --mssanitizer"
        echo "    bash build.sh --pkg --experimental --soc=ascend910b --ops=abs --oom"
        echo "    bash build.sh --pkg --experimental --soc=ascend910b --ops=abs --dump_cce"
        echo "    bash build.sh --pkg --experimental --soc=ascend910b --ops=abs --bisheng_flags=ccec_g,oom"
        echo "    bash build.sh --pkg --experimental --soc=ascend950 --ops=abs --tiling_key=101,102"
        return
        ;;
      opkernel)
        echo "Opkernel Build Options:"
        echo $dotted_line
        echo "    --opkernel             Build binary kernel"
        echo "    --soc=soc_version      Compile for specified Ascend SoC"
        echo "    --ops=op1,op2,...      Compile specified operators (comma-separated for multiple)"
        echo "    --build-type=<Type>    Specify build-type (Type options: Release/Debug), Default:Release"
        echo "    --mssanitizer          Build with mssanitizer mode on the kernel side, with options: '-g --cce-enable-sanitizer'"
        echo "    --oom                  Build with oom mode on the kernel side, with options: '-g --cce-enable-oom'"
        echo "    --dump_cce             Dump kernel precompiled files"
        echo "    --no_force             Don't force dependency installation"
        echo "    --bisheng_flags=flag1,flag2"
        echo "                           Specify bisheng compiler config (comma-separated for multiple)"
        echo "    --tiling_key=tilingkey1,tilingkey2"
        echo "                           Specify tiling key (comma-separated for multiple)"
        echo $dotted_line
        echo "Examples:"
        echo "    bash build.sh --opkernel --soc=ascend310p --ops=add,sub"
        echo "    bash build.sh --opkernel --soc=ascend310p --ops=add,sub --build-type=Debug"
        echo "    bash build.sh --opkernel --soc=ascend310p --ops=add,sub --mssanitizer"
        echo "    bash build.sh --opkernel --soc=ascend310p --ops=add,sub --oom"
        echo "    bash build.sh --opkernel --soc=ascend310p --ops=add,sub --dump_cce"
        echo "    bash build.sh --opkernel --soc=ascend310p --ops=add,sub --bisheng_flags=ccec_g,oom"
        echo "    bash build.sh --opkernel --soc=ascend950 --ops=abs --tiling_key=101,102"
        return
        ;;
      opkernel_aicpu)
        echo "AICPU Opkernel Build Options:"
        echo $dotted_line
        echo "    --opkernel_aicpu       Build AICPU kernel"
        echo "    --soc=soc_version      Compile for specified Ascend SoC"
        echo "    --ops=op1,op2,...      Compile specified operators (comma-separated for multiple)"
        echo "    --build-type=<Type>    Specify build-type (Type options: Release/Debug), Default:Release"
        echo "    --mssanitizer          Build with mssanitizer mode on the kernel side, with options: '-g --cce-enable-sanitizer'"
        echo "    --oom                  Build with oom mode on the kernel side, with options: '-g --cce-enable-oom'"
        echo "    --bisheng_flags=flag1,flag2"
        echo "                           Specify bisheng compiler flags (comma-separated for multiple)"

        echo $dotted_line
        echo "Examples:"
        echo "    bash build.sh --opkernel_aicpu --soc=ascend910b --ops=add,sub"
        echo "    bash build.sh --opkernel_aicpu --soc=ascend910b --ops=add,sub --build-type=Debug"
        echo "    bash build.sh --opkernel_aicpu --soc=ascend910b --ops=add,sub --mssanitizer"
        echo "    bash build.sh --opkernel_aicpu --soc=ascend910b --ops=add,sub --oom"
        echo "    bash build.sh --opkernel_aicpu --soc=ascend910b --ops=add,sub --bisheng_flags=ccec_g,oom"
        return
        ;;
      test)
        echo "Test Options:"
        echo $dotted_line
        echo "    -u                     Build and run all unit tests"
        echo "    --noexec               Only compile ut, do not execute"
        echo "    --cov                  Enable code coverage for unit tests"
        echo "    --soc=soc_version      Run unit tests for specified Ascend SoC"
        echo "    --ophost_test          Build and run ophost unit tests"
        echo "    --opapi_test           Build and run opapi unit tests"
        echo "    --opgraph_test         Build and run opgraph unit tests"
        echo "    --ophost -u            Same as --ophost_test"
        echo "    --opapi -u             Same as --opapi_test"
        echo "    --opgraph -u           Same as --opgraph_test"
        echo $dotted_line
        echo "Examples:"
        echo "    bash build.sh -u --noexec --cov"
        echo "    bash build.sh -u --ophost --soc=ascend910b --ops=is_finite"
        echo "    bash build.sh --ophost_test --opapi_test --noexec"
        echo "    bash build.sh --ophost --opapi --opgraph -u --cov"
        return
        ;;
      clean)
        echo "Clean Options:"
        echo $dotted_line
        echo "    --make_clean           Clean build artifacts"
        echo $dotted_line
        return
        ;;
      valgrind)
        echo "Valgrind Options:"
        echo $dotted_line
        echo "    --valgrind             Run unit tests with valgrind (disables ASAN and noexec)"
        echo $dotted_line
        return
        ;;
      ophost)
        echo "Ophost Build Options:"
        echo $dotted_line
        echo "    --ophost               Build ophost library"
        echo "    -j[n]                  Compile thread nums, default is 8, eg: -j8"
        echo "    -O[n]                  Compile optimization options, support [O0 O1 O2 O3], eg:-O3"
        echo "    --build-type=<Type>    Specify build-type (Type options: Release/Debug), Default:Release"
        echo $dotted_line
        echo "Examples:"
        echo "    bash build.sh --ophost -j16 -O3"
        echo "    bash build.sh --ophost --build-type=Debug"
        return
        ;;
      opapi)
        echo "Opapi Build Options:"
        echo $dotted_line
        echo "    --opapi                Build opapi library"
        echo "    -j[n]                  Compile thread nums, default is 8, eg: -j8"
        echo "    -O[n]                  Compile optimization options, support [O0 O1 O2 O3], eg:-O3"
        echo "    --build-type=<Type>    Specify build-type (Type options: Release/Debug), Default:Release"
        echo $dotted_line
        echo "Examples:"
        echo "    bash build.sh --opapi -j16 -O3"
        echo "    bash build.sh --opapi --build-type=Debug"
        return
        ;;
      opgraph)
        echo "Opgraph Build Options:"
        echo $dotted_line
        echo "    --opgraph              Build opgraph library"
        echo "    -j[n]                  Compile thread nums, default is 8, eg: -j8"
        echo "    -O[n]                  Compile optimization options, support [O0 O1 O2 O3], eg:-O3"
        echo "    --build-type=<Type>    Specify build-type (Type options: Release/Debug), Default:Release"
        echo $dotted_line
        echo "Examples:"
        echo "    bash build.sh --opgraph -j16 -O3"
        echo "    bash build.sh --opgraph --build-type=Debug"
        return
        ;;
      ophost_test)
        echo "Ophost Test Options:"
        echo $dotted_line
        echo "    --ophost_test          Build and run ophost unit tests"
        echo "    --noexec               Only compile ut, do not execute"
        echo "    --cov                  Enable code coverage for unit tests"
        echo $dotted_line
        echo "Examples:"
        echo "    bash build.sh --ophost_test --noexec --cov"
        return
        ;;
      opapi_test)
        echo "Opapi Test Options:"
        echo $dotted_line
        echo "    --opapi_test           Build and run opapi unit tests"
        echo "    --noexec               Only compile ut, do not execute"
        echo "    --cov                  Enable code coverage for unit tests"
        echo $dotted_line
        echo "Examples:"
        echo "    bash build.sh --opapi_test --noexec --cov"
        return
        ;;
      opgraph_test)
        echo "Opgraph Test Options:"
        echo $dotted_line
        echo "    --opgraph_test         Build and run opgraph unit tests"
        echo "    --noexec               Only compile ut, do not execute"
        echo "    --cov                  Enable code coverage for unit tests"
        echo $dotted_line
        echo "Examples:"
        echo "    bash build.sh --opgraph_test --noexec --cov"
        return
        ;;
      run_example)
        echo "Run examples Options:"
        echo $dotted_line
        echo "    --run_example op_type  mode[eager:graph] [pkg_mode --vendor_name=name]     Compile and execute the test_aclnn_xxx.cpp/test_geir_xxx.cpp"
        echo $dotted_line
        echo "Examples:"
        echo "    bash build.sh --run_example abs eager"
        echo "    bash build.sh --run_example abs graph"
        echo "    bash build.sh --run_example abs eager cust"
        echo "    bash build.sh --run_example abs eager cust --vendor_name=custom"
        return
        ;;
      genop)
        echo "Gen Op Directory Options:"
        echo $dotted_line
        echo "    --genop=op_class/op_name      Create the initial directory for op_name undef op_class"
        echo $dotted_line
        echo "Examples:"
        echo "    bash build.sh --genop=examples/add"
        return
        ;;
      genop_aicpu)
        echo "Gen Op Directory Options:"
        echo $dotted_line
        echo "    --genop_aicpu=op_class/op_name      Create the initial directory for op_name undef op_class"
        echo $dotted_line
        echo "Examples:"
        echo "    bash build.sh --genop_aicpu=examples/add"
        return
        ;;
    esac
  fi

  echo "build script for ops repository"
  echo "Usage:"
  echo "    bash build.sh [-h] [-j[n]] [-v] [-O[n]] [-u] "
  echo ""
  echo ""
  echo "Options:"
  echo $dotted_line
  echo "    Build parameters "
  echo $dotted_line
  echo "    -h Print usage"
  echo "    -j[n] Compile thread nums, default is 8, eg: -j8"
  echo "    -v Cmake compile verbose"
  echo "    -O[n] Compile optimization options, support [O0 O1 O2 O3], eg:-O3"
  echo "    -u Compile all ut"
  echo $dotted_line
  echo "    examples, Build ophost_test with O3 level compilation optimization and do not execute."
  echo "    ./build.sh --ophost_test --noexec -O3"
  echo $dotted_line
  echo "    The following are all supported arguments:"
  echo $dotted_line
  echo "    --cov When building uTest locally, count the coverage."
  echo "    --noexec Only compile ut, do not execute the compiled executable file"
  echo "    --make_clean make clean"
  echo "    --asan enable asan on the host side"
  echo "    --valgrind run ut with valgrind. This option will disable asan, noexec and run utest by valgrind"
  echo "    --ops Compile specified operator, use snake name, like: --ops=add,add_lora, use ',' to separate different operator"
  echo "    --soc Compile binary with specified Ascend SoC, like: --soc=ascend910b"
  echo "    --vendor_name Specify the custom operator package vendor name, like: --vendor_name=customize, default to custom"
  echo "    --aicpu build aicpu task"
  echo "    --opgraph build opgraph_math.so"
  echo "    --opapi build opapi_math.so"
  echo "    --ophost build ophost_math.so"
  echo "    --opkernel build binary kernel"
  echo "    --opkernel_aicpu build aicpu kernel"
  echo "    --pkg build run package with kernel bin"
  echo "    --build-type specify build-type (Type options: Release/Debug), Default:Release"
  echo "    --static build static library package"
  echo "    --experimental Build experimental version"
  echo "    --opapi_test build and run opapi unit tests"
  echo "    --ophost_test build and run ophost unit tests"
  echo "    --opgraph_test build and run opgraph unit tests"
  echo "    --opkernel_test build and run opkernel unit tests"
  echo "    --opkernel_aicpu_test build and run aicpu opkernel unit tests"
  echo "    --run_example Compile and execute the test_aclnn_xxx.cpp/test_geir_xxx.cpp"
  echo "    --genop Create the initial directory for op"
  echo "    --genop_aicpu Create the initial directory for AI CPU op"
  echo "    --mssanitizer Build with mssanitizer mode on the kernel side, with options: '-g --cce-enable-sanitizer'"
  echo "    --oom Build with oom mode on the kernel side, with options: '-g --cce-enable-oom'"
  echo "    --dump_cce Dump kernel precompiled files"
  echo "    --bisheng_flags Specify bisheng compiler config, like: --bisheng_flags=ccec_g,oom, use ',' to separate different compiler flags"
  echo "    --tiling_key Specify tiling key, like: --tiling_key=0,1, use ',' to separate different tiling key"
  echo "to be continued ..."
}

check_help_combinations() {
  local args=("$@")
  local has_u=false
  local has_test_command=false
  local has_build_command=false
  local has_package=false
  local has_opkernel=false
  local has_opkernel_aicpu=false

  for arg in "${args[@]}"; do
    case "$arg" in
      -u) has_u=true ;;
      --ophost_test | --opapi_test | --opgraph_test | --ophost | --opapi | --opgraph)
        has_test_command=true
        has_build_command=true
        ;;
      --pkg) has_package=true ;;
      --opkernel) has_opkernel=true ;;
      --opkernel_aicpu) has_opkernel_aicpu=true ;;
      --help | -h) ;;
    esac
  done

  # Check the invalid command combinations in help
  if [[ "$has_package" == "true" && ("$has_test_command" == "true" || "$has_u" == "true") ]]; then
    echo "[ERROR] --pkg cannot be used with test(-u, --ophost_test, etc.), --ophost, --opapi, or --opgraph"
    return 1
  fi

  if [[ "$has_opkernel" == "true" && ("$has_test_command" == "true" || "$has_u" == "true") ]]; then
    echo "[ERROR] --opkernel cannot be used with test(-u, --ophost_test, etc.), --ophost, --opapi, or --opgraph"
    return 1
  fi

  if [[ "$has_opkernel_aicpu" == "true" && ("$has_test_command" == "true" || "$has_u" == "true") ]]; then
    echo "[ERROR] --opkernel_aicpu cannot be used with test(-u, --ophost_test, etc.), --ophost, --opapi, or --opgraph"
    return 1
  fi

  return 0
}

check_param() {
  if [[ "$ENABLE_RUN_EXAMPLE" == "TRUE" ]]; then
    ENABLE_CUSTOM=FALSE
  fi
  # --ops不能与--ophost，--opapi，--opgraph同时存在，如果带U则可以
  if [[ -n "$COMPILED_OPS" && "$ENABLE_TEST" == "FALSE" ]] && [[ "$OP_HOST" == "TRUE" || "$OP_API" == "TRUE" || "$OP_GRAPH" == "TRUE" ]]; then
    echo "[ERROR] --ops cannot be used with --ophost, --opapi, or --opgraph"
    exit 1
  fi

  # -pkg不能与-u（UT模式，包含_test的参数）或者--ophost，--opapi，--opgraph同时存在
  if [[ "$ENABLE_PACKAGE" == "TRUE" ]]; then
    if [[ "$ENABLE_TEST" == "TRUE" ]]; then
      echo "[ERROR] --pkg cannot be used with test(-u, --ophost_test, etc.)"
      exit 1
    fi

    if [[ "$OP_HOST" == "TRUE" || "$OP_API" == "TRUE" || "$OP_GRAPH" == "TRUE" ]]; then
      echo "[ERROR] --pkg cannot be used with --ophost, --opapi, --opgraph"
      exit 1
    fi

    if [[ "$ENABLE_GENOP" == "TRUE" ]]; then
      echo "[ERROR] --pkg cannot be used with --genop"
      exit 1
    fi

    if [[ "$ENABLE_GENOP_AICPU" == "TRUE" ]]; then
      echo "[ERROR] --pkg cannot be used with --genop_aicpu"
      exit 1
    fi

    if $(echo ${USE_CMD} | grep -wq "jit"); then
      ENABLE_BINARY=FALSE
    fi
  fi

  if [[ -n "${BUILD_TYPE}" ]]; then
    if [[ "${BUILD_TYPE}" != "Release" && "${BUILD_TYPE}" != "Debug" ]]; then
      echo "[ERROR] --build-type only support Release/Debug Mode"
      exit 1
    fi
  fi

  if [[ "${BUILD_TYPE}" == "Debug" ]]; then
    if [[ "$ENABLE_MSSANITIZER" == "TRUE" || "$ENABLE_OOM" == "TRUE" || "$ENABLE_DUMP_CCE" == "TRUE" ]]; then
      echo "[ERROR] --build-type=Debug cannot be used with --mssanitizer, --oom, --dump_cce"
      exit 1
    fi
  fi

  if [ -n "$BISHENG_FLAGS" ]; then
    if [[ "$ENABLE_MSSANITIZER" == "TRUE" || "$ENABLE_OOM" == "TRUE" || "$ENABLE_DUMP_CCE" == "TRUE" ]]; then
      echo "[ERROR] --bisheng_flags= cannot be used with --mssanitizer, --oom, --dump_cce"
      exit 1
    fi
  fi

  if [ -n "$TILING_KEY" ]; then
    if [[ -z "${COMPILED_OPS}" || "$COMPILED_OPS" == *","* ]]; then
      echo "[ERROR] --tiling_key must be used with --ops= and can only specify a single operator"
      exit 1
    fi
  fi

  if [[ "$ENABLE_MSSANITIZER" == "TRUE" && "$ENABLE_OOM" == "TRUE" ]]; then
    echo "[ERROR] --mssanitizer cannot be used with --oom"
    exit 1
  fi

  if $(echo ${USE_CMD} | grep -wq "static") && $(echo ${USE_CMD} | grep -wq "jit"); then
    echo "[ERROR] --static cannot be used with --jit"
    exit 1
  fi

  if $(echo ${USE_CMD} | grep -wq "static") && [[ "$ENABLE_PACKAGE" != "TRUE" ]]; then
    echo "[ERROR] --static can only be used with --pkg"
    exit 1
  fi

  if $(echo ${USE_CMD} | grep -wq "opkernel") && $(echo ${USE_CMD} | grep -wq "jit"); then
    echo "[ERROR] --opkernel cannot be used with --jit"
    exit 1
  fi

  if $(echo ${USE_CMD} | grep -wq "opkernel_aicpu") && $(echo ${USE_CMD} | grep -wq "jit"); then
    echo "[ERROR] --opkernel_aicpu cannot be used with --jit"
    exit 1
  fi
}

set_create_libs() {
  if [[ "$ENABLE_TEST" == "TRUE" ]]; then
    return
  fi
  if [[ "$ENABLE_PACKAGE" == "TRUE" && "$ENABLE_CUSTOM" != "TRUE" ]]; then
    BUILD_LIBS=("ophost_${REPOSITORY_NAME}" "opapi_${REPOSITORY_NAME}" "opgraph_${REPOSITORY_NAME}")
    ENABLE_CREATE_LIB=TRUE
  else
    if [[ "$OP_HOST" == "TRUE" ]]; then
      BUILD_LIBS+=("ophost_${REPOSITORY_NAME}")
      ENABLE_CREATE_LIB=TRUE
    fi
    if [[ "$OP_API" == "TRUE" ]]; then
      BUILD_LIBS+=("opapi_${REPOSITORY_NAME}")
      ENABLE_CREATE_LIB=TRUE
    fi
    if [[ "$OP_GRAPH" == "TRUE" ]]; then
      BUILD_LIBS+=("opgraph_${REPOSITORY_NAME}")
      ENABLE_CREATE_LIB=TRUE
    fi
    if [[ "$OP_KERNEL" == "TRUE" ]]; then
      ENABLE_BINARY=TRUE
    fi
  fi
}

set_ut_mode() {
  if [[ "$ENABLE_TEST" != "TRUE" ]]; then
    return
  fi
  UT_TEST_ALL=TRUE
  if [[ "$OP_HOST" == "TRUE" ]]; then
    OP_HOST_UT=TRUE
    UT_TEST_ALL=FALSE
  fi
  if [[ "$OP_API" == "TRUE" ]]; then
    OP_API_UT=TRUE
    UT_TEST_ALL=FALSE
  fi
  if [[ "$OP_GRAPH" == "TRUE" ]]; then
    OP_GRAPH_UT=TRUE
    UT_TEST_ALL=FALSE
  fi
  if [[ "$OP_KERNEL" == "TRUE" ]]; then
    OP_KERNEL_UT=TRUE
    UT_TEST_ALL=FALSE
  fi
  if [[ "$OP_KERNEL_AICPU" == "TRUE" ]]; then
    OP_KERNEL_AICPU_UT=TRUE
    UT_TEST_ALL=FALSE
  fi

  # 检查测试项，至少有一个
  if [[ "$UT_TEST_ALL" == "FALSE" && "$OP_HOST_UT" == "FALSE" && "$OP_API_UT" == "FALSE" && "$OP_GRAPH_UT" == "FALSE" && "$OP_KERNEL_UT" == "FALSE" && "$OP_KERNEL_AICPU_UT" == "FALSE" ]]; then
    echo "[ERROR] At least one test target must be specified (ophost_test, opapi_test, opgraph_test, opkernel_test, opkernel_aicpu_test)"
    usage
    exit 1
  fi

  if [[ "$UT_TEST_ALL" == "TRUE" ]] || [[ "$OP_HOST_UT" == "TRUE" ]]; then
    UT_TARGETS+=("${REPOSITORY_NAME}_op_host_ut")
  fi
  if [[ "$UT_TEST_ALL" == "TRUE" ]] || [[ "$OP_API_UT" == "TRUE" ]]; then
    UT_TARGETS+=("${REPOSITORY_NAME}_op_api_ut")
  fi
  if [[ "$UT_TEST_ALL" == "TRUE" ]] || [[ "$OP_KERNEL_UT" == "TRUE" ]]; then
    UT_TARGETS+=("${REPOSITORY_NAME}_op_kernel_ut")
  fi
  if [[ "$UT_TEST_ALL" == "TRUE" ]] || [[ "$OP_KERNEL_AICPU_UT" == "TRUE" ]]; then
    UT_TARGETS+=("${REPOSITORY_NAME}_aicpu_op_kernel_ut")
  fi
}

process_genop() {
  local opt_name=$1
  local genop_value=$2

  if [[ "$opt_name" == "genop" ]]; then
    ENABLE_GENOP=TRUE
  elif [[ "$opt_name" == "genop_aicpu" ]]; then
    ENABLE_GENOP_AICPU=TRUE
  else
    usage "genop"
    exit 1
  fi

  if [[ "$genop_value" != *"/"* ]] || [[ "$genop_value" == *"/" ]]; then
    usage "$opt_name"
    exit 1
  fi

  GENOP_NAME=${genop_value##*/}
  local remaining=${genop_value%/*}

  if [[ "$remaining" != *"/"* ]]; then
    GENOP_TYPE=$remaining
    GENOP_BASE=${BASE_PATH}
  else
    GENOP_TYPE=${remaining##*/}
    GENOP_BASE=${remaining%/*}
    if [[ ! "$GENOP_BASE" =~ ^/ && ! "$GENOP_BASE" =~ ^[a-zA-Z]: ]]; then
      GENOP_BASE="${BASE_PATH}/${GENOP_BASE}"
    fi
  fi
}

checkopts_run_example() {
  ENABLE_RUN_EXAMPLE=TRUE
  EXAMPLE_NAME="${!OPTIND}"
  ((OPTIND++))
  if [[ $OPTIND -le $# ]] && [[ "${!OPTIND}" != --* ]]; then
    EXAMPLE_MODE="${!OPTIND}"
    ((OPTIND++))
  fi

  if [[ $OPTIND -le $# ]] && [[ "${!OPTIND}" != --* ]]; then
    PKG_MODE="${!OPTIND}"
    ((OPTIND++))
    if [[ $OPTIND -le $# ]] && [[ "${!OPTIND}" == --vendor_name* ]]; then
      VENDOR="${!OPTIND}"
      VENDOR="${VENDOR#*=}"
      ((OPTIND++))
    else
      VENDOR="custom"
    fi
  fi
}

check_group_compile_config() {
  local base_path=${BASE_PATH}
  local yaml_file="$base_path/scripts/ci/ascend950/ops_math_operator_list.yaml"
  local pattern='AddConfig("ascend950'

  local group base_dir op_dir op_name
  local missing=0
  echo "[INFO] check ascend950 group compile config"
  for group in ops; do
    base_dir="$base_path/$group"
    [ -d "$base_dir" ] || continue
    for op_dir in "$base_dir"/*; do
      [ -d "$op_dir" ] || continue
      op_name=$(basename "$op_dir")
      if grep -q "$pattern" "$op_dir"/op_host/*def.cpp 2>/dev/null; then
        if ! grep -qw "$op_name" "$yaml_file"; then
          echo "[ERROR] $yaml_file does not configed op: $op_name"
          missing=1
        fi
      fi
    done
  done

  if [ "$missing" -ne 0 ]; then
    echo "[FAIL] ascend950 group compiled config failed"
    exit 1
  fi
  echo "[PASS] check ascend950 group compile config success"
  return 0
}

checkopts() {
  THREAD_NUM=8
  VERBOSE=""
  BUILD_MODE=""
  COMPILED_OPS=""
  UT_TEST_ALL=FALSE
  CHANGED_FILES=""
  CI_MODE=FALSE
  COMPUTE_UNIT=""
  VENDOR_NAME=""
  SHOW_HELP=""
  EXAMPLE_NAME=""
  EXAMPLE_MODE=""
  BUILD_TYPE="Release"
  USE_CMD="$*"
  BISHENG_FLAGS=""
  TILING_KEY=""

  ENABLE_MSSANITIZER=FALSE
  ENABLE_OOM=FALSE
  ENABLE_DUMP_CCE=FALSE
  ENABLE_COVERAGE=FALSE
  ENABLE_UT_EXEC=TRUE
  ENABLE_ASAN=FALSE
  ENABLE_VALGRIND=FALSE
  ENABLE_BINARY=FALSE
  ENABLE_CUSTOM=FALSE
  ENABLE_PACKAGE=FALSE
  ENABLE_TEST=FALSE
  ENABLE_EXPERIMENTAL=FALSE
  ENABLE_STATIC=FALSE
  AICPU_ONLY=FALSE
  OP_API_UT=FALSE
  OP_HOST_UT=FALSE
  OP_GRAPH_UT=FALSE
  OP_KERNEL_UT=FALSE
  OP_KERNEL_AICPU_UT=FALSE
  OP_API=FALSE
  OP_HOST=FALSE
  OP_GRAPH=FALSE
  OP_KERNEL=FALSE
  OP_KERNEL_AICPU=FALSE
  ENABLE_CREATE_LIB=FALSE
  ENABLE_RUN_EXAMPLE=FALSE
  NO_FORCE=FALSE
  BUILD_LIBS=()
  UT_TARGETS=()

  ENABLE_GENOP=FALSE
  ENABLE_GENOP_AICPU=FALSE
  GENOP_TYPE=""
  GENOP_NAME=""
  GENOP_BASE=${BASE_PATH}

  # 首先检查所有参数是否合法
  for arg in "$@"; do
    if [[ "$arg" =~ ^- ]]; then # 只检查以-开头的参数
      if ! check_option_validity "$arg"; then
        echo "[ERROR] Invalid param $arg, Use 'bash build.sh --help' for more information."
        exit 1
      fi
    fi
  done

  # 检查并处理--help
  for arg in "$@"; do
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
      # 检查帮助信息中的组合参数
      check_help_combinations "$@"
      local comb_result=$?
      if [ $comb_result -eq 1 ]; then
        exit 1
      fi
      SHOW_HELP="general"

      # 检查 --help 前面的命令
      for prev_arg in "$@"; do
        case "$prev_arg" in
          --pkg) SHOW_HELP="package" ;;
          --opkernel) SHOW_HELP="opkernel" ;;
          --opkernel_aicpu) SHOW_HELP="opkernel_aicpu" ;;
          -u) SHOW_HELP="test" ;;
          --make_clean) SHOW_HELP="clean" ;;
          --valgrind) SHOW_HELP="valgrind" ;;
          --ophost) SHOW_HELP="ophost" ;;
          --opapi) SHOW_HELP="opapi" ;;
          --opgraph) SHOW_HELP="opgraph" ;;
          --ophost_test) SHOW_HELP="ophost_test" ;;
          --opapi_test) SHOW_HELP="opapi_test" ;;
          --opgraph_test) SHOW_HELP="opgraph_test" ;;
          --run_example) SHOW_HELP="run_example" ;;
          --genop) SHOW_HELP="genop" ;;
          --genop_aicpu) SHOW_HELP="genop_aicpu" ;;
        esac
      done

      usage "$SHOW_HELP"
      exit 0
    fi
  done

  # Process the options
  while getopts $SUPPORTED_SHORT_OPTS opt; do
    case "${opt}" in
      h)
        usage
        exit 0
        ;;
      j) THREAD_NUM=$OPTARG ;;
      v) VERBOSE="VERBOSE=1" ;;
      O) BUILD_MODE="-O$OPTARG" ;;
      u) ENABLE_TEST=TRUE ;;
      f)
        CHANGED_FILES=$OPTARG
        CI_MODE=TRUE
        ;;
      -) case $OPTARG in
        help)
          usage
          exit 0
          ;;
        ops=*)
          COMPILED_OPS=${OPTARG#*=}
          ENABLE_CUSTOM=TRUE
          ;;
        genop=*)
          process_genop "genop" "${OPTARG#*=}"
          ;;
        genop_aicpu=*)
          process_genop "genop_aicpu" "${OPTARG#*=}"
          ;;
        soc=*)
          COMPUTE_UNIT=${OPTARG#*=}
          ;;
        vendor_name=*)
          VENDOR_NAME=${OPTARG#*=}
          ENABLE_CUSTOM=TRUE
          ;;
        build-type=*)
          BUILD_TYPE=${OPTARG#*=}
          ;;
        mssanitizer) ENABLE_MSSANITIZER=TRUE ;;
        oom) ENABLE_OOM=TRUE ;;
        dump_cce) ENABLE_DUMP_CCE=TRUE ;;
        bisheng_flags=*)
          BISHENG_FLAGS=${OPTARG#*=}
          ;;
        tiling_key=*)
          TILING_KEY=${OPTARG#*=}
          ;;
        cann_3rd_lib_path=*)
          CANN_3RD_LIB_PATH="$(realpath ${OPTARG#*=})"
          ;;
        cov) ENABLE_COVERAGE=TRUE ;;
        noexec) ENABLE_UT_EXEC=FALSE ;;
        aicpu) AICPU_ONLY=TRUE ;;
        pkg)
          ENABLE_BINARY=TRUE
          ENABLE_PACKAGE=TRUE
          ;;
        static)
          ENABLE_STATIC=TRUE
          ENABLE_BINARY=TRUE
          ;;
        jit) ENABLE_BINARY=FALSE ;;
        asan) ENABLE_ASAN=TRUE ;;
        valgrind)
          ENABLE_VALGRIND=TRUE
          ENABLE_UT_EXEC=FALSE
          ;;
        run_example)
          checkopts_run_example "$@"
          ;;
        experimental)
          ENABLE_EXPERIMENTAL=TRUE
          ENABLE_CUSTOM=TRUE
          ;;
        make_clean)
          clean_build
          clean_build_out
          clean_third_party
          exit 0
          ;;
        no_force) NO_FORCE=TRUE ;;
        *)
          ## 如果不在RELEASE_TARGETS 或者 UT_TARGETS，不做处理
          if ! in_array "$OPTARG" "${RELEASE_TARGETS[@]}" && ! in_array "$OPTARG" "${UT_TARGETS[@]}"; then
            echo "[ERROR] Invalid option: --$OPTARG"
            usage
            exit 1
          fi
          ## 如果_test形式的，那么获取正确的名，并强设UT_MODE为TRUE
          if [[ "$OPTARG" == *"_test" ]]; then
            OPTARG="${OPTARG%_test}"
            ENABLE_TEST=TRUE
          fi

          if [[ "$OPTARG" == "ophost" ]]; then
            OP_HOST=TRUE
          elif [[ "$OPTARG" == "opapi" ]]; then
            OP_API=TRUE
          elif [[ "$OPTARG" == "opgraph" ]]; then
            OP_GRAPH=TRUE
          elif [[ "$OPTARG" == "opkernel" ]]; then
            OP_KERNEL=TRUE
          elif [[ "$OPTARG" == "opkernel_aicpu" ]]; then
            OP_KERNEL_AICPU=TRUE
          else
            usage
            exit 1
          fi
          ;;
      esac ;;
      *)
        echo "Undefined option: ${opt}"
        usage
        exit 1
        ;;
    esac
  done
  shift $((OPTIND - 1))
  if [[ "x$@" != "x" ]]; then
    echo "unparsed param: $@"
    usage
    exit
  fi

  check_param
  set_create_libs
  parse_changed_files
  set_ut_mode
  check_group_compile_config
}

parse_changed_files() {
  if [[ -z "$CHANGED_FILES" ]]; then
    return
  fi

  if [[ "$CHANGED_FILES" != /* ]]; then
    CHANGED_FILES=$PWD/$CHANGED_FILES
  fi

  echo "changed files is "$CHANGED_FILES
  echo $dotted_line
  echo "changed lines:"
  cat $CHANGED_FILES
  echo $dotted_line

  COMPILED_OPS=$(python3 scripts/ci/parse_changed_ops.py $CHANGED_FILES "$ENABLE_EXPERIMENTAL")
  echo "related ops "$COMPILED_OPS

  if [[ -z $COMPILED_OPS ]]; then
    if [[ "$ENABLE_EXPERIMENTAL" == "TRUE" ]]; then
      COMPILED_OPS='log'
    else
      COMPILED_OPS='is_finite'
    fi
    echo "No ops changed found, set op $COMPILED_OPS as default."
  fi

  if [[ "$ENABLE_PACKAGE" == "TRUE" ]]; then
    return
  fi

  local script_ret=$(python3 scripts/ci/parse_changed_files.py $CHANGED_FILES "$ENABLE_EXPERIMENTAL")
  IFS='&&' read -r related_ut soc_info <<<"$script_ret"
  echo "related ut "$related_ut
  echo "related soc_info "$soc_info

  COMPUTE_UNIT=$soc_info

  if [[ "$related_ut" == "set()" ]]; then
    ENABLE_TEST=FALSE
    echo "no ut matched! no need to run!"
    echo "---------------- CANN build finished ----------------"
    return
  else
    ENABLE_TEST=TRUE
  fi

  if [[ "$related_ut" =~ "ALL_UT" ]]; then
    echo "ALL UT is triggered!"
    return
  fi
  if [[ ("$related_ut" =~ "OP_HOST_UT" || "$related_ut" =~ "OP_GRAPH_UT") && "$OP_HOST" == "TRUE" ]]; then
    echo "OP_HOST_UT is triggered!"
    OP_HOST_UT=TRUE
    OP_KERNEL_UT=TRUE
    OP_KERNEL=TRUE
    OP_GRAPH=TRUE
    ENABLE_CUSTOM=TRUE
  fi
  if [[ "$related_ut" =~ "OP_API_UT" && "$OP_API" == "TRUE" ]]; then
    echo "OP_API_UT is triggered!"
    OP_API_UT=TRUE
    ENABLE_CUSTOM=TRUE
  fi
  if [[ "$related_ut" =~ "OP_KERNEL_UT" && "$OP_KERNEL" == "TRUE" ]]; then
    echo "OP_KERNEL_UT is triggered!"
    OP_KERNEL_UT=TRUE
    ENABLE_CUSTOM=TRUE
  fi
}

custom_cmake_args() {
  if [[ -n $COMPILED_OPS ]]; then
    COMPILED_OPS="${COMPILED_OPS//,/;}"
    CMAKE_ARGS="$CMAKE_ARGS -DASCEND_OP_NAME=$COMPILED_OPS"
  fi
  if [[ -n $VENDOR_NAME ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DVENDOR_NAME=$VENDOR_NAME"
  fi
}

assemble_cmake_args() {
  if [[ "$ENABLE_ASAN" == "TRUE" ]]; then
    set +e
    echo 'int main() {return 0;}' | gcc -x c -fsanitize=address - -o asan_test >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "This environment does not have the ASAN library, no need enable ASAN"
      ENABLE_ASAN=FALSE
    else
      $(rm -f asan_test)
      CMAKE_ARGS="$CMAKE_ARGS -DENABLE_ASAN=TRUE"
    fi
    set -e
  fi
  if [[ "$ENABLE_VALGRIND" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DENABLE_VALGRIND=TRUE"
  fi
  if [[ "$ENABLE_TEST" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DENABLE_TEST=TRUE"
    custom_cmake_args
  fi
  if [[ "$ENABLE_UT_EXEC" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DENABLE_UT_EXEC=TRUE"
  fi
  if [[ "$ENABLE_COVERAGE" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DENABLE_COVERAGE=TRUE"
  fi
  if [[ "$ENABLE_BINARY" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DENABLE_BINARY=TRUE"
  fi
  if [[ "$ENABLE_CUSTOM" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DENABLE_CUSTOM=TRUE -DENABLE_BINARY=TRUE"
    custom_cmake_args
  fi
  if [[ "$ENABLE_PACKAGE" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DENABLE_PACKAGE=TRUE"
  fi
  if [[ "$ENABLE_EXPERIMENTAL" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DENABLE_EXPERIMENTAL=TRUE"
  fi
  if [[ "x$BUILD_MODE" != "x" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DBUILD_MODE=${BUILD_MODE}"
  fi
  if [[ "x$BISHENG_FLAGS" != "x" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DBISHENG_FLAGS=${BISHENG_FLAGS}"
  fi
  if [[ "x$TILING_KEY" != "x" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DTILING_KEY=${TILING_KEY}"
  fi
  if [[ "$OP_HOST_UT" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DOP_HOST_UT=TRUE"
  fi
  if [[ "$OP_API_UT" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DOP_API_UT=TRUE"
  fi
  if [[ "$OP_GRAPH_UT" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DOP_GRAPH_UT=TRUE"
  fi
  if [[ "$OP_KERNEL_UT" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DOP_KERNEL_UT=TRUE"
  fi
  if [[ "$OP_KERNEL_AICPU_UT" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DOP_KERNEL_AICPU_UT=TRUE"
  fi
  if [[ "$UT_TEST_ALL" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DUT_TEST_ALL=TRUE"
  fi
  if [[ "$ENABLE_STATIC" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DENABLE_STATIC=${ENABLE_STATIC}"
  fi
  if [[ -n "${BUILD_TYPE}" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DCMAKE_BUILD_TYPE=${BUILD_TYPE}"
  fi
  if [[ "$ENABLE_MSSANITIZER" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DENABLE_MSSANITIZER=TRUE"
  fi
  if [[ "$ENABLE_OOM" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DENABLE_OOM=TRUE"
  fi
  if [[ "$ENABLE_DUMP_CCE" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DENABLE_DUMP_CCE=TRUE"
  fi
  if [[ "$NO_FORCE" == "TRUE" ]]; then
    CMAKE_ARGS="$CMAKE_ARGS -DNO_FORCE=TRUE"
  fi
  if [[ -n $COMPUTE_UNIT ]]; then
    COMPUTE_UNIT=$(echo "$COMPUTE_UNIT" | tr '[:upper:]' '[:lower:]')
    found=0
    for support_unit in "${SUPPORT_COMPUTE_UNIT_SHORT[@]}"; do
      if [[ "$COMPUTE_UNIT" == "$support_unit" ]]; then
        COMPUTE_UNIT_SHORT=$support_unit
        found=1
        break
      fi
    done
    if [[ $found -eq 0 ]]; then
      echo "soc only support : ${SUPPORT_COMPUTE_UNIT_SHORT[@]}"
      exit 1
    fi
    echo "COMPUTE_UNIT: ${COMPUTE_UNIT}"
    CMAKE_ARGS="$CMAKE_ARGS -DASCEND_COMPUTE_UNIT=$COMPUTE_UNIT"
  fi
  CMAKE_ARGS="$CMAKE_ARGS -DCANN_3RD_LIB_PATH=${CANN_3RD_LIB_PATH}"
}

cmake_init() {
  if [[ "$ENABLE_GENOP" == "TRUE" || "$ENABLE_GENOP_AICPU" == "TRUE" ]]; then
    return
  fi
  if [ ! -d "${BUILD_PATH}" ]; then
    mkdir -p "${BUILD_PATH}"
  fi

  [ -f "${BUILD_PATH}/CMakeCache.txt" ] && rm -f ${BUILD_PATH}/CMakeCache.txt

  cd "${BUILD_PATH}" && cmake ${CMAKE_ARGS} ..
}

clean_build() {
  if [ -d "${BUILD_PATH}" ]; then
    rm -rf ${BUILD_PATH}/*
  fi
}

clean_build_out() {
  if [ -d "${BUILD_OUT_PATH}" ]; then
    rm -rf ${BUILD_OUT_PATH}/*
  fi
}

clean_third_party() {
  THIRD_PARTY_PATH=${BASE_PATH}/third_party
  if [ -d "${THIRD_PARTY_PATH}" ]; then
    rm -rf ${THIRD_PARTY_PATH}/abseil-cpp
    rm -rf ${THIRD_PARTY_PATH}/ascend_protobuf
  fi
}

clean_build_binary() {
  if [ -d "${BUILD_PATH}/tbe" ]; then
    rm -rf ${BUILD_PATH}/tbe/
  fi
  if [ -d "${BUILD_PATH}/autogen" ]; then
    rm -rf ${BUILD_PATH}/autogen/
  fi
  if [ -d "${BUILD_PATH}/binary" ]; then
    rm -rf ${BUILD_PATH}/binary/
  fi
  if [ -d "${BUILD_PATH}/es_packages" ]; then
    rm -rf ${BUILD_PATH}/es_packages/
  fi
  if [ -d "${BUILD_PATH}/es_math_build" ]; then
    rm -rf ${BUILD_PATH}/es_math_build/
  fi
  if [[ "$ENABLE_STATIC" == "TRUE" ]]; then
    if [ -d "${BUILD_PATH}/static_library_files" ]; then
      rm -rf ${BUILD_PATH}/static_library_files/
    fi
  fi
}

build_static_lib() {
  echo $dotted_line
  echo "Start to build static lib."

  cd "${BUILD_PATH}" && cmake ${CMAKE_ARGS} ..
  local all_targets=$(cmake --build . --target help)
  rm -fr ${BUILD_PATH}/bin_tmp
  mkdir -p ${BUILD_PATH}/bin_tmp
  if grep -wq "ophost_math_static" <<<"${all_targets}"; then
    cmake --build . --target ophost_math_static -- ${VERBOSE} -j $THREAD_NUM
  fi

  local UNITS=(${COMPUTE_UNIT_SHORT//;/ })
  if [[ ${#UNITS[@]} -eq 0 ]]; then
    UNITS+=("ascend910b")
  fi
  cmake --build . --target opapi_math_static -- ${VERBOSE} -j $THREAD_NUM
  for unit in "${UNITS[@]}"; do
    rm -fr ${BUILD_PATH}/bin_tmp/${unit}
    python3 "${BASE_PATH}/scripts/util/build_opp_kernel_static.py" GenStaticOpResourceIni -s ${unit} -b ${BUILD_PATH}
    python3 "${BASE_PATH}/scripts/util/build_opp_kernel_static.py" StaticCompile -s ${unit} -b ${BUILD_PATH} -n=0 -a=${ARCH_INFO}
  done
  cd "${BUILD_PATH}" && cmake ${CMAKE_ARGS} ..
  cmake --build . --target cann_math_static -- ${VERBOSE} -j $THREAD_NUM
  echo "Build static lib success!"
}

build_lib() {
  echo $dotted_line
  echo "Start to build libs ${BUILD_LIBS[@]}"

  cd "${BUILD_PATH}" && cmake ${CMAKE_ARGS} -UENABLE_STATIC ..

  for lib in "${BUILD_LIBS[@]}"; do
    echo "Building target ${lib}"
    cmake --build . --target ${lib} -- ${VERBOSE} -j $THREAD_NUM
  done

  echo $dotted_line
  echo "Build libs ${BUILD_LIBS[@]} success"
  echo $dotted_line
}

build_binary() {
  if [[ "$ENABLE_TEST" == "TRUE" ]]; then
    return
  fi

  echo $dotted_line
  echo "Start to build binary"

  echo "--------------- prepare build start ---------------"
  local all_targets=$(cmake --build . --target help)
  if echo "${all_targets}" | grep -wq "gen_bin_scripts"; then
    cmake --build . --target gen_bin_scripts -- ${VERBOSE} -j $THREAD_NUM
    if [ $? -ne 0 ]; then exit 1; fi
  fi
  echo "--------------- prepare build end ---------------"

  echo "--------------- binary build start ---------------"
  local cur_path=$(pwd)
  if [ "$ENABLE_CUSTOM" == "TRUE" ]; then
    cmake --build . --target ophost_math -- ${VERBOSE} -j $THREAD_NUM
  fi
  if [ ! -L op_impl/ai_core/tbe/op_tiling/liboptiling.so ]; then
    mkdir -p ${cur_path}/op_impl/ai_core/tbe/op_tiling
    ln -s ${cur_path}/libophost_math.so op_impl/ai_core/tbe/op_tiling/liboptiling.so
  fi
  export ASCEND_CUSTOM_OPP_PATH=${cur_path}

  local UNITS=(${COMPUTE_UNIT_SHORT//;/ })
  if [[ ${#UNITS[@]} -eq 0 ]]; then
    UNITS+=("ascend910b")
  fi
  for unit in "${UNITS[@]}"; do
    if echo "${all_targets}" | grep -wq "prepare_binary_compile_${unit}"; then
      cmake --build . --target prepare_binary_compile_${unit} -- ${VERBOSE} -j $THREAD_NUM
      if [ $? -ne 0 ]; then
        echo "[ERROR] Kernel compile failed!" && exit 1
      fi
      local opc_list_num=$(wc -l <"${BUILD_PATH}/binary/${unit}/bin/opc_cmd/opc_cmd.sh")
      CMAKE_ARGS="${CMAKE_ARGS} -DOPC_NUM_${unit}=${opc_list_num}"
    fi
  done

  echo "[INFO] CMAKE_ARGS is: ${CMAKE_ARGS}"
  cd "$BUILD_PATH" && cmake .. ${CMAKE_ARGS}

  if echo "${all_targets}" | grep -wq "binary"; then
    echo "[INFO] Start compile kernel binary."
    cmake --build . --target binary -- ${VERBOSE} -j $THREAD_NUM
    if [ $? -ne 0 ]; then
      echo "[ERROR] Kernel compile failed!" && exit 1
    fi
  fi
  if echo "${all_targets}" | grep -wq "gen_bin_info_config"; then
    cmake --build . --target gen_bin_info_config -- ${VERBOSE} -j $THREAD_NUM
    if [ $? -ne 0 ]; then exit 1; fi
  fi
  echo "--------------- binary build end ---------------"

  echo "Build binary success"
  echo $dotted_line
}

build_package() {
  echo "--------------- build package start ---------------"
  clean_build_out

  local all_targets=$(cmake --build . --target help)
  if [[ "$ENABLE_BINARY" != "TRUE" && "$ENABLE_CUSTOM" != "TRUE" ]]; then
    # gen impl python files
    if echo "${all_targets}" | grep -wq "ascendc_impl_gen"; then
      cmake --build . --target ascendc_impl_gen -- ${VERBOSE} -j $THREAD_NUM
      if [ $? -ne 0 ]; then exit 1; fi
    fi
  fi

  if echo "${all_targets}" | grep -wq "build_es_math"; then
    cmake --build . --target build_es_math -- ${VERBOSE} -j $THREAD_NUM
    [ $? -ne 0 ] && echo "[ERROR] target:build_es_math compile failed!" && exit 1
  fi
  cmake --build . --target package -- ${VERBOSE} -j $THREAD_NUM
  echo "--------------- build package end ---------------"
}

build_ut() {
  echo $dotted_line
  echo "Start to build ut"

  for lib in "${UT_TARGETS[@]}"; do
    $(find . -name "${lib}*" -type f -delete)
    cmake --build . --target ${lib} -- ${VERBOSE} -j $THREAD_NUM
  done
  if [[ "$ENABLE_COVERAGE" =~ "TRUE" ]]; then
    cmake --build . --target generate_ops_cpp_cov -- -j $THREAD_NUM
  fi
}

build_example() {
  echo $dotted_line
  echo "Start to run examples, name:${EXAMPLE_NAME} mode:${EXAMPLE_MODE}"

  # Determine file search pattern based on mode and experimental flag
  local file_pattern=""
  local search_path=""
  local executable_name=""

  if [[ "${EXAMPLE_MODE}" == "eager" ]]; then
    executable_name="test_aclnn_${EXAMPLE_NAME}"
    if [[ "$ENABLE_EXPERIMENTAL" == "TRUE" ]]; then
      search_path="../experimental"
    else
      search_path="../"
    fi
    file_pattern="test_aclnn_*.cpp"
  elif [[ "${EXAMPLE_MODE}" == "graph" ]]; then
    executable_name="test_geir_${EXAMPLE_NAME}"
    if [[ "$ENABLE_EXPERIMENTAL" == "TRUE" ]]; then
      search_path="../experimental"
    else
      search_path="../"
    fi
    file_pattern="test_geir_*.cpp"
  else
    usage
    exit 1
  fi

  # Find example files
  local find_cmd="find ${search_path} -path \"*/${EXAMPLE_NAME}/examples/*\" -name \"${file_pattern}\" -not -path \"*/scripts/*\""
  if [[ "$ENABLE_EXPERIMENTAL" != "TRUE" ]]; then
    find_cmd="${find_cmd} -not -path \"*/experimental/*\""
  fi

  local files=$(eval $find_cmd)

  if [ -z "$files" ]; then
    echo "ERROR: ${EXAMPLE_NAME} does not have ${EXAMPLE_MODE} examples"
    exit 1
  fi

  # Process each found file
  for f in $files; do
    echo "Start compile and run examples file: $f"

    # Compile based on mode
    if [[ "${EXAMPLE_MODE}" == "eager" ]]; then
      compile_eager_example "$f" "$executable_name"
    elif [[ "${EXAMPLE_MODE}" == "graph" ]]; then
      compile_graph_example "$f" "$executable_name"
    fi

    # Run the executable
    ./${executable_name}
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
      echo "run ${executable_name}, execute samples success"
    else
      echo "run ${executable_name}, execute samples failed"
      exit 1
    fi
  done
}

# Helper function to compile eager examples
compile_eager_example() {
  local source_file=$1
  local executable_name=$2

  if [[ "${PKG_MODE}" == "" ]]; then
    g++ ${source_file} \
      -I ${INCLUDE_PATH} \
      -I ${ACLNN_INCLUDE_PATH} \
      -L ${EAGER_LIBRARY_PATH} \
      -lopapi_math -lascendcl -lnnopbase \
      -o ${executable_name}

  elif [[ "${PKG_MODE}" == "cust" ]]; then
    echo "pkg_mode:${PKG_MODE} vendor_name:${VENDOR}"

    export CUST_LIBRARY_PATH="${ASCEND_HOME_PATH}/opp/vendors/${VENDOR}_math/op_api/lib"
    export CUST_INCLUDE_PATH="${ASCEND_HOME_PATH}/opp/vendors/${VENDOR}_math/op_api/include"
    local CUST_ACLNNOP_INCLUDE_PATH="${ASCEND_HOME_PATH}/opp/vendors/${VENDOR}_math/op_api/include/aclnnop"

    # Backup and set up symlink
    local include_dir_mode=$(stat -c %a $CUST_INCLUDE_PATH 2>/dev/null)
    if [ ! -L ${CUST_ACLNNOP_INCLUDE_PATH} ]; then
      chmod u+w $(dirname ${CUST_ACLNNOP_INCLUDE_PATH}) 2>/dev/null
      ln -s ${CUST_INCLUDE_PATH} ${CUST_ACLNNOP_INCLUDE_PATH} 2>/dev/null
    fi

    # Compile with custom paths
    g++ ${source_file} \
      -I ${INCLUDE_PATH} \
      -I ${INCLUDE_PATH}/aclnnop \
      -I ${CUST_INCLUDE_PATH} \
      -L ${CUST_LIBRARY_PATH} \
      -L ${EAGER_LIBRARY_PATH} \
      -lcust_opapi -lascendcl -lnnopbase \
      -o ${executable_name} \
      -Wl,-rpath=${CUST_LIBRARY_PATH}

    # Clean up symlink
    if [ -L ${CUST_ACLNNOP_INCLUDE_PATH} ]; then
      rm ${CUST_ACLNNOP_INCLUDE_PATH} 2>/dev/null
      chmod ${include_dir_mode} $CUST_INCLUDE_PATH 2>/dev/null
    fi
  else
    echo "Error: pkg_mode(${PKG_MODE}) must be cust or empty."
    exit 1
  fi
}

# Helper function to compile graph examples
compile_graph_example() {
  local source_file=$1
  local executable_name=$2

  g++ ${source_file} \
    -I ${GE_EXTERNAL_INCLUDE_PATH} \
    -I ${GRAPH_INCLUDE_PATH} \
    -I ${GE_INCLUDE_PATH} \
    -I ${INCLUDE_PATH} \
    -I ${INC_INCLUDE_PATH} \
    -L ${GRAPH_LIBRARY_PATH} \
    -lgraph -lge_runner -lgraph_base -lge_compiler \
    -o ${executable_name}
}

gen_op() {
  if [[ -z "$GENOP_NAME" ]] || [[ -z "$GENOP_TYPE" ]]; then
    echo "Error: op_class or op_name is not set."
    usage "genop"
  fi

  echo $dotted_line
  echo "Start to create the initial directory for ${GENOP_NAME} under ${GENOP_TYPE}"

  # 检查 python 或 python3 是否存在
  local python_cmd=""
  if command -v python3 &>/dev/null; then
    python_cmd="python3"
  elif command -v python &>/dev/null; then
    python_cmd="python"
  fi

  if [ -n "${python_cmd}" ]; then
    ${python_cmd} "${BASE_PATH}/scripts/opgen/opgen_standalone.py" -t ${GENOP_TYPE} -n ${GENOP_NAME} -p ${GENOP_BASE}
    echo "Create the initial directory for ${GENOP_NAME} under ${GENOP_TYPE} success"
    return $?
  fi
}

gen_aicpu_op() {
  if [[ -z "$GENOP_NAME" ]] || [[ -z "$GENOP_TYPE" ]]; then
    echo "Error: op_class or op_name is not set."
    usage "genop"
  fi

  echo $dotted_line
  echo "Start to create the AI CPU initial directory for ${GENOP_NAME} under ${GENOP_TYPE}"

  # 检查 python 或 python3 是否存在
  local python_cmd=""
  if command -v python3 &>/dev/null; then
    python_cmd="python3"
  elif command -v python &>/dev/null; then
    python_cmd="python"
  fi

  if [ -n "${python_cmd}" ]; then
    ${python_cmd} "${BASE_PATH}/scripts/opgen/opgen_standalone.py" -t ${GENOP_TYPE} -n ${GENOP_NAME} -p ${GENOP_BASE} -v aicpu
    echo "Create the AI CPU initial directory for ${GENOP_NAME} under ${GENOP_TYPE} success"
    return $?
  else
    echo "Please install Python to generate op project framework."
  fi
}

build_package_static() {
  # Check weather BUILD_OUT_PATH directory exists
  if [ ! -d "$BUILD_OUT_PATH" ]; then
    echo "Error: Directory $BUILD_OUT_PATH does not exist"
    return 1
  fi

  # Check weather *.run is exists and verify the file numbers
  local run_files=("$BUILD_OUT_PATH"/*.run)
  if [ ${#run_files[@]} -eq 0 ]; then
    echo "Error: No .run files found in $BUILD_OUT_PATH directory"
    return 1
  fi
  if [ ${#run_files[@]} -gt 1 ]; then
    echo "Error: Multiple .run files found in $BUILD_OUT_PATH directory:"
    printf '%s\n' "${run_files[@]}"
    return 1
  fi

  # Get filename of *.run file and set new directory name
  local run_file=$(basename "${run_files[0]}")
  echo "Found .run file: $run_file"
  if [[ "$run_file" != *"ops"* ]]; then
    echo "Error: Filename '$run_file' does not contain 'ops'"
    return 1
  fi
  local new_name="${run_file/ops/ops-static}"
  new_name="${new_name%.run}"

  # Check weather $BUILD_PATH/static_library_files directory exists and not empty
  local static_files_dir="$BUILD_PATH/static_library_files"
  if [ ! -d "$static_files_dir" ]; then
    echo "Error: Directory $static_files_dir does not exist"
    return 1
  fi
  if [ -z "$(ls -A "$static_files_dir")" ]; then
    echo "Error: Directory $static_files_dir is empty"
    return 1
  fi

  # Rename directory
  local new_dir_path="$BUILD_PATH/$new_name"
  if mv "$static_files_dir" "$new_dir_path"; then
    echo "Preparing for packaging: renamed $static_files_dir to $new_dir_path"
  else
    echo "Packaging preparation failed: directory rename failed ($static_files_dir -> $new_dir_path)"
    return 1
  fi

  # Create compressed package and restore directory name
  local new_filename="${new_name}.tar.gz"
  if tar -czf "$BUILD_OUT_PATH/$new_filename" -C "$BUILD_PATH" "$new_name"; then
    echo "[SUCCESS] Build static lib success!"
    echo "Successfully created compressed package: $BUILD_OUT_PATH/$new_filename"
    # Restore original directory name
    echo "Restoring original directory name: $new_dir_path -> $static_files_dir"
    mv "$new_dir_path" "$static_files_dir"
    return 0
  else
    echo "Error: Failed to create compressed package"
    # Attempt to restore original directory name
    mv "$new_dir_path" "$static_files_dir"
    return 1
  fi
}

main() {
  checkopts "$@"
  if [ "$THREAD_NUM" -gt "$CORE_NUMS" ]; then
    echo "compile thread num:$THREAD_NUM over core num:$CORE_NUMS, adjust to core num"
    THREAD_NUM=$CORE_NUMS
  fi
  assemble_cmake_args
  echo "CMAKE_ARGS: ${CMAKE_ARGS}"

  clean_build_binary
  cmake_init
  if [ "$ENABLE_CREATE_LIB" == "TRUE" ]; then
    build_lib
  fi
  if [[ "$ENABLE_BINARY" == "TRUE" || "$ENABLE_CUSTOM" == "TRUE" ]]; then
    build_binary
  fi
  if [[ "$ENABLE_STATIC" == "TRUE" ]]; then
    build_static_lib
  fi
  if [[ "$ENABLE_PACKAGE" == "TRUE" ]]; then
    build_package
    if [[ "$ENABLE_STATIC" == "TRUE" ]]; then
      build_package_static
    fi
  fi
  if [[ "$ENABLE_TEST" == "TRUE" ]]; then
    build_ut
  fi
  if [[ "$ENABLE_RUN_EXAMPLE" == "TRUE" ]]; then
    build_example
  fi
  if [[ "$ENABLE_GENOP" == "TRUE" ]]; then
    gen_op
  fi
  if [[ "$ENABLE_GENOP_AICPU" == "TRUE" ]]; then
    gen_aicpu_op
  fi
}

set -o pipefail
if [ $# -eq 0 ]; then
  usage
  exit 0
fi
main "$@" 2>&1 | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}'
