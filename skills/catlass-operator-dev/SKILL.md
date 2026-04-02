---
name: catlass-operator-dev
description: Catlass 算子端到端开发编排器
---

# Catlass 算子端到端开发编排

## 核心工作流

```
需求收集 → 工程初始化 → Catlass 准备 → 算子设计 → 代码生成 → 编译调试 → 精度验证 → 性能优化（可选）
```

## 核心原则

1. **端到端连续执行**：Agent **必须亲自**完成可执行步骤，**禁止**用「建议您执行…」替代
2. **按 Skill 执行**：每个阶段须**打开并遵循对应子 Skill**
3. **算子命名**：`op_name`（snake_case）**必须**包含子串 `catlass`
4. **诚实停机**：因环境或数据无法继续时，说明**具体原因**与**已完成步骤**后停止
5. **优先级**：开发 Catlass 算子时，**优先使用 catlass-*** skill，而非通用 ascendc-*** skill

## 工程目录术语

| 术语 | 含义 |
|------|------|
| **OPS_PROJECT_ROOT** | 含 `build.sh`、`ops/` 的工程根；catlass 默认位于 `<OPS_PROJECT_ROOT>/catlass/` |
| **USER_OP_PROJECT** | 单算子目录 `<OPS_PROJECT_ROOT>/ops/<算子名>/` |

---

## 步骤编排

### 步骤 0：收集需求

本编排器直接执行，不调用子 skill。

确认：算子名称、功能要点、使用的 CANN 环境

### 步骤 1：工程初始化

**子技能**：`ascendc-operator-project-init`

**产出**：`OPS_PROJECT_ROOT`

### 步骤 2：准备 Catlass 源码

**前置**：步骤 1 完成

1. 若尚无 `catlass/include`、`catlass/examples`，执行  
   `git clone https://gitcode.com/cann/catlass.git catlass`  
   **仅**在工程根执行，**禁止**在 `USER_OP_PROJECT` 内克隆

**产出**：`<OPS_PROJECT_ROOT>/catlass/` 可浏览

### 步骤 3：算子设计

**子技能**：`catlass-operator-design`

**前置**：步骤 2 完成

**产出**：设计文档已定稿（路径明确）

### 步骤 4：代码生成

**子技能**：`catlass-operator-code-gen`

**前置**：步骤 3 的设计文档

**产出**：USER_OP_PROJECT 内含 op_host、op_kernel、`examples/test_aclnn_<op_name>.cpp`

### 步骤 5：编译调试

**子技能**：`ascendc-operator-compile-debug`

**前置**：步骤 4 的代码已落地

**产出**：编译通过；具备运行条件时执行示例并记录输出

### 步骤 6：文档生成（可选）

**子技能**：`ascendc-operator-doc-gen`

用户可跳过。安排在编译之后、精度之前

### 步骤 7：精度验证

**子技能**：`ascendc-operator-precision-eval`

**前置**：`test_aclnn_<op_name>.cpp` 存在，步骤 5 至少已可编译

**产出**：PASS / FAIL / 阻塞说明

**FAIL 闭环**：分析原因 → 修正设计或代码 → 回到步骤 5 → 步骤 6 → 步骤 7 复测

### 步骤 8：询问是否性能优化

**须主动向用户提问**，不得默认跳过

- 同意 → 调用 `catlass-operator-performance-optim`，涉及代码变更时回到步骤 5→6→7 迭代
- 拒绝 → 结束主流程

---

## 状态跟踪

| 阶段 | 检查点 |
|------|--------|
| 工程初始化 | `OPS_PROJECT_ROOT` 下存在 `ops/ops-project/`或`ops/<op_name>` |
| Catlass 就绪 | `<OPS_PROJECT_ROOT>/catlass/` 可引用 |
| 设计文档 | 已定稿且路径明确 |
| 代码生成 | USER_OP_PROJECT 含 host/kernel 与 test_aclnn |
| 编译调试 | 编译通过；运行按环境执行 |
| 文档 | 已生成或用户跳过 |
| 精度验证 | PASS / FAIL / 阻塞 |
| 性能调优 | 已询问用户；已执行或已跳过 |

---

## 子技能调用顺序

```
catlass-operator-dev（本编排器）
    │
    ├── 1. ascendc-operator-project-init
    ├── 2. clone catlass
    ├── 3. catlass-operator-design
    ├── 4. catlass-operator-code-gen
    ├── 5. ascendc-operator-compile-debug
    ├── 6. ascendc-operator-doc-gen（可选）
    ├── 7. ascendc-operator-precision-eval
    │         └──（FAIL）回到 4 或 3 → 5 → 6 → 7
    └── 8. catlass-operator-performance-optim（用户同意时）
              └── 代码变更时回到 5 → 6 → 7
```
