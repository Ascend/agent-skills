# ----------------------------------------------------------------------------
# This program is free software, you can redistribute it and/or modify it.
# Copyright (c) 2025 Huawei Technologies Co., Ltd.
# This file is a part of the CANN Open Software.
# Licensed under CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING
# BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
# ----------------------------------------------------------------------------

if(BUILD_WITH_INSTALLED_DEPENDENCY_CANN_PKG)
  npu_op_library(${COMMON_NAME}_obj TILING)
else()
  add_library(${COMMON_NAME}_obj OBJECT)
endif()

file(GLOB CPP_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/op_host/*.cpp")

target_sources(${COMMON_NAME}_obj PRIVATE ${CPP_SOURCES})

target_include_directories(${COMMON_NAME}_obj
  PRIVATE
  ${C_SEC_INCLUDE}
  ${TILINGAPI_INC_DIRS}
  ${PLATFORM_INC_DIRS}
  ${METADEF_INCLUDE_DIRS}
  ${OPS_MATH_DIR}/common/inc
  ${ASCEND_DIR}/pkg_inc
)

target_link_libraries(${COMMON_NAME}_obj
  PRIVATE
  $<BUILD_INTERFACE:intf_pub_cxx17>
  tiling_api
)

if(NOT ENABLE_EXPERIMENTAL)
  file(GLOB CURRENT_DIRS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/*)
  foreach(SUB_DIR ${CURRENT_DIRS})
      if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${SUB_DIR}/framework/CMakeLists.txt")
          add_subdirectory(${SUB_DIR}/framework)
      endif()
  endforeach()
endif()