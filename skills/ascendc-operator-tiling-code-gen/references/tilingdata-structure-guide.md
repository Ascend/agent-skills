# TilingData结构定义详细指南

## 核心概念

TilingData结构用于在Host侧和Kernel侧之间传递切分参数。它通过继承TilingDef基类提供序列化和反序列化能力。

## 结构定义语法

### 基础定义

```cpp
#include "register/tilingdata_base.h"

namespace optiling {

BEGIN_TILING_DATA_DEF(YourOpTilingData)
    // 字段定义
END_TILING_DATA_DEF;

REGISTER_TILING_DATA_CLASS(YourOp, YourOpTilingData)

} // namespace optiling
```

### 字段类型宏

| 宏名称 | 用途 | 语法 |
|-------|------|------|
| `TILING_DATA_FIELD_DEF` | 定义普通字段 | `TILING_DATA_FIELD_DEF(type, name)` |
| `TILING_DATA_FIELD_DEF_ARR` | 定义数组字段 | `TILING_DATA_FIELD_DEF_ARR(type, size, name)` |
| `TILING_DATA_FIELD_DEF_STRUCT` | 定义嵌套结构体 | `TILING_DATA_FIELD_DEF_STRUCT(struct_type, name)` |

## 支持的数据类型

### 基础类型

```cpp
// 支持的类型
int8_t, uint8_t
int16_t, uint16_t
int32_t, uint32_t
int64_t, uint64_t
float
```

### 类型选择建议

| 使用场景 | 推荐类型 | 理由 |
|---------|---------|------|
| 元素数量、维度大小 | `int64_t` | 支持大张量 |
| 核心数、计数 | `uint32_t` | 非负、范围合适 |
| 字节大小 | `uint64_t` | 支持大内存 |
| 超参数、阈值 | `float` | 小数值 |
| 数组索引 | `int32_t` | 节省空间 |

## 字段排列与对齐

### 对齐规则

```
当前成员偏移量 offset 必须满足：
offset % sizeof(member) == 0
```

### 推荐排列顺序

```cpp
BEGIN_TILING_DATA_DEF(ExampleTilingData)
    // 1. 8字节类型优先
    TILING_DATA_FIELD_DEF(int64_t, totalElements);
    TILING_DATA_FIELD_DEF(uint64_t, tmpBufSize);
    
    // 2. 4字节类型
    TILING_DATA_FIELD_DEF(int32_t, perCoreNum);
    TILING_DATA_FIELD_DEF(uint32_t, needCoreNum);
    TILING_DATA_FIELD_DEF(float, epsilon);
    
    // 3. 数组字段（通常为int32_t）
    TILING_DATA_FIELD_DEF_ARR(int32_t, 50, startIdx);
    TILING_DATA_FIELD_DEF_ARR(int32_t, 50, endIdx);
    
    // 4. 2字节类型（如有）
    TILING_DATA_FIELD_DEF(int16_t, flag);
    
    // 5. 1字节类型（如有）
    TILING_DATA_FIELD_DEF(uint8_t, dataType);
END_TILING_DATA_DEF;
```

## 数组字段使用

### 定义数组

```cpp
// 在头文件中定义常量
constexpr uint16_t MAX_CORE_CONT = 50;

BEGIN_TILING_DATA_DEF(OpTilingData)
    TILING_DATA_FIELD_DEF_ARR(int32_t, MAX_CORE_CONT, batchStart);
    TILING_DATA_FIELD_DEF_ARR(int32_t, MAX_CORE_CONT, batchEnd);
END_TILING_DATA_DEF;
```

### 设置数组值

```cpp
// 在tiling.cpp中
int32_t batchStart[MAX_CORE_CONT] = {0};
int32_t batchEnd[MAX_CORE_CONT] = {0};

// 填充数组
for (int i = 0; i < needCoreNum; i++) {
    batchStart[i] = i * perCore;
    batchEnd[i] = std::min((i + 1) * perCore, total);
}

// 设置到TilingData
tilingData.set_batchStart(batchStart);
tilingData.set_batchEnd(batchEnd);
```

**注意**: `set_xxx`仅复制数组指针指向的数据，长度由宏定义中的size决定。确保传入数组长度不小于定义的size。

## 嵌套结构体

### 定义嵌套结构

```cpp
// 先定义子结构体
BEGIN_TILING_DATA_DEF(SubStruct)
    TILING_DATA_FIELD_DEF(int32_t, value1);
    TILING_DATA_FIELD_DEF(int32_t, value2);
END_TILING_DATA_DEF;
// 注册中间结构体：第一个参数为 struct_name#Op
REGISTER_TILING_DATA_CLASS(SubStructOp, SubStruct)

// 再定义主结构体
BEGIN_TILING_DATA_DEF(MainTilingData)
    TILING_DATA_FIELD_DEF(int64_t, totalSize);
    TILING_DATA_FIELD_DEF_STRUCT(SubStruct, subData);
END_TILING_DATA_DEF;
REGISTER_TILING_DATA_CLASS(MainOp, MainTilingData)
```

### 访问嵌套字段

```cpp
// 设置值
tilingData.subData.set_value1(100);
tilingData.subData.set_value2(200);

// 获取值
int32_t v1 = tilingData.subData.get_value1();
```

## CompileInfo结构

### 定义

```cpp
struct OpCompileInfo {
    uint32_t coreNum = 0;    // 平台核心数
    uint64_t ubSize = 0;     // 平台UB大小
};
```

### 获取平台信息

```cpp
static ge::graphStatus TilingPrepare(gert::TilingParseContext* context)
{
    auto compileInfo = context->GetCompiledInfo<OpCompileInfo>();
    OP_CHECK_NULL_WITH_CONTEXT(context, compileInfo);
    
    auto platformInfo = context->GetPlatformInfo();
    auto ascendcPlatform = platform_ascendc::PlatformAscendC(platformInfo);
    
    uint64_t ubSize;
    ascendcPlatform.GetCoreMemSize(platform_ascendc::CoreMemType::UB, ubSize);
    
    compileInfo->coreNum = ascendcPlatform.GetCoreNumAiv();
    compileInfo->ubSize = ubSize;
    
    // 验证硬件信息有效性
    OP_CHECK_IF(compileInfo->coreNum <= 0,
                OP_LOGE(context->GetNodeName(), "Invalid coreNum: %u", compileInfo->coreNum),
                return ge::GRAPH_FAILED);
    
    return ge::GRAPH_SUCCESS;
}
```

## 常见TilingData字段模板

### 归约类算子

```cpp
BEGIN_TILING_DATA_DEF(ReduceOpTilingData)
    TILING_DATA_FIELD_DEF(int64_t, dataType);
    TILING_DATA_FIELD_DEF(int64_t, needCoreNum);
    TILING_DATA_FIELD_DEF(int64_t, totalElements);
    TILING_DATA_FIELD_DEF(int64_t, reduceDimSize);
    TILING_DATA_FIELD_DEF(int64_t, perCoreElements);
    TILING_DATA_FIELD_DEF(int64_t, tmpBufSize);
    
    TILING_DATA_FIELD_DEF_ARR(int32_t, MAX_CORE_CONT, coreStart);
    TILING_DATA_FIELD_DEF_ARR(int32_t, MAX_CORE_CONT, coreEnd);
END_TILING_DATA_DEF;
```

### 归一化类算子

```cpp
BEGIN_TILING_DATA_DEF(NormOpTilingData)
    TILING_DATA_FIELD_DEF(int64_t, dataType);
    TILING_DATA_FIELD_DEF(int64_t, needCoreNum);
    TILING_DATA_FIELD_DEF(int64_t, batches);
    TILING_DATA_FIELD_DEF(int64_t, normDimSize);
    TILING_DATA_FIELD_DEF(int64_t, batchPerCore);
    TILING_DATA_FIELD_DEF(int64_t, tmpBufSize);
    TILING_DATA_FIELD_DEF(float, epsilon);
    
    TILING_DATA_FIELD_DEF_ARR(int32_t, MAX_CORE_CONT, batchStart);
    TILING_DATA_FIELD_DEF_ARR(int32_t, MAX_CORE_CONT, batchEnd);
END_TILING_DATA_DEF;
```

### 逐元素算子

```cpp
BEGIN_TILING_DATA_DEF(ElementwiseOpTilingData)
    TILING_DATA_FIELD_DEF(int64_t, dataType);
    TILING_DATA_FIELD_DEF(int64_t, needCoreNum);
    TILING_DATA_FIELD_DEF(int64_t, totalLength);
    TILING_DATA_FIELD_DEF(int64_t, tileLength);
    TILING_DATA_FIELD_DEF(int64_t, tileNum);
    
    TILING_DATA_FIELD_DEF_ARR(int32_t, MAX_CORE_CONT, coreOffset);
END_TILING_DATA_DEF;
```

## 序列化与保存

```cpp
void FillTilingData()
{
    // 设置所有字段值
    tilingData.set_dataType(dataTypeVal);
    tilingData.set_needCoreNum(needCoreNum);
    // ... 其他字段
    
    // 保存到context
    tilingData.SaveToBuffer(
        tilingContext->GetRawTilingData()->GetData(),
        tilingContext->GetRawTilingData()->GetCapacity()
    );
    tilingContext->GetRawTilingData()->SetDataSize(tilingData.GetDataSize());
    
    // 设置block维度和tiling key
    tilingContext->SetBlockDim(needCoreNum);
    tilingContext->SetTilingKey(tilingKey);
}
```

## 常见错误

### 错误1: 数组越界

```cpp
// 错误：数组长度小于定义的size
int32_t smallArray[10] = {0};
tilingData.set_batchStart(smallArray);  // 危险！会读取越界数据

// 正确：确保数组长度足够
int32_t correctArray[MAX_CORE_CONT] = {0};
tilingData.set_batchStart(correctArray);
```

### 错误2: 类型不匹配

```cpp
// 错误：使用不支持的结构体类型
struct MyStruct { int x; };
TILING_DATA_FIELD_DEF_STRUCT(MyStruct, data);  // 编译错误

// 正确：使用BEGIN_TILING_DATA_DEF定义的结构体
BEGIN_TILING_DATA_DEF(MyStruct)
    TILING_DATA_FIELD_DEF(int32_t, x);
END_TILING_DATA_DEF;
REGISTER_TILING_DATA_CLASS(MyStructOp, MyStruct)
```

### 错误3: 对齐问题

```cpp
// 可能有问题：字段排列导致对齐失败
BEGIN_TILING_DATA_DEF(BadAlignment)
    TILING_DATA_FIELD_DEF(int8_t, flag);      // 1字节
    TILING_DATA_FIELD_DEF(int64_t, value);    // 8字节，可能未对齐
END_TILING_DATA_DEF;

// 正确：按大小降序排列
BEGIN_TILING_DATA_DEF(GoodAlignment)
    TILING_DATA_FIELD_DEF(int64_t, value);    // 8字节优先
    TILING_DATA_FIELD_DEF(int8_t, flag);      // 1字节最后
END_TILING_DATA_DEF;
```
