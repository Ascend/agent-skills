# ----------------------------------------------------------------------------
# Copyright (c) 2025 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
# ----------------------------------------------------------------------------

set(COMMON_NAME common_${PKG_NAME})
set(OPHOST_NAME ophost_${PKG_NAME})
set(OPSTATIC_NAME cann_${PKG_NAME}_static)
set(OPAPI_NAME opapi_${PKG_NAME})
set(OPGRAPH_NAME opgraph_${PKG_NAME})
set(GRAPH_PLUGIN_NAME graph_plugin_${PKG_NAME})
set(ONNX_PLUGIN_NAME op_${PKG_NAME}_onnx_plugin)

# interface, 用于收集aclnn/aclnn_inner/aclnn_exclude的def文件
add_library(${OPHOST_NAME}_opdef_aclnn_obj INTERFACE)
add_library(${OPHOST_NAME}_opdef_aclnn_inner_obj INTERFACE)
add_library(${OPHOST_NAME}_opdef_aclnn_exclude_obj INTERFACE)
add_library(${OPHOST_NAME}_aclnn_exclude_headers INTERFACE)
# interface, 用于收集ops proto头文件
add_library(${GRAPH_PLUGIN_NAME}_proto_headers INTERFACE)

# global variables
# 需要编译的算子
set(NEED_COMPILE_OPS "${ASCEND_OP_NAME}" CACHE STRING "Need to be compiled Ops" FORCE)
# 已编译的算子
set(COMPILED_OPS CACHE STRING "Compiled Ops" FORCE)
set(COMPILED_OP_DIRS CACHE STRING "Compiled Ops Dirs" FORCE)

# src path
get_filename_component(OPS_MATH_CMAKE_DIR           "${OPS_MATH_DIR}/cmake"                              REALPATH)
get_filename_component(OPS_MATH_COMMON_INC          "${OPS_MATH_DIR}/common/inc"                         REALPATH)
get_filename_component(OPS_MATH_COMMON_INC_COMMON   "${OPS_MATH_COMMON_INC}/common"                      REALPATH)
get_filename_component(OPS_MATH_COMMON_INC_EXTERNAL "${OPS_MATH_COMMON_INC}/external"                    REALPATH)
get_filename_component(OPS_MATH_COMMON_INC_HEADERS  "${OPS_MATH_COMMON_INC_EXTERNAL}/aclnn_kernels"      REALPATH)
get_filename_component(OPS_KERNEL_BINARY_SCRIPT     "${OPS_MATH_DIR}/scripts/kernel/binary_script"       REALPATH)
get_filename_component(OPS_KERNEL_BINARY_CONFIG     "${OPS_MATH_DIR}/scripts/kernel/binary_config"       REALPATH)

# python
if(NOT DEFINED ASCEND_PYTHON_EXECUTABLE)
  set(ASCEND_PYTHON_EXECUTABLE python3 CACHE STRING "")
endif()

# install path
if(ENABLE_CUSTOM)
  # custom package install path
  set(PATH_NAME "${VENDOR_NAME}_math")

  set(ACLNN_INC_INSTALL_DIR           packages/vendors/${PATH_NAME}/op_api/include)
  set(ACLNN_LIB_INSTALL_DIR           packages/vendors/${PATH_NAME}/op_api/lib)
  set(OPS_INFO_INSTALL_DIR            packages/vendors/${PATH_NAME}/op_impl/ai_core/tbe/config)
  set(IMPL_INSTALL_DIR                packages/vendors/${PATH_NAME}/op_impl/ai_core/tbe/${PATH_NAME}_impl/ascendc)
  set(IMPL_DYNAMIC_INSTALL_DIR        packages/vendors/${PATH_NAME}/op_impl/ai_core/tbe/${PATH_NAME}_impl/dynamic)
  set(BIN_KERNEL_INSTALL_DIR          packages/vendors/${PATH_NAME}/op_impl/ai_core/tbe/kernel)
  set(BIN_KERNEL_CONFIG_INSTALL_DIR   packages/vendors/${PATH_NAME}/op_impl/ai_core/tbe/kernel/config)
  set(OPTILING_INSTALL_DIR            packages/vendors/${PATH_NAME}/op_impl/ai_core/tbe/op_tiling/)
  set(OPTILING_LIB_INSTALL_DIR        packages/vendors/${PATH_NAME}/op_impl/ai_core/tbe/op_tiling/lib/linux/${CMAKE_SYSTEM_PROCESSOR})
  set(OPPROTO_INC_INSTALL_DIR         packages/vendors/${PATH_NAME}/op_proto/inc)
  set(OPPROTO_LIB_INSTALL_DIR         packages/vendors/${PATH_NAME}/op_proto/lib/linux/${CMAKE_SYSTEM_PROCESSOR})
  set(AICPU_KERNEL_IMPL               packages/vendors/${PATH_NAME}/op_impl/cpu/aicpu_kernel/impl)
  set(AICPU_JSON_CONFIG               packages/vendors/${PATH_NAME}/op_impl/cpu/config)
  set(CUST_AICPU_OP_PROTO             packages/vendors/${PATH_NAME}/op_proto)
  set(ES_INC_INSTALL_DIR              packages/vendors/${PATH_NAME}/op_proto/es/include)
  set(ES_LIB_INSTALL_DIR              packages/vendors/${PATH_NAME}/op_proto/es/lib/linux/${CMAKE_SYSTEM_PROCESSOR})
  set(VERSION_INFO_INSTALL_DIR        packages/vendors/${PATH_NAME}/)
else()
  # built-in package install path
  set(ACLNN_INC_INSTALL_DIR           ops_math/built-in/op_impl/ai_core/tbe/op_api/include/aclnnop)
  set(ACLNN_INC_LEVEL2_INSTALL_DIR    ops_math/built-in/op_impl/ai_core/tbe/op_api/include/aclnnop/level2)
  set(ACLNN_LIB_INSTALL_DIR           ops_math/built-in/op_impl/ai_core/tbe/op_api/lib/linux/${CMAKE_SYSTEM_PROCESSOR})
  set(OPS_INFO_INSTALL_DIR            ops_math/built-in/op_impl/ai_core/tbe/config)
  set(IMPL_INSTALL_DIR                ops_math/built-in/op_impl/ai_core/tbe/impl/ops_math/ascendc)
  set(IMPL_DYNAMIC_INSTALL_DIR        ops_math/built-in/op_impl/ai_core/tbe/impl/ops_math/dynamic)
  set(BIN_KERNEL_INSTALL_DIR          ops_math/built-in/op_impl/ai_core/tbe/kernel)
  set(BIN_KERNEL_CONFIG_INSTALL_DIR   ops_math/built-in/op_impl/ai_core/tbe/kernel/config)
  set(OPHOST_INC_INSTALL_PATH         ops_math/built-in/op_impl/ai_core/tbe/op_host/include)
  set(OPHOST_LIB_INSTALL_PATH         ops_math/built-in/op_impl/ai_core/tbe/op_host/lib/linux/${CMAKE_SYSTEM_PROCESSOR})
  set(AICPU_KERNEL_IMPL               ops_math/built-in/op_impl/aicpu/kernel)
  set(AICPU_JSON_CONFIG               ops_math/built-in/op_impl/aicpu/config)
  set(OPTILING_LIB_INSTALL_DIR        ${OPHOST_LIB_INSTALL_PATH})
  set(OPGRAPH_INC_INSTALL_DIR         ops_math/built-in/op_graph/inc)
  set(OPGRAPH_LIB_INSTALL_DIR         ops_math/built-in/op_graph/lib/linux/${CMAKE_SYSTEM_PROCESSOR})
  set(ONNX_PLUGIN_LIB_INSTALL_DIR     ops_math/built-in/framework/onnx)
  set(COMMON_INC_INSTALL_DIR          ops_math/include)
  set(COMMON_LIB_INSTALL_DIR          ops_math/lib)
  set(VERSION_INFO_INSTALL_DIR        ops_math)
endif()

if(ENABLE_STATIC)
  set(STATIC_LIBRARY_FILES_DIR ${CMAKE_BINARY_DIR}/static_library_files)
  set(STATIC_BIN_INSTALL_DIR ${CMAKE_BINARY_DIR}/static_library_files/lib64)
  set(STATIC_ACLNN_INC_INSTALL_DIR ${CMAKE_BINARY_DIR}/static_library_files/include)
  set(STATIC_ACLNN_INC_LEVEL2_INSTALL_DIR ${CMAKE_BINARY_DIR}/static_library_files/include)
  set(STATIC_OPHOST_INC_INSTALL_PATH ${CMAKE_BINARY_DIR}/static_library_files/include)
  set(STATIC_COMMON_INC_INSTALL_DIR ${CMAKE_BINARY_DIR}/static_library_files/include)
  set(STATIC_ES_INC_INSTALL_DIR ${CMAKE_BINARY_DIR}/static_library_files/include)
  file(MAKE_DIRECTORY ${STATIC_LIBRARY_FILES_DIR})
  file(MAKE_DIRECTORY ${STATIC_BIN_INSTALL_DIR})
  file(MAKE_DIRECTORY ${STATIC_ACLNN_INC_INSTALL_DIR})
endif()

# util path
set(ASCEND_TENSOR_COMPILER_PATH ${ASCEND_DIR}/compiler)
set(ASCEND_CCEC_COMPILER_PATH ${ASCEND_TENSOR_COMPILER_PATH}/ccec_compiler/bin)
set(OP_BUILD_TOOL ${ASCEND_DIR}/tools/opbuild/op_build)

set(UT_PATH ${CMAKE_CURRENT_SOURCE_DIR}/tests/ut)
set(OP_API_UT_COMMON_INC ${UT_PATH}/op_api/op_api_ut_common/inc)
set(UT_COMMON_INC ${UT_PATH}/common)

# output path
set(ASCEND_AUTOGEN_PATH     ${CMAKE_BINARY_DIR}/autogen)
set(ASCEND_TBE_BUILD_PATH   ${CMAKE_BINARY_DIR}/tbe)
set(ASCEND_KERNEL_SRC_DST   ${ASCEND_TBE_BUILD_PATH}/ascendc)
set(ASCEND_KERNEL_CONF_DST  ${ASCEND_TBE_BUILD_PATH}/config)
set(ASCEND_GRAPH_CONF_DST   ${ASCEND_TBE_BUILD_PATH}/graph)
file(MAKE_DIRECTORY ${ASCEND_AUTOGEN_PATH})
file(MAKE_DIRECTORY ${ASCEND_KERNEL_SRC_DST})
file(MAKE_DIRECTORY ${ASCEND_KERNEL_CONF_DST})
file(MAKE_DIRECTORY ${ASCEND_GRAPH_CONF_DST})
set(CUSTOM_COMPILE_OPTIONS "custom_compile_options.ini")
set(CUSTOM_OPC_OPTIONS "custom_opc_options.ini")
execute_process(
  COMMAND rm -rf ${ASCEND_AUTOGEN_PATH}/${CUSTOM_COMPILE_OPTIONS}
  COMMAND rm -rf ${ASCEND_AUTOGEN_PATH}/${CUSTOM_OPC_OPTIONS}
  COMMAND touch ${ASCEND_AUTOGEN_PATH}/${CUSTOM_COMPILE_OPTIONS}
  COMMAND touch ${ASCEND_AUTOGEN_PATH}/${CUSTOM_OPC_OPTIONS}
)

# pack path
set(CMAKE_INSTALL_PREFIX ${CMAKE_SOURCE_DIR}/build_out)

set(OPAPI_INCLUDE
  ${OPS_MATH_DIR}/common/inc
  ${OPS_MATH_DIR}/common/inc/op_api
  ${OPS_MATH_DIR}/common/inc/external
  ${C_SEC_INCLUDE}
  ${PLATFORM_INC_DIRS}
  ${METADEF_INCLUDE_DIRS}
  ${NNOPBASE_INCLUDE_DIRS}
  ${NPURUNTIME_INCLUDE_DIRS}
  ${AICPU_INC_DIRS}
  ${OPBASE_INC_DIRS}
  ${OPS_MATH_DIR}/
  ${TOP_DIR}/output/${PRODUCT}/aclnnop_resource
)

set(OP_TILING_INCLUDE
  ${C_SEC_INCLUDE}
  ${PLATFORM_INC_DIRS}
  ${METADEF_INCLUDE_DIRS}
  ${TILINGAPI_INC_DIRS}
  ${NPURUNTIME_INCLUDE_DIRS}
  ${OPBASE_INC_DIRS}
  ${OPS_MATH_DIR}
  ${OPS_MATH_DIR}/common/inc/
  ${OPS_MATH_DIR}/common/inc/op_api
)

set(OP_PROTO_INCLUDE
  ${C_SEC_INCLUDE}
  ${METADEF_INCLUDE_DIRS}
  ${OPBASE_INC_DIRS}
  ${NPURUNTIME_INCLUDE_DIRS}
  ${OPS_MATH_DIR}
  ${OPS_MATH_DIR}/common/inc/
  ${OPS_MATH_DIR}/common/inc/op_api
  ${OPS_MATH_DIR}/common/inc/common
  ${TOP_DIR}/runtime/pkg_inc
)

set(AICPU_INCLUDE
  ${OPBASE_INC_DIRS}
  ${AICPU_INC_DIRS}
  ${C_SEC_INCLUDE}
  ${NNOPBASE_INCLUDE_DIRS}
  ${HCCL_EXTERNAL_INCLUDE}
  ${OPS_MATH_DIR}/common/inc/op_api
  ${METADEF_INCLUDE_DIRS}
)

set(AICPU_DEFINITIONS
  -O2
  -std=c++14
  -fstack-protector-all
  -fvisibility-inlines-hidden
  -fvisibility=hidden
  -frename-registers
  -fpeel-loops
  -DEIGEN_NO_DEBUG
  -DEIGEN_MPL2_ONLY
  -DNDEBUG
  -DEIGEN_HAS_CXX11_MATH
  -DEIGEN_OS_GNULINUX
  -DEigen=ascend_Eigen
  -fno-common
  -fPIC
)

set(OPS_CATEGORY_LIST
  "ops"
)

# mapping of soc full name and short name
set(SHORT_NAME_LIST "ascend910_93" "ascend950" "ascend910b" "ascend910" "ascend310p")
set(FULL_NAME_LIST "ascend910_9391" "ascend910PR_9599" "ascend910B1" "ascend910A" "ascend310P1")
