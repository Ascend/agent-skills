# Stage 4: 测试样例开发与执行

本文档是 ascendc-operator-compile-debug Skill 的参考文档，包含测试样例开发、编译和执行的详细步骤。

## 目录

1. [测试样例开发](#测试样例开发)
2. [测试工程搭建](#测试工程搭建)
3. [测试程序编译](#测试程序编译)
4. [测试程序执行与验证](#测试程序执行与验证)
5. [常见测试问题与解决方案](#常见测试问题与解决方案)

## 测试样例开发

测试样例需要使用ACL和aclnn接口调用自定义算子，验证其功能正确性。以下是一个基本的测试样例结构：

### test_aclnn_add_custom.cpp

查看完整的[测试样例1](../example/AddCustom/test/test_aclnn_add_custom.cpp)和[测试样例2](../example/AddCustom/test_new/test_aclnn_add_custom.cpp)。

```cpp
#include <iostream>
#include <vector>
#include "acl/acl.h"
#include "aclnn_add_custom.h"

#define CHECK_RET(cond, return_expr) \
    do {                              \
        if (!(cond)) {                \
            return_expr;              \
        }                             \
    } while (0)

#define LOG_PRINT(message, ...)         \
    do {                                \
        printf(message, ##__VA_ARGS__); \
    } while (0)

int64_t GetShapeSize(const std::vector<int64_t>& shape) {
    int64_t shapeSize = 1;
    for (auto i : shape) {
        shapeSize *= i;
    }
    return shapeSize;
}

void PrintOutResult(std::vector<int64_t>& shape, void** deviceAddr, 
                    const std::vector<float>& selfXHostData, const std::vector<float>& selfYHostData) {
    auto size = GetShapeSize(shape);
    std::vector<float> resultData(size, 0);
    auto ret = aclrtMemcpy(
        resultData.data(), resultData.size() * sizeof(resultData[0]), *deviceAddr, size * sizeof(resultData[0]),
        ACL_MEMCPY_DEVICE_TO_HOST);
    CHECK_RET(ret == ACL_SUCCESS, LOG_PRINT("copy result from device to host failed. ERROR: %d\n", ret); return);
    for (int64_t i = 0; i < size; i++) {
        LOG_PRINT("add_custom first input[%ld] is: %f, second input[%ld] is: %f, result[%ld] is: %f\n", 
                 i, selfXHostData[i], i, selfYHostData[i], i, resultData[i]);
    }
}

int Init(int32_t deviceId, aclrtStream* stream) {
    // 初始化ACL环境
    auto ret = aclInit(nullptr);
    CHECK_RET(ret == ACL_SUCCESS, LOG_PRINT("aclInit failed. ERROR: %d\n", ret); return ret);
    
    // 设置设备
    ret = aclrtSetDevice(deviceId);
    CHECK_RET(ret == ACL_SUCCESS, LOG_PRINT("aclrtSetDevice failed. ERROR: %d\n", ret); return ret);
    
    // 创建流
    ret = aclrtCreateStream(stream);
    CHECK_RET(ret == ACL_SUCCESS, LOG_PRINT("aclrtCreateStream failed. ERROR: %d\n", ret); return ret);
    
    return 0;
}

template <typename T>
int CreateAclTensor(
    const std::vector<T>& hostData, const std::vector<int64_t>& shape, void** deviceAddr, 
    aclDataType dataType, aclTensor** tensor) {
    auto size = GetShapeSize(shape) * sizeof(T);
    
    // 申请device侧内存
    auto ret = aclrtMalloc(deviceAddr, size, ACL_MEM_MALLOC_HUGE_FIRST);
    CHECK_RET(ret == ACL_SUCCESS, LOG_PRINT("aclrtMalloc failed. ERROR: %d\n", ret); return ret);
    
    // 拷贝数据到device侧
    ret = aclrtMemcpy(*deviceAddr, size, hostData.data(), size, ACL_MEMCPY_HOST_TO_DEVICE);
    CHECK_RET(ret == ACL_SUCCESS, LOG_PRINT("aclrtMemcpy failed. ERROR: %d\n", ret); return ret);

    // 计算strides
    std::vector<int64_t> strides(shape.size(), 1);
    for (int64_t i = shape.size() - 2; i >= 0; i--) {
        strides[i] = shape[i + 1] * strides[i + 1];
    }

    // 创建aclTensor
    *tensor = aclCreateTensor(
        shape.data(), shape.size(), dataType, strides.data(), 0, aclFormat::ACL_FORMAT_ND, 
        shape.data(), shape.size(), *deviceAddr);
    
    return 0;
}

int main(int argc, char* argv[]) {
    // 1. 初始化ACL环境和设备
    int32_t deviceId = 0;
    
    // 支持通过命令行参数指定设备ID
    if (argc > 1) {
        deviceId = atoi(argv[1]);
    }
    
    aclrtStream stream;
    auto ret = Init(deviceId, &stream);
    CHECK_RET(ret == ACL_SUCCESS, LOG_PRINT("Init acl failed. ERROR: %d\n", ret); return ret);

    // 2. 准备输入输出数据
    aclTensor* selfX = nullptr;
    void* selfXDeviceAddr = nullptr;
    std::vector<int64_t> selfXShape = {32, 4, 4, 4};
    std::vector<float> selfXHostData(2048, 1); // 32*4*4*4=2048
    ret = CreateAclTensor(selfXHostData, selfXShape, &selfXDeviceAddr, aclDataType::ACL_FLOAT, &selfX);
    CHECK_RET(ret == ACL_SUCCESS, return ret);

    aclTensor* selfY = nullptr;
    void* selfYDeviceAddr = nullptr;
    std::vector<int64_t> selfYShape = {32, 4, 4, 4};
    std::vector<float> selfYHostData(2048, 1);
    ret = CreateAclTensor(selfYHostData, selfYShape, &selfYDeviceAddr, aclDataType::ACL_FLOAT, &selfY);
    CHECK_RET(ret == ACL_SUCCESS, return ret);

    aclTensor* out = nullptr;
    void* outDeviceAddr = nullptr;
    std::vector<int64_t> outShape = {32, 4, 4, 4};
    std::vector<float> outHostData(2048, 1);
    ret = CreateAclTensor(outHostData, outShape, &outDeviceAddr, aclDataType::ACL_FLOAT, &out);
    CHECK_RET(ret == ACL_SUCCESS, return ret);

    // 3. 调用算子API
    uint64_t workspaceSize = 0;
    aclOpExecutor* executor;

    // 获取工作空间大小
    ret = aclnnAddCustomGetWorkspaceSize(selfX, selfY, out, &workspaceSize, &executor);
    CHECK_RET(ret == ACL_SUCCESS, LOG_PRINT("aclnnAddCustomGetWorkspaceSize failed. ERROR: %d\n", ret); return ret);

    // 申请工作空间
    void* workspaceAddr = nullptr;
    if (workspaceSize > static_cast<uint64_t>(0)) {
        ret = aclrtMalloc(&workspaceAddr, workspaceSize, ACL_MEM_MALLOC_HUGE_FIRST);
        CHECK_RET(ret == ACL_SUCCESS, LOG_PRINT("allocate workspace failed. ERROR: %d\n", ret); return ret);
    }

    // 执行算子
    ret = aclnnAddCustom(workspaceAddr, workspaceSize, executor, stream);
    CHECK_RET(ret == ACL_SUCCESS, LOG_PRINT("aclnnAddCustom failed. ERROR: %d\n", ret); return ret);

    // 4. 同步流
    ret = aclrtSynchronizeStream(stream);
    CHECK_RET(ret == ACL_SUCCESS, LOG_PRINT("aclrtSynchronizeStream failed. ERROR: %d\n", ret); return ret);

    // 5. 打印结果
    PrintOutResult(outShape, &outDeviceAddr, selfXHostData, selfYHostData);

    // 6. 释放资源
    aclDestroyTensor(selfX);
    aclDestroyTensor(selfY);
    aclDestroyTensor(out);

    aclrtFree(selfXDeviceAddr);
    aclrtFree(selfYDeviceAddr);
    aclrtFree(outDeviceAddr);
    if (workspaceSize > static_cast<uint64_t>(0)) {
        aclrtFree(workspaceAddr);
    }
    aclrtDestroyStream(stream);
    aclrtResetDevice(deviceId);
    aclFinalize();

    return 0;
}
```

## 测试工程搭建

测试工程需要创建CMakeLists.txt文件，配置编译选项、头文件路径和库依赖：

### CMakeLists.txt

```cmake
# CMake最低版本要求
cmake_minimum_required(VERSION 3.14)

# 设置工程名
project(ACLNN_ADD_CUSTOM_EXAMPLE)

# 编译选项
add_compile_options(-std=c++11)

# 设置编译选项
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY  "./bin")
set(CMAKE_CXX_FLAGS_DEBUG "-fPIC -O0 -g -Wall")
set(CMAKE_CXX_FLAGS_RELEASE "-fPIC -O2 -Wall")

# 设置可执行文件名
add_executable(opapi_test_add_custom test_aclnn_add_custom.cpp)

# 设置ASCEND_PATH和头文件目录
if(NOT "$ENV{ASCEND_HOME_PATH}" STREQUAL "")      
    set(ASCEND_PATH $ENV{ASCEND_HOME_PATH})
else()
    message(FATAL_ERROR "请先完成前置步骤：设置CANN环境，确保ASCEND_HOME_PATH已设置")
endif()
set(INCLUDE_BASE_DIR "${ASCEND_PATH}/include")

# 配置头文件路径
include_directories(
    ${INCLUDE_BASE_DIR}
    ${INCLUDE_BASE_DIR}/aclnn
    ${INCLUDE_BASE_DIR}/aclnnop
    # custom包安装后的头文件路径
    ${ASCEND_PATH}/opp/vendors/customize/op_api/include 
)

# 设置链接的库文件路径
target_link_libraries(opapi_test_add_custom PRIVATE
                      ${ASCEND_PATH}/lib64/libascendcl.so
                      ${ASCEND_PATH}/lib64/libnnopbase.so
                      # custom包使用libcust_opapi.so（安装后的路径）
                      ${ASCEND_PATH}/opp/vendors/customize/op_api/lib/libcust_opapi.so 
                      )

# 安装配置
install(TARGETS opapi_test_add_custom DESTINATION ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})
```

## 测试程序编译

使用以下命令编译测试程序：

```bash
# 进入测试目录
cd test

# 创建构建目录
mkdir -p build
cd build

# 配置CMake
cmake ../ -DCMAKE_CXX_COMPILER=g++ -DCMAKE_SKIP_RPATH=TRUE

# 编译测试程序
make
```

编译成功后，会在`bin`目录下生成可执行文件`opapi_test_add_custom`。

## 测试程序执行与验证

执行测试程序需要设置正确的环境变量：

```bash
# 确保ASCEND_HOME_PATH环境变量已经设置
if [ -z "$ASCEND_HOME_PATH" ]; then
    echo "错误：ASCEND_HOME_PATH环境变量未设置"
    echo "请先完成前置步骤：设置CANN环境"
    exit 1
fi

# 设置LD_LIBRARY_PATH，指向算子库文件目录
export LD_LIBRARY_PATH=$ASCEND_HOME_PATH/opp/vendors/customize/op_api/lib/:${LD_LIBRARY_PATH}

# 使用skill提供的自动选择健康设备脚本执行测试
# 该脚本会自动检测健康的NPU设备，并处理"get platform info failed, drvErr=4"等错误

# 执行测试程序，自动选择健康设备
$SKILL_DIR/scripts/run_with_healthy_device.sh ./bin/opapi_test_add_custom
```

程序执行后，会输出算子的计算结果，例如：

```
add_custom first input[0] is: 1.000000, second input[0] is: 1.000000, result[0] is: 2.000000
add_custom first input[1] is: 1.000000, second input[1] is: 1.000000, result[1] is: 2.000000
...
```

## 常见测试问题与解决方案

1. **问题**：编译时找不到`aclnn_add_custom.h`头文件
   **解决方案**：检查头文件路径配置，确保包含算子安装后的头文件目录

2. **问题**：运行时找不到`libcust_opapi.so`库文件
   **解决方案**：设置正确的LD_LIBRARY_PATH环境变量，指向算子库文件目录

3. **问题**：算子执行结果不符合预期
   **解决方案**：检查kernel侧的计算逻辑实现，确保使用了正确的AscendC API和数据处理方式

4. **问题**：设备初始化失败
   **解决方案**：检查NPU设备状态和权限，确保设备可用

5. **问题**：内存分配失败
   **解决方案**：检查数据大小和设备内存限制，调整输入数据的规模
