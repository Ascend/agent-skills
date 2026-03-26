# Copyright (c) 2025 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
# ============================================================================

# load ut common depends
include(${PROJECT_SOURCE_DIR}/cmake/intf_pub_llt_gccnative.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/third_party/gtest.cmake)

file(
  GLOB SUBDIRECTORIES
  LIST_DIRECTORIES true
  RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}/*)
foreach(SUBDIR ${SUBDIRECTORIES})
  if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${SUBDIR}/CMakeLists.txt)
    add_subdirectory(${SUBDIR})
  endif()
endforeach()

if(ENABLE_COVERAGE)
  if(UT_TEST_ALL OR OP_KERNEL_UT)
    set(depend_module ${depend_module} ${PKG_NAME}_op_kernel_ut)
  endif()
  if(UT_TEST_ALL OR OP_HOST_UT)
    set(depend_module ${depend_module} ${PKG_NAME}_op_host_ut)
  endif()
  if(UT_TEST_ALL OR OP_API_UT)
    set(depend_module ${depend_module} ${PKG_NAME}_op_api_ut)
  endif()
  if(UT_TEST_ALL OR OP_KERNEL_AICPU_UT)
    set(depend_module ${depend_module} ${PKG_NAME}_aicpu_op_kernel_ut)
  endif()
  message("coverage depend_module is ${depend_module}")
  if(NOT "" STREQUAL "${depend_module}")
    add_custom_target(
      generate_ops_cpp_cov ALL
      DEPENDS ${depend_module}
      COMMENT "Generate coverage for ops ut")
  endif()

  if(ENABLE_UT_EXEC)
    set(GENERATE_CPP_COV ${CMAKE_SOURCE_DIR}/scripts/util/generate_cpp_cov.sh)
    set(_ops_capture_path ${CMAKE_BINARY_DIR})
    set(_ops_cov_report ${CMAKE_BINARY_DIR}/tests/ut/cov_report)
    set(_ops_cov_html ${_ops_cov_report}/cpp_utest)
    set(_ops_cov_data ${_ops_cov_report}/cpp_utest/ops.info)
    message(STATUS "GENERATE_CPP_COV is ${GENERATE_CPP_COV}")
    add_custom_command(
      TARGET generate_ops_cpp_cov
      COMMAND bash ${GENERATE_CPP_COV} ${_ops_capture_path} ${_ops_cov_data}
              ${_ops_cov_html})
  endif()
endif()
