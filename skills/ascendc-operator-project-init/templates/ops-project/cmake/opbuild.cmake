# ----------------------------------------------------------------------------
# Copyright (c) 2025 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
# ----------------------------------------------------------------------------
# ######################################################################################################################
# 调用opbuild工具，生成aclnn/aclnnInner/.ini的算子信息库 等文件 generate outpath: ${ASCEND_AUTOGEN_PATH}/${sub_dir}
# ######################################################################################################################
function(gen_opbuild_target)
  set(oneValueArgs TARGET PREFIX GENACLNN OUT_DIR OUT_SUB_DIR)
  set(multiValueArgs IN_SRCS OUT_SRCS OUT_HEADERS)
  cmake_parse_arguments(OPBUILD "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  if(NOT OPBUILD_IN_SRCS)
    message(STATUS "No ${OPBUILD_PREFIX} srcs, skip ${OPBUILD_TARGET}")
    return()
  endif()

  add_library(gen_op_host_${OPBUILD_PREFIX} SHARED ${OPBUILD_IN_SRCS})
  target_link_libraries(gen_op_host_${OPBUILD_PREFIX} PRIVATE $<BUILD_INTERFACE:intf_pub_cxx17> exe_graph register
          c_sec)
  target_compile_options(gen_op_host_${OPBUILD_PREFIX} PRIVATE -fno-common)
  string(REPLACE ";" "\;" OPS_PRODUCT_NAME "${ASCEND_COMPUTE_UNIT}")


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
  endif()
  message("LIBASAN_PATH = ${LIBASAN_PATH}")
  add_custom_command(
          OUTPUT ${OPBUILD_OUT_SRCS} ${OPBUILD_OUT_HEADERS}
          COMMAND
          OPS_PROTO_SEPARATE=1 OPS_PROJECT_NAME=${OPBUILD_PREFIX} OPS_ACLNN_GEN=${OPBUILD_GENACLNN}
          OPS_PRODUCT_NAME=\"${OPS_PRODUCT_NAME}\"
          env LD_PRELOAD=${LIBASAN_PATH}
          env LD_LIBRARY_PATH=${ASCEND_DIR}/${SYSTEM_PREFIX}/lib64:$ENV{LD_LIBRARY_PATH} ${OP_BUILD_TOOL}
          $<TARGET_FILE:gen_op_host_${OPBUILD_PREFIX}> ${OPBUILD_OUT_DIR}/${OPBUILD_OUT_SUB_DIR})

  add_custom_target(${OPBUILD_TARGET} DEPENDS ${OPBUILD_OUT_SRCS} ${OPBUILD_OUT_HEADERS})
  add_dependencies(${OPBUILD_TARGET} gen_op_host_${OPBUILD_PREFIX})
  if(TARGET op_build)
    add_dependencies(${OPBUILD_TARGET} op_build)
  endif()
endfunction()

function(gen_aclnn_classify host_obj prefix ori_out_srcs ori_out_headers opbuild_out_srcs opbuild_out_headers)
  get_target_property(module_sources ${host_obj} INTERFACE_SOURCES)
  set(sub_dir)
  # aclnn\aclnnExc以aclnn开头，aclnnInner以aclnnInner开头
  if("${prefix}" STREQUAL "aclnn")
    set(file_prefix "aclnn")
    set(need_gen_aclnn 1)
  elseif("${prefix}" STREQUAL "aclnnInner")
    set(sub_dir inner)
    set(file_prefix "aclnnInner")
    set(need_gen_aclnn 1)
  elseif("${prefix}" STREQUAL "aclnnExc")
    set(sub_dir exc)
    set(file_prefix "aclnn")
    set(need_gen_aclnn 0)
  else()
    message(FATAL_ERROR "UnSupported aclnn prefix type, must be in aclnn/aclnnInner/aclnnExc")
  endif()

  set(out_src_path ${ASCEND_AUTOGEN_PATH}/${sub_dir})
  file(MAKE_DIRECTORY ${out_src_path})
  get_filename_component(out_src_path ${out_src_path} REALPATH)
  set(in_srcs)
  set(out_srcs)
  set(out_headers)
  if(module_sources)
    foreach(file ${module_sources})
      get_filename_component(name_without_ext ${file} NAME_WE)
      string(REGEX REPLACE "_def$" "" _op_name ${name_without_ext})
      list(APPEND in_srcs ${file})
      list(APPEND out_srcs ${out_src_path}/${file_prefix}_${_op_name}.cpp)
      list(APPEND out_headers ${out_src_path}/${file_prefix}_${_op_name}.h)
    endforeach()
  endif()
  # opbuild_gen_aclnn/opbuild_gen_aclnnInner/opbuild_gen_aclnnExc
  gen_opbuild_target(
          TARGET opbuild_gen_${prefix} PREFIX ${prefix} GENACLNN ${need_gen_aclnn} IN_SRCS "${in_srcs}" OUT_SRCS
          "${out_srcs}" OUT_HEADERS "${out_headers}" OUT_DIR ${ASCEND_AUTOGEN_PATH} OUT_SUB_DIR ${sub_dir})
  if("${prefix}" STREQUAL "aclnnExc")
    get_target_property(exclude_headers ${OPHOST_NAME}_aclnn_exclude_headers INTERFACE_SOURCES)
    if(exclude_headers)
      set(${opbuild_out_headers} ${ori_out_headers} ${exclude_headers} PARENT_SCOPE)
    endif()
  else()
    set(${opbuild_out_srcs} ${ori_out_srcs} ${out_srcs} PARENT_SCOPE)
    if("${prefix}" STREQUAL "aclnn")
      set(${opbuild_out_headers} ${ori_out_headers} ${out_headers} PARENT_SCOPE)
    endif()
  endif()
endfunction()

function(gen_aclnn_master_header aclnn_master_header_name aclnn_master_header opbuild_out_headers)
  # 规范化，防止生成的代码编译失败
  string(REGEX REPLACE "[^a-zA-Z0-9_]" "_" aclnn_master_header_name "${aclnn_master_header_name}")
  string(TOUPPER ${aclnn_master_header_name} aclnn_master_header_name)

  # 生成include内容
  set(aclnn_all_header_include_content "")
  foreach(header_file ${opbuild_out_headers})
    get_filename_component(header_name ${header_file} NAME)
    set(aclnn_all_header_include_content "${aclnn_all_header_include_content}#include \"${header_name}\"\n")
  endforeach()

  # 根据模板生成头文件
  message(STATUS "create aclnn master header file: ${aclnn_master_header}")
  configure_file(
          "${CMAKE_CURRENT_SOURCE_DIR}/cmake/aclnn_ops_math.h.in"
          "${aclnn_master_header}"
          @ONLY
  )
endfunction()

function(gen_aclnn_with_opdef)
  set(opbuild_out_srcs)
  set(opbuild_out_headers)
  gen_aclnn_classify(${OPHOST_NAME}_opdef_aclnn_obj aclnn "${opbuild_out_srcs}" "${opbuild_out_headers}"
          opbuild_out_srcs opbuild_out_headers)
  gen_aclnn_classify(${OPHOST_NAME}_opdef_aclnn_inner_obj aclnnInner "${opbuild_out_srcs}" "${opbuild_out_headers}"
          opbuild_out_srcs opbuild_out_headers)
  gen_aclnn_classify(${OPHOST_NAME}_opdef_aclnn_exclude_obj aclnnExc "${opbuild_out_srcs}" "${opbuild_out_headers}"
          opbuild_out_srcs opbuild_out_headers)

  # 创建汇总头文件
  if(ENABLE_CUSTOM)
    set(aclnn_master_header_name "aclnn_ops_math_${VENDOR_NAME}")
  else()
    set(aclnn_master_header_name "aclnn_ops_math")
  endif()
  set(aclnn_master_header "${CMAKE_CURRENT_BINARY_DIR}/${aclnn_master_header_name}.h")
  gen_aclnn_master_header(${aclnn_master_header_name} "${aclnn_master_header}" "${opbuild_out_headers}")

  # 将头文件安装到packages/vendors/vendor_name/op_api/include
  if(ENABLE_PACKAGE)
    if(ENABLE_CUSTOM)
      install(FILES ${opbuild_out_headers} DESTINATION ${ACLNN_INC_INSTALL_DIR} OPTIONAL)
      install(FILES ${aclnn_master_header} DESTINATION ${ACLNN_INC_INSTALL_DIR} OPTIONAL)
    else()
      install(FILES ${opbuild_out_headers} DESTINATION ${ACLNN_INC_INSTALL_DIR} OPTIONAL)
      install(FILES ${aclnn_master_header} DESTINATION ${ACLNN_INC_INSTALL_DIR} OPTIONAL)
      install(FILES ${opbuild_out_headers} DESTINATION ${ACLNN_INC_LEVEL2_INSTALL_DIR} OPTIONAL)
      install(FILES ${aclnn_master_header} DESTINATION ${ACLNN_INC_LEVEL2_INSTALL_DIR} OPTIONAL)
    endif()
    if(ENABLE_STATIC)
      install(FILES ${opbuild_out_headers} DESTINATION ${STATIC_ACLNN_INC_INSTALL_DIR} OPTIONAL)
      install(FILES ${opbuild_out_headers} DESTINATION "${STATIC_ACLNN_INC_INSTALL_DIR}/aclnnop" OPTIONAL)
      install(FILES ${aclnn_master_header} DESTINATION ${STATIC_ACLNN_INC_INSTALL_DIR} OPTIONAL)
      install(FILES ${aclnn_master_header} DESTINATION "${STATIC_ACLNN_INC_INSTALL_DIR}/aclnnop" OPTIONAL)
      if(NOT ENABLE_CUSTOM)
        install(FILES ${opbuild_out_headers} DESTINATION ${STATIC_ACLNN_INC_LEVEL2_INSTALL_DIR} OPTIONAL)
        install(FILES ${aclnn_master_header} DESTINATION ${STATIC_ACLNN_INC_LEVEL2_INSTALL_DIR} OPTIONAL)
      endif()
    endif()
  endif()

  # ascendc_impl_gen depends opbuild_custom_gen_aclnn_all, for opbuild will generate .ini
  set(dependency_list)
  if(TARGET opbuild_gen_aclnn)
    list(APPEND dependency_list opbuild_gen_aclnn)
  endif()
  if(TARGET opbuild_gen_aclnnInner)
    list(APPEND dependency_list opbuild_gen_aclnnInner)
  endif()
  if(TARGET opbuild_gen_aclnnExc)
    list(APPEND dependency_list opbuild_gen_aclnnExc)
  endif()
  if(NOT dependency_list)
    message(STATUS "no operator info to generate")
    return()
  endif()
  add_custom_target(opbuild_custom_gen_aclnn_all
                    COMMAND python3 ${PROJECT_SOURCE_DIR}/scripts/util/modify_gen_aclnn_static.py ${CMAKE_BINARY_DIR})
  add_dependencies(opbuild_custom_gen_aclnn_all ${dependency_list})
  if(opbuild_out_srcs)
    set_source_files_properties(${opbuild_out_srcs} PROPERTIES GENERATED TRUE)
    add_library(opbuild_gen_aclnn_all OBJECT ${opbuild_out_srcs})
    add_dependencies(opbuild_gen_aclnn_all opbuild_custom_gen_aclnn_all)
    target_include_directories(opbuild_gen_aclnn_all PRIVATE ${OPAPI_INCLUDE})
  endif()
endfunction()
