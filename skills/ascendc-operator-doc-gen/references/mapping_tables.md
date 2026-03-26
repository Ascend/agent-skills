# 映射参考表

本文档包含从AscendC源代码到文档格式的所有映射关系。

## 数据类型映射

### 基本数值类型

| C++ 类型 | 文档格式 | 说明 |
|----------|----------|------|
| `ge::DT_FLOAT` | FLOAT / FLOAT32 | 32位浮点数 |
| `ge::DT_DOUBLE` | FLOAT64 | 64位浮点数 |
| `ge::DT_FLOAT16` | FLOAT16 | 16位浮点数 |
| `ge::DT_BF16` | BFLOAT16 | 16位脑浮点数 |

### 整数类型

| C++ 类型 | 文档格式 | 说明 |
|----------|----------|------|
| `ge::DT_INT8` | INT8 | 8位有符号整数 |
| `ge::DT_INT16` | INT16 | 16位有符号整数 |
| `ge::DT_INT32` | INT32 | 32位有符号整数 |
| `ge::DT_INT64` | INT64 | 64位有符号整数 |
| `ge::DT_UINT8` | UINT8 | 8位无符号整数 |
| `ge::DT_UINT16` | UINT16 | 16位无符号整数 |
| `ge::DT_UINT32` | UINT32 | 32位无符号整数 |
| `ge::DT_UINT64` | UINT64 | 64位无符号整数 |

### FLOAT8系列（特殊浮点类型）

| C++ 类型 | 文档格式 | 说明 |
|----------|----------|------|
| `ge::DT_HIFLOAT8` | HIFLOAT8 | 高精度浮点8位 |
| `ge::DT_FLOAT8_E5M2` | FLOAT8_E5M2 | 5位指数2位尾数浮点8位 |
| `ge::DT_FLOAT8_E4M3FN` | FLOAT8_E4M3FN | 4位指数3位尾数浮点8位 |
| `ge::DT_FLOAT8_E8M0` | FLOAT8_E8M0 | 8位指数0位尾数浮点8位 |

### 量化类型

| C++ 类型 | 文档格式 | 说明 |
|----------|----------|------|
| `ge::DT_INT4` | INT4 | 4位整数（特定条件支持） |
| `ge::DT_QINT8` | QINT8 | 8位量化整数 |
| `ge::DT_QUINT8` | QUINT8 | 8位无符号量化整数 |
| `ge::DT_QINT16` | QINT16 | 16位量化整数 |
| `ge::DT_QUINT16` | QUINT16 | 16位无符号量化整数 |
| `ge::DT_QINT32` | QINT32 | 32位量化整数 |

### 其他类型

| C++ 类型 | 文档格式 | 说明 |
|----------|----------|------|
| `ge::DT_BOOL` | BOOL | 布尔类型 |
| `ge::DT_STRING` | STRING | 字符串类型 |
| `ge::DT_COMPLEX64` | COMPLEX64 | 64位复数 |
| `ge::DT_COMPLEX128` | COMPLEX128 | 128位复数 |
| `char*` | STRING | 字符串（属性） |

## 格式映射

| C++ 格式 | 文档格式 | 说明 |
|----------|----------|------|
| `ge::FORMAT_ND` | ND | N维通用格式（最常用） |
| `ge::FORMAT_NCHW` | NCHW | 批量×通道×高度×宽度 |
| `ge::FORMAT_NHWC` | NHWC | 批量×高度×宽度×通道 |
| `ge::FORMAT_NCDHW` | NCDHW | 批量×通道×深度×高度×宽度（3D操作） |
| `ge::FORMAT_NZ` | NZ / FRACTAL_NZ | Ascend专用分形格式 |
| `ge::FORMAT_NC1HWC0` | NC1HWC0 | Ascend专用格式 |
| `ge::FORMAT_FRACTAL_NZ` | FRACTAL_NZ | Ascend专用分形格式 |
| `ge::FORMAT_HWC4` | HWC4 | HWC4格式 |

## 参数类型映射

| 代码 | 文档标签 | 说明 |
|------|----------|------|
| `Input()` + `REQUIRED` | 输入 | 必需输入参数 |
| `Input()` + `OPTIONAL` | 可选输入 | 可选输入参数 |
| `Output()` | 输出 | 输出参数 |
| `Attr()` + `REQUIRED` | 属性 | 必需属性 |
| `Attr()` + `OPTIONAL` | 可选属性 | 可选属性 |

## 芯片配置映射

| 代码配置 | 产品名称 |
|----------|----------|
| `ascend910b` | <term>Atlas A2 训练系列产品/Atlas A2 推理系列产品</term> |
| `ascend910_93` | <term>Atlas A3 训练系列产品/Atlas A3 推理系列产品</term> |
| `ascend950` | <term>Ascend 950PR/Ascend 950DT</term> |
| `ascend310p` | <term>Atlas 推理系列产品</term> |
| `ascend910` | <term>Atlas 训练系列产品</term> |
| `kirinx90` | <term>Kirin X90 处理器系列产品</term> |
| `kirin9030` | <term>Kirin 9030 处理器系列产品</term> |

## 舍入模式映射

| RoundMode | 说明 |
|-----------|------|
| `CAST_NONE` | 无转换/直接传递 |
| `CAST_RINT` | 向最近的整数舍入（四舍六入五成双） |
| `CAST_ROUND` | 四舍五入 |
| `CAST_FLOOR` | 向下取整 |
| `CAST_CEIL` | 向上取整 |
| `CAST_TRUNC` | 截断 |

## 产品支持表格模板

### README.md 产品支持表格

```markdown
| 产品                                                         | 是否支持 |
| :----------------------------------------------------------- | :------: |
| <term>Atlas A3 训练系列产品/Atlas A3 推理系列产品</term>     |    √     |
| <term>Atlas A2 训练系列产品/Atlas A2 推理系列产品</term> |    √     |
| <term>Kirin X90 处理器系列产品</term> | √ |
| <term>Kirin 9030 处理器系列产品</term> | √ |
```

### aclnn文档产品支持表格

```markdown
| 产品                                                         | 是否支持 |
| :----------------------------------------------------------- | :------: |
| <term>Ascend 950PR/Ascend 950DT</term>                 |    √     |
| <term>Atlas A3 训练系列产品/Atlas A3 推理系列产品</term> |    √     |
| <term>Atlas A2 训练系列产品/Atlas A2 推理系列产品</term> |    √     |
| <term>Atlas 200I/500 A2 推理产品</term> |      ×     |
| <term>Atlas 推理系列产品</term> |      ×     |
| <term>Atlas 训练系列产品</term> |      ×     |
```
