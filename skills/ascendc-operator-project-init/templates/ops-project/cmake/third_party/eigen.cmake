# ----------------------------------------------------------------------------
# Copyright (c) 2025 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
# ----------------------------------------------------------------------------
if(POLICY CMP0135)
    cmake_policy(SET CMP0135 NEW)
endif()
set(EIGEN_VERSION_PKG eigen-5.0.0.tar.gz)

unset(eigen_FOUND CACHE)
unset(EIGEN_INCLUDE CACHE)

find_path(EIGEN_INCLUDE
        NAMES Eigen/Eigen
        NO_CMAKE_SYSTEM_PATH
        NO_CMAKE_FIND_ROOT_PATH
        PATHS
          ${CANN_3RD_LIB_PATH}/eigen-5.0.0
          ${CANN_3RD_LIB_PATH}/eigen)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(eigen
        FOUND_VAR
        eigen_FOUND
        REQUIRED_VARS
        EIGEN_INCLUDE
        )

if(eigen_FOUND)
  message(STATUS "Found eigen in ${EIGEN_INCLUDE}")
else()
  if(EXISTS "${CANN_3RD_LIB_PATH}/pkg/${EIGEN_VERSION_PKG}")
    set(REQ_URL "${CANN_3RD_LIB_PATH}/pkg/${EIGEN_VERSION_PKG}")
    message(STATUS "[ThirdPartyLib][eigen] found in ${REQ_URL}.")
  elseif(EXISTS "${CANN_3RD_LIB_PATH}/${EIGEN_VERSION_PKG}")
    set(REQ_URL "${CANN_3RD_LIB_PATH}/${EIGEN_VERSION_PKG}")
    message(STATUS "[ThirdPartyLib][eigen] found in ${REQ_URL}.")
  else()
    set(REQ_URL "https://gitcode.com/cann-src-third-party/eigen/releases/download/5.0.0/${EIGEN_VERSION_PKG}")
    message(STATUS "[ThirdPartyLib][eigen] ${REQ_URL} not found, need download.")
  endif()

  include(ExternalProject)
  ExternalProject_Add(external_eigen_math
    URL               ${REQ_URL}
    DOWNLOAD_DIR      ${CANN_3RD_LIB_PATH}/pkg
    SOURCE_DIR        ${CANN_3RD_LIB_PATH}/eigen
    CONFIGURE_COMMAND ""
    BUILD_COMMAND     ""
    INSTALL_COMMAND   ""
  )

  ExternalProject_Get_Property(external_eigen_math SOURCE_DIR)
  set(EIGEN_INCLUDE ${SOURCE_DIR})
endif()

add_library(EigenMath INTERFACE)
target_compile_options(EigenMath INTERFACE -w)

set_target_properties(EigenMath PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES "${EIGEN_INCLUDE}"
)
add_dependencies(EigenMath external_eigen_math)

add_library(Eigen3::EigenMath ALIAS EigenMath)
