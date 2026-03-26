---
name: "ascendc-operator-design"
description: "帮助设计AscendC算子实现方案和编写设计文档，包括算法设计、API设计以及性能优化策略。TRIGGER when: 用户询问算子设计、实现架构、需要规划新算子实现、要求编写设计文档、讨论Tiling切分策略、或需要AscendC编程指导。关键词：AscendC、算子、Tiling、Kernel、AI Core、昇腾、NPU。"
---

# 算子设计方案助手

本技能协助设计AscendC算子实现方案，输出标准化设计文档，遵循昇腾AI处理器硬件特性和编程模型。

## 何时使用

- 设计新AscendC算子或规划架构
- 咨询算法/API设计指导
- 编写/优化算子设计文档

---

## 编程模型概述

AscendC采用基于AI Core的异构并行编程模型：

**核心硬件**：AI Core（Scalar、Vector、Cube计算单元）、Local Memory（512KB L1, 64KB L0A/L0B, 128KB L0C, 192KB UB）、DMA搬运单元

**核心概念**：核函数（`__aicore__`修饰）、Queue数据传输、异步执行（GM→Local Memory→计算单元→Local Memory→GM）

---

## 输出格式

**必须严格遵循以下结构和约束**：
- 公式一致性：用户输入的公式/代码逻辑不得改写
- 文档总行数≤300行

### 输出文档结构

#### 1. 需求分析

##### 1.1 功能分析
- **算子功能说明**：计算功能、数学定义
- **数学公式**：核心公式
- **变量说明**：表格形式，含变量、类型、含义、约束

#### 2. 原型设计

**【内部检查项-不输出到文档】**：
- 检查aclnnGetWorkspaceSize接口最后2个参数是否为 `uint64_t* workspaceSize, aclOpExecutor** executor`
- 检查aclnn执行接口参数是否为 `void* workspace, uint64_t workspaceSize, aclOpExecutor* executor, aclrtStream stream`

**aclnn接口定义**（严格遵循）：
1. **获取workspace大小**：最后2个参数必须是 `uint64_t* workspaceSize, aclOpExecutor** executor`
2. **执行算子**：参数必须是 `void* workspace, uint64_t workspaceSize, aclOpExecutor* executor, aclrtStream stream`

**数据类型支持**：FLOAT16, BF16, FLOAT

#### 3. 规格约束

**输入Tensor约束**：Shape任意维度（最多8维）、数据类型FLOAT16/BF16/FLOAT、元素总数>0

**输出Tensor约束**：Shape与输入相同、数据类型/格式与输入相同

#### 4. 特性实现方案

##### 4.1 Tiling切分

**【内部检查项-不输出到文档】**：
- 检查是否做了算子类型判断
- 检查是否给出核间切分策略
- 检查UB空间分配是否严格不超192KB
- 检查UB空间分配是否输出且为表格形式
- 检查TilingData结构体是否输出
- 检查单次循环处理量是否取三个缓冲区最小值

**步骤1：算子类型判断**（必须作为第一步）：

| 算子类型 | 典型算子 | 切分特点 |
|---------|---------|---------|
| Elementwise | Add, Mul, GELU, ReLU | 一维切分，按元素总数均分 |
| 归一化类 | LayerNorm, BatchNorm | 按归约轴切分，保留最后维度完整 |
| 池化类 | MaxPool, AvgPool | 按输入空间维度切分，考虑窗口重叠 |
| 归约类 | ReduceSum, ReduceMax | 按归约前维度切分，多核部分归约后合并 |
| 矩阵类 | MatMul, Linear | 按Batch或M/N维度切分 |
| 卷积类 | Conv2D | 按Batch或输出特征图切分 |

**步骤2：核间切分策略**：根据算子类型选择对应的切分方案，给出具体的切分公式和示例

**步骤3：核内循环策略**：

**【强制要求】UB空间分配**（表格形式，总计不超过192KB）：
```
UB总大小: 192KB (Atlas A2/A3)

缓冲区划分：
| 缓冲区名称 | 大小 | 说明 |
|-----------|------|------|
| inputBuf | 64KB | 输入缓冲区 |
| computeBuf | 64KB | 计算缓冲区（按FP32计算） |
| outputBuf | 64KB | 输出缓冲区 |
| 总计 | 192KB | ✓ (不超过192KB) |

单次循环处理量计算：
- 输入缓冲区处理量 = inputBuf大小 / 输入数据类型大小
- 计算缓冲区处理量 = computeBuf大小 / 4（固定按FP32计算）
- 输出缓冲区处理量 = outputBuf大小 / 输出数据类型大小
- 最终单次循环处理量 = min(输入缓冲区处理量, 计算缓冲区处理量, 输出缓冲区处理量)

示例：
- FP32输入: min(64KB/4, 64KB/4, 64KB/4) = 16384 elements
- FP16/BF16输入: min(64KB/2, 64KB/4, 64KB/2) = 16384 elements
```

**硬件约束**：UB缓冲区32字节对齐、归约类单值缓冲区需32B、FP16/BF16升精度到FP32计算

**【强制要求】TilingData结构**：
```cpp
struct XxxTilingData {
    uint32_t totalElements;      // 总元素数
    uint32_t blockDim;           // 核数
    uint32_t elementsPerCore;    // 每核处理元素数
    uint32_t loopNumPerCore;     // 每核循环次数
    uint32_t tailElements;       // 尾部元素数
};
```

**【禁止内容】**：不得包含CopyIn/CopyOut/Compute等Kernel实现函数名、核内处理流程伪代码、数据加载/存储的具体实现描述

##### 4.2 Kernel实现

**核心处理流程伪代码**：
```
Process():
    for loopIdx in range(loopNum):
        CopyIn(loopIdx)      // 数据加载
        Compute(loopIdx)     // 核心计算
        CopyOut(loopIdx)     // 结果存储

Compute(loopIdx):
    input = DeQue(inQueue)
    result = ComputeOp(input)
    EnQue(outQueue, result)
```

**约束**：仅输出伪代码，不得输出完整的AscendC实现代码、完整类定义、辅助函数细节

**【禁止内容】**：不得包含TilingData结构定义、核间切分策略描述、UB空间分配方案、完整的AscendC模板代码实现

---

## 反模式清单

**禁止以下行为**：
1. **输出过长文档**：生成的详设文档总行数≤300行
2. **输出不符合要求的aclnn接口**：严格遵循参数格式和顺序
3. **Kernel实现输出整体架构**：仅输出核心Process函数
4. **改写用户输入的代码段**：公式不得改写用户输入的代码段
5. **Kernel伪代码使用逐元素计算**：必须使用向量化计算
6. **未判断算子类型就输出切分方案**：必须先明确算子类型
7. **章节内容混杂**：Tiling章节不得包含Kernel实现代码
8. **输出优化策略**：详设文档不得包含优化策略章节或内容
9. **UB空间分配超限**：分配的UB空间加和不得超过192KB（Atlas A2/A3芯片）
10. **单次循环处理量计算错误**：计算缓冲区必须按FP32计算，最终处理量必须取三个缓冲区最小值

---

## 参考资料

- [API参考](references/api-reference.md)
- [Kernel实现样例](references/kernel-example.md)
- [Tiling实现样例](references/tiling-examples.md)
