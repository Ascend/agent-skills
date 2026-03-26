# ----------------------------------------------------------------------------
# Copyright (c) 2025 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
# ----------------------------------------------------------------------------

cmake_minimum_required(VERSION 3.16)
set(PKG_NAME math)
project(${PKG_NAME} VERSION 1.0.0)

find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
  set(CMAKE_C_COMPILER_LAUNCHER ${CCACHE_PROGRAM})
  set(CMAKE_CXX_COMPILER_LAUNCHER ${CCACHE_PROGRAM})
endif()

if(PROJECT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
  message(STATUS "compile project with library")
  option(BUILD_WITH_INSTALLED_DEPENDENCY_CANN_PKG "Build ops with cann pkg" ON)
else()
  message(STATUS "compile project with src")
  option(BUILD_WITH_INSTALLED_DEPENDENCY_CANN_PKG "Build ops with cann source" OFF)
endif()

if(UNIX)
  set(SYSTEM_PREFIX ${CMAKE_SYSTEM_PROCESSOR}-linux)
endif()
set(OPS_MATH_DIR ${CMAKE_CURRENT_SOURCE_DIR})

# 外部传参
option(ENABLE_ASAN "Enable asan" OFF)
option(ENABLE_VALGRIND "Enable valgrind" OFF)
option(ENABLE_TEST "Enable test" OFF)
option(ENABLE_UT_EXEC "Enable exec ut" OFF)
option(ENABLE_BINARY "Enable build binary" OFF)
option(ENABLE_CUSTOM "Enable build custom" OFF)
option(ENABLE_PACKAGE "Enable build package" OFF)
option(ENABLE_EXPERIMENTAL "Enable experimental module" OFF)
option(ENABLE_COVERAGE "Enable coverage" OFF)
option(ENABLE_MSSANITIZER "Enable mssanitizer mode" OFF)
option(ENABLE_OOM "Enable oom mode" OFF)
option(ENABLE_DUMP_CCE "Enable dump_cce mode" OFF)

option(OP_HOST_UT "Enable ophost ut" OFF)
option(OP_API_UT "Enable opapi ut" OFF)
option(OP_GRAPH_UT "Enable graph ut" OFF)
option(OP_KERNEL_UT "Enable kernel ut" OFF)
option(OP_KERNEL_AICPU_UT "Enable aicpu kernel ut" OFF)
option(UT_TEST_ALL "Enable all ut" OFF)
set(BISHENG_FLAGS "" CACHE STRING "bisheng compiler flags")
set(TILING_KEY "" CACHE STRING " tiling key")
set(BUILD_MODE "" CACHE STRING "build mode -O0/O1/O2/O3")
set(ASCEND_COMPUTE_UNIT "ascend910b" CACHE STRING "soc that need to be compiled")
# if(NOT CANN_3RD_LIB_PATH)
#   set(CANN_3RD_LIB_PATH ${PROJECT_SOURCE_DIR}/third_party CACHE STRING "cann third party lib path")
# endif()
# 指定编译的算子
set(ASCEND_OP_NAME "" CACHE STRING "operators that designated for compilation")
set(VENDOR_NAME "custom" CACHE STRING "vendor name")
set(ASCEND_ALL_COMPUTE_UNIT "ascend031;ascend035;ascend630;ascend610lite;ascend310b;ascend310p;ascend910;ascend910b;ascend910_93;ascend950;kirinx90;kirin9030;mc62cm12a")

if("${BUILD_MODE}" STREQUAL "-O0" OR "${BUILD_MODE}" STREQUAL "-O1" OR
   "${BUILD_MODE}" STREQUAL "-O2" OR "${BUILD_MODE}" STREQUAL "-O3"
  )
  set(COMPILE_OP_MODE ${BUILD_MODE})
else()
  if(ENABLE_TEST)
    set(COMPILE_OP_MODE "-O0")
  else()
    set(COMPILE_OP_MODE "-O2")
  endif()
endif()
if(ENABLE_TEST)
  set(COMPILE_OP_MODE "${COMPILE_OP_MODE} -g")
  set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "cmake build type")
else()
  set(CMAKE_BUILD_TYPE "Release" CACHE STRING "cmake build type")
endif()

# Cmake Compile配置
set(CMAKE_CXX_STANDARD 17 CACHE STRING "c++17 is needed for this project")
include(cmake/dependencies.cmake)
include(cmake/variables.cmake)
include(cmake/opbuild.cmake)
# include(cmake/third_party/eigen.cmake)
# include(cmake/third_party/abseil-cpp.cmake)
# include(cmake/third_party/ascend_protobuf.cmake)
# include(cmake/third_party/json.cmake)
include(cmake/func.cmake)
include(cmake/intf_pub_linux.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/ut.cmake)

add_subdirectory(common)

foreach(ops_category ${OPS_CATEGORY_LIST})
  add_subdirectory("${ops_category}")
endforeach()

set(_orig_ops "${ASCEND_OP_NAME}")
list(LENGTH _orig_ops _orig_len)
set(_filtered_ops "${_orig_ops}")
list(FILTER _filtered_ops INCLUDE REGEX "add_example")
list(LENGTH _filtered_ops _filtered_len)
if(_orig_len GREATER 0 AND _filtered_len EQUAL _orig_len)
    add_subdirectory(examples)
endif()

if(ENABLE_TEST)
  add_subdirectory(tests/ut)
endif()

check_compiled_ops()

if(BUILD_WITH_INSTALLED_DEPENDENCY_CANN_PKG AND NOT ENABLE_TEST)
  include(cmake/gen_ops_info.cmake)
  gen_ops_info_and_python()

  include(cmake/symbol.cmake)
  if(ENABLE_CUSTOM)
    # custom package library setting and install
    gen_cust_symbol()
  else()
    gen_norm_symbol()
  endif()
endif()

if(ENABLE_PACKAGE)
  include(cmake/package.cmake)

  if(ENABLE_CUSTOM)
    pack_custom()
  else()
    pack_built_in()
  endif()

  if(ENABLE_STATIC)
      include(cmake/static.cmake)
  endif()
endif()
