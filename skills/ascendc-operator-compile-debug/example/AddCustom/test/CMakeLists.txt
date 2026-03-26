# Copyright (c) Huawei Technologies Co., Ltd. 2025. All rights reserved.

# CMake lowest version requirement
cmake_minimum_required(VERSION 3.14)

# 设置工程名
project(ACLNN_ADD_CUSTOM_EXAMPLE)

# Compile options
add_compile_options(-std=c++11)

# 设置编译选项
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY  "./bin")
set(CMAKE_CXX_FLAGS_DEBUG "-fPIC -O0 -g -Wall")
set(CMAKE_CXX_FLAGS_RELEASE "-fPIC -O2 -Wall")

# 设置可执行文件名，并指定待运行算子文件*.cpp所在目录
add_executable(opapi_test_add_custom
               test_aclnn_add_custom.cpp) 

# 设置ASCEND_PATH（CANN软件包目录，请根据实际路径修改）和INCLUDE_BASE_DIR（头文件目录）
if(NOT "$ENV{ASCEND_HOME_PATH}" STREQUAL "")      
    set(ASCEND_PATH $ENV{ASCEND_HOME_PATH})
else()
    set(ASCEND_PATH "/usr/local/Ascend/cann")
endif()
set(INCLUDE_BASE_DIR "${ASCEND_PATH}/include")
include_directories(
    ${INCLUDE_BASE_DIR}
    ${INCLUDE_BASE_DIR}/aclnn
    ${INCLUDE_BASE_DIR}/aclnnop
    # custom包安装后的头文件路径
    /data/yyd/Ascend/cann-9.0.0/opp/vendors/customize/op_api/include 
)

# 设置链接的库文件路径 - 移除了不需要的math和transformer库
target_link_libraries(opapi_test_add_custom PRIVATE
                      ${ASCEND_PATH}/lib64/libascendcl.so
                      ${ASCEND_PATH}/lib64/libnnopbase.so
                      # custom包使用libcust_opapi.so（安装后的路径）
                      /data/yyd/Ascend/cann-9.0.0/opp/vendors/customize/op_api/lib/libcust_opapi.so 
                      )

# 可执行文件在CMakeLists文件所在目录的bin目录下
install(TARGETS opapi_test_add_custom DESTINATION ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})