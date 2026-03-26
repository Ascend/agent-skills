# ----------------------------------------------------------------------------
# Copyright (c) 2025 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
# ----------------------------------------------------------------------------

include(FindPackageHandleStandardArgs)
set(runtime_FOUND ON)
#search acl.h
set(ACL_HEAD_SEARCH_PATHS
  ${ASCEND_DIR}/${SYSTEM_PREFIX}/include
  ${ASCEND_DIR}/${SYSTEM_PREFIX}/include/external
  ${TOP_DIR}/ace/npuruntime/acl/inc/external            # compile with ci
  ${TOP_DIR}/runtime/pkg_inc
  ${TOP_DIR}/runtime/include/external
)
find_path(ACL_INC_DIR
  NAMES acl/acl.h
  PATHS ${ACL_HEAD_SEARCH_PATHS}
  NO_CMAKE_SYSTEM_PATH
  NO_CMAKE_FIND_ROOT_PATH
)
if(NOT ACL_INC_DIR)
  set(runtime_FOUND OFF)
  message(FATAL_ERROR "no source acl include dir found")
endif()
get_filename_component(ACL_INC_DIR ${ACL_INC_DIR} REALPATH)
message(STATUS "Found source acl include dir:  ${ACL_INC_DIR}")

# search rt.h
set(RUNTIME_SEARCH_PATH
  ${ASCEND_DIR}/${SYSTEM_PREFIX}/include/experiment/runtime
  ${ASCEND_DIR}/${SYSTEM_PREFIX}/pkg_inc/runtime
  ${TOP_DIR}/ace/npuruntime/inc            # compile with ci
  ${TOP_DIR}/runtime/pkg_inc/runtime
)
find_path(RUNTIME_INC_DIR
  NAMES runtime/rt.h
  PATHS ${RUNTIME_SEARCH_PATH}
  NO_CMAKE_SYSTEM_PATH
  NO_CMAKE_FIND_ROOT_PATH
)

# retry with 3.1 package
if(NOT RUNTIME_INC_DIR)
  set(RUNTIME_SEARCH_PATH
    ${ASCEND_DIR}/${SYSTEM_PREFIX}/pkg_inc
  )
  find_path(RUNTIME_INC_DIR
    NAMES runtime/rt_external.h
    PATHS ${RUNTIME_SEARCH_PATH}
    NO_CMAKE_SYSTEM_PATH
    NO_CMAKE_FIND_ROOT_PATH
  )
endif()

if(NOT RUNTIME_INC_DIR)
  set(runtime_FOUND OFF)
  message(FATAL_ERROR "no source runtime include dir found")
endif()
get_filename_component(RUNTIME_INC_DIR ${RUNTIME_INC_DIR} REALPATH)

if(runtime_FOUND)
  if(NOT runtime_FIND_QUIETLY)	
    message(STATUS "[math]Found source npuruntime include dir: ${RUNTIME_INC_DIR}")
  endif()
  set(NPURUNTIME_INCLUDE_DIRS
    ${ACL_INC_DIR}
    ${TOP_DIR}/runtime/pkg_inc
    ${TOP_DIR}/runtime/pkg_inc/runtime
    ${TOP_DIR}/runtime/pkg_inc/profiling
    ${RUNTIME_INC_DIR}
    ${RUNTIME_INC_DIR}/runtime
    ${RUNTIME_INC_DIR}/../profiling
  )
endif()
