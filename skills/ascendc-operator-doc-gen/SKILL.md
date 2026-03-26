---
name: ascendc-operator-doc-gen
description: "为AscendC算子生成README.md和aclnn API文档。触发场景：用户提到\"生成算子文档\"、\"创建README\"、\"生成aclnn文档\"、\"文档化算子\"、\"帮我写文档\"（算子上下文）、\"算子文档\"、\"aclnn文档\"，或在算子目录下提到\"文档\"/\"README\"时，务必使用此skill。本skill指导从算子源代码提取信息并生成符合CANN规范的文档。"
---

## 概述

本skill用于从AscendC算子源代码自动生成标准化的技术文档：
- **README.md**: 算子概述文档（保存在算子根目录）
- **aclnn*.md**: aclnn API调用文档（保存在算子根目录/docs/目录）

## 文档生成流程

### 步骤1：确认目标

首先确认用户需要生成哪种文档：
- 仅README.md？
- 仅aclnn文档？
- 两者都需要？

### 步骤2：定位算子源文件

在算子目录中按优先级查找源文件：

| 优先级 | 文件类型 | 路径模式 | 用途 |
|--------|----------|----------|------|
| 1 | aclnn头文件 | `op_host/op_api/aclnn_*.h` | 信息最完整，包含参数注释 |
| 2 | 算子定义文件 | `op_host/*_def.cpp` | 备选，包含参数定义和芯片配置 |
| 3 | 调用示例 | `examples/test_aclnn_*.cpp` | 辅助参考，了解实际调用方式 |

**操作：** 使用Glob工具查找上述文件，确认存在后再进行下一步。

### 步骤3：提取参数信息

#### 优先从aclnn头文件提取

查找函数声明中的Doxygen注释：

```cpp
/**
 * @brief {算子功能描述}
 * @param [in] {参数名}: {参数描述}
 * @param [out] {输出名}: {输出描述}
 * @return aclnnStatus: 返回状态码。
 */
aclnnStatus aclnn{算子名}GetWorkspaceSize(...);
```

提取内容：
- 算子功能描述（@brief）
- 所有参数名、类型（输入/输出）、描述

#### 备选：从_def.cpp文件提取

当没有aclnn头文件时，解析 `op_host/*_def.cpp` 中的参数定义：

```cpp
// 输入参数
this->Input("{参数名}")
    .ParamType(REQUIRED)      // REQUIRED=必需, OPTIONAL=可选
    .DataType({ge::DT_FLOAT, ge::DT_FLOAT16, ge::DT_BF16})
    .Format({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND});

// 输出参数
this->Output("{参数名}")
    .ParamType(REQUIRED)
    .DataType({ge::DT_FLOAT, ge::DT_FLOAT16, ge::DT_BF16})
    .Format({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND});

// 属性
this->Attr("{属性名}").AttrType(OPTIONAL).String("{默认值}");

// 芯片支持
this->AICore().AddConfig("ascend910b");   // <term>Atlas A2 训练系列产品/Atlas A2 推理系列产品</term>
this->AICore().AddConfig("ascend910_93"); // <term>Atlas A3 训练系列产品/Atlas A3 推理系列产品</term>
this->AICore().AddConfig("ascend950");    // <term>Ascend 950PR/Ascend 950DT</term>
this->AICore().AddConfig("kirinx90");     // <term>Kirin X90 处理器系列产品</term>
this->AICore().AddConfig("kirin9030");    // <term>Kirin 9030 处理器系列产品</term>
```

### 步骤4：查阅映射表和模板

**必须阅读以下参考文件：**

1. **映射表** - `references/mapping_tables.md`（数据类型、格式、芯片配置映射）
2. **README模板** - `references/operator_template.md`（生成README.md时）
3. **aclnn模板** - `references/aclnn_template.md`（生成aclnn文档时）

**操作：** 使用Read工具读取对应的参考文件。

### 步骤5：生成文档

#### README.md 结构

1. **产品支持情况表格** - 根据芯片配置映射生成
2. **功能说明** - 算子功能描述 + 计算公式（LaTeX格式）
3. **参数说明表格** - 5列：参数名、输入/输出/属性、描述、数据类型、数据格式
4. **约束说明** - 维度限制、数据类型约束等
5. **调用说明** - aclnn调用链接

#### aclnn文档结构

1. **产品支持情况表格**
2. **功能说明** - 接口功能 + 计算公式
3. **函数原型** - GetWorkspaceSize和执行函数的C++声明
4. **GetWorkspaceSize参数说明** - 8列详细参数表
5. **返回值和错误码表格**
6. **执行函数参数说明** - 3列参数表（workspace/workspaceSize/executor/stream）
7. **约束说明** - 确定性计算、维度限制等
8. **调用示例** - 完整的C++示例代码

### 步骤6：验证完整性

生成文档后，逐项检查：

- [ ] 所有输入/输出/属性参数都已记录
- [ ] 数据类型使用了文档格式（FLOAT16而非ACL_FLOAT16）
- [ ] 芯片支持配置正确映射
- [ ] 所有产品名称使用了`<term>`标签格式
- [ ] 计算公式已填写（需根据算子数学定义）
- [ ] 约束条件已补充（需根据实现）

---

## 边界情况处理

### 多个aclnn函数

当一个算子有多个aclnn接口时（如aclnnAdd和aclnnInplaceAdd）：
- 生成**单个README.md**，包含所有参数的并集
- 为**每个aclnn函数生成单独的aclnn*.md**文档
- 在README的调用说明中列出所有aclnn调用方式

### 可选参数命名

可选参数在函数签名中通常带有`Optional`后缀：
- `realShiftOptional` → 描述中标注"可选输入"
- `dropMaskOptional` → 描述中标注"可选输入"

### workspaceSize和executor参数

这两个参数是GetWorkspaceSize函数的输出，固定格式：
- workspaceSize：输出，返回需要在Device侧申请的workspace大小
- executor：输出，返回op执行器，包含了算子计算流程

---

## 示例参考

在生成文档前，建议阅读对应复杂度的示例：

| 算子类型 | README示例 | aclnn示例 |
|----------|------------|-----------|
| 简单算子 | examples/README_Add&InplaceAdd.md | examples/aclnnAdd&aclnnInplaceAdd.md |
| 归一化算子 | examples/README_RmsNorm.md | examples/aclnnRmsNorm.md |
| 矩阵乘法 | examples/README_Matmul.md | examples/aclnnMatmul.md |
| 复杂注意力 | examples/README_FlashAttentionScore.md | examples/aclnnFlashAttentionScore.md |

---

## 注意事项

1. **计算公式**：需要根据算子数学定义手动编写，无法从代码自动提取
2. **约束条件**：需要阅读算子实现代码补充，如维度限制、数据类型约束等
3. **产品名称格式**：**文档中的任何地方都必须使用产品的完整名称，不允许简写**
   - 示例：`<term>Atlas A2 训练系列产品/Atlas A2 推理系列产品</term>`，不能简写为 `Atlas A2/A3`
4. **数据类型格式**：生成文档中的数据类型必须是映射后的格式
   - 正确：`FLOAT16`、`INT8`、`BFLOAT16`、`FLOAT8_E4M3FN`
   - 错误：`ACL_FLOAT16`、`ACL_INT8`、`ACL_BF16`
5. **文档保存位置**：
   - README.md → 算子根目录（如 `rms_norm/README.md`）
   - aclnn*.md → 算子根目录/docs/（如 `rms_norm/docs/aclnnRmsNorm.md`）
   - 如果docs目录不存在，需要先创建
