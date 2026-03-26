# ----------------------------------------------------------------------------
# Copyright (c) 2025 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
# ----------------------------------------------------------------------------

if(UT_TEST_ALL OR OP_API_UT)
  ## set variables
  set(OP_API_UT_EXE ${PKG_NAME}_op_api_ut)

  ## load opapi ut common depends: python
  include(${PROJECT_SOURCE_DIR}/cmake/modules/FindPython.cmake)

  ## load opapi ut common
  file(GLOB SUBDIRECTORIES LIST_DIRECTORIES true RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/*)
  foreach(SUBDIR ${SUBDIRECTORIES})
    if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${SUBDIR}/CMakeLists.txt)
      add_subdirectory(${SUBDIR})
    endif()
  endforeach()

  ## add opapi ut cases object: math_op_tiling_ut_cases_obj
  add_opapi_ut_modules(${OP_API_MODULE_NAME})

  ## add opapi source so: libopapi_math_ut.so
  add_library(${OPAPI_NAME}_ut SHARED
          $<TARGET_OBJECTS:${OPHOST_NAME}_opapi_obj>
          )
  target_link_libraries(${OPAPI_NAME}_ut PRIVATE
          $<BUILD_INTERFACE:intf_llt_pub_asan_cxx17>
          )

  ## add opapi ut exe:  math_op_api_ut
  add_executable(${OP_API_UT_EXE}
          test_op_api_main.cpp
          $<TARGET_OBJECTS:${OP_API_MODULE_NAME}_cases_obj>
          )
  target_compile_options(${OP_API_UT_EXE} PUBLIC -fPIE -fno-access-control)
  target_link_directories(${OP_API_UT_EXE} PRIVATE
          ${ASCEND_DIR}/${SYSTEM_PREFIX}/lib64
          )
  target_link_libraries(${OP_API_UT_EXE} PRIVATE
          $<BUILD_INTERFACE:intf_llt_pub_asan_cxx17>
          -Wl,--as-needed
              op_api_ut_common
              ${OPAPI_NAME}_ut
              nnopbase
              unified_dlog
          -Wl,--no-as-needed
          -Wl,--whole-archive
          graph
          gtest
          -Wl,--no-whole-archive
          )

  ## exec opapi ut exe
  if(ENABLE_UT_EXEC)
    if(ENABLE_ASAN)
      execute_process(
        COMMAND ${CMAKE_C_COMPILER} -print-file-name=libasan.so
        OUTPUT_VARIABLE LIBASAN_PATH
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE result
      )
      if(NOT result EQUAL 0)
        message(FATAL_ERROR "compiler not support asan, please disable asan")
      endif()

      execute_process(
        COMMAND ${CMAKE_C_COMPILER} -print-file-name=libstdc++.so
        OUTPUT_VARIABLE LIBSTDC_PATH
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE stdc_result
      )
      if(NOT stdc_result EQUAL 0)
        message(FATAL_ERROR "not find libstdc++.so, please confirm.")
      endif()

      add_custom_command(
          TARGET ${OP_API_UT_EXE}
          POST_BUILD
          COMMAND
              ${CMAKE_COMMAND} -E env LD_LIBRARY_PATH=$ENV{LD_LIBRARY_PATH}
              LD_PRELOAD=${LIBASAN_PATH}:${LIBSTDC_PATH} ASAN_OPTIONS=detect_leaks=0
              $<TARGET_FILE:${OP_API_UT_EXE}>
              COMMENT "Run ops op_api utest with asan"
      )
    else()
      add_custom_command(
              TARGET ${OP_API_UT_EXE}
              POST_BUILD
              COMMAND
              ${CMAKE_COMMAND} -E env LD_LIBRARY_PATH=$ENV{LD_LIBRARY_PATH} $<TARGET_FILE:${OP_API_UT_EXE}>
              COMMENT "Run ops op_api utest"
      )
    endif()
  endif()
endif()
