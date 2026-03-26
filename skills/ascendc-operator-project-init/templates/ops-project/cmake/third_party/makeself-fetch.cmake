# ----------------------------------------------------------------------------
# Copyright (c) 2025 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
# ----------------------------------------------------------------------------

set(MAKESELF_NAME "makeself")
set(MAKESELF_PATH ${CANN_3RD_LIB_PATH}/makeself)
set(MAKESELF_VERSION_PKG makeself-release-2.5.0-patch1.tar.gz)

if(POLICY CMP0135)
    cmake_policy(SET CMP0135 NEW)
endif()

# 默认配置的makeself还是不存在则下载
if (NOT EXISTS "${MAKESELF_PATH}/makeself-header.sh" OR NOT EXISTS "${MAKESELF_PATH}/makeself.sh")
    # 优先查找本地压缩包
    if(EXISTS "${CANN_3RD_LIB_PATH}/pkg/${MAKESELF_VERSION_PKG}")
        set(REQ_URL "file://${CANN_3RD_LIB_PATH}/pkg/${MAKESELF_VERSION_PKG}")
        message(STATUS "[ThirdPartyLib][makeself] found in ${REQ_URL}.")
    elseif(EXISTS "${CANN_3RD_LIB_PATH}/${MAKESELF_VERSION_PKG}")
        set(REQ_URL "file://${CANN_3RD_LIB_PATH}/${MAKESELF_VERSION_PKG}")
        message(STATUS "[ThirdPartyLib][makeself] found in ${REQ_URL}.")
    else()
        set(REQ_URL "https://gitcode.com/cann-src-third-party/makeself/releases/download/release-2.5.0-patch1.0/${MAKESELF_VERSION_PKG}")
        message(STATUS "[ThirdPartyLib][makeself] ${REQ_URL} not found, need download.")
    endif()

    include(FetchContent)
    FetchContent_Declare(
        ${MAKESELF_NAME}
        URL ${REQ_URL}
        URL_HASH SHA256=bfa730a5763cdb267904a130e02b2e48e464986909c0733ff1c96495f620369a
        DOWNLOAD_DIR ${CANN_3RD_LIB_PATH}/pkg
        SOURCE_DIR "${MAKESELF_PATH}"  # 直接解压到此目录
    )
    FetchContent_MakeAvailable(${MAKESELF_NAME})
    execute_process(
        COMMAND chmod 700 "${CMAKE_BINARY_DIR}/makeself/makeself.sh"
        COMMAND chmod 700 "${CMAKE_BINARY_DIR}/makeself/makeself-header.sh"
        -E env
        CMAKE_TLS_VERIFY=0
        RESULT_VARIABLE CHMOD_RESULT
        ERROR_VARIABLE CHMOD_ERROR
    )
endif()
