---
name: ascendc-operator-dev
description: "AscendC算子端到端开发编排器。当用户需要开发新算子、实现自定义算子、或完成从需求分析到测试验证的完整流程时使用。关键词：算子开发、operator development、端到端、完整流程、工作流编排。"
---

# AscendC 算子端到端开发编排

**Skill类型**：流程导向型（多阶段工作流，子技能编排）

## 核心原则

1. **设计文档前置**：用户必须提供算子设计文档，包含完整的 Tiling 策略和 Kernel 策略
2. **子技能编排优先**：每个阶段必须调用对应的子 skill，不得自行实现
3. **阶段门控**：每个阶段完成后必须验证检查点，通过后才能进入下一阶段
4. **依赖串行**：kernel 依赖 tiling 数据结构，必须在同一 Sub-Agent 中串行执行
5. **条件执行**：框架适配仅在用户需要时执行

## 工作流概览

```
需求收集 → 工程初始化 → 代码生成 → 编译部署 → 文档生成 → [框架适配] → 精度验证
                                                  ↑
                                            条件执行
```

**前置条件**：用户必须提供算子设计文档（包含 Tiling 策略和 Kernel 策略）

**产出物**：完整的算子实现代码、编译产物、文档、测试验证结果

## 决策树

| 用户请求 | 处理方式 |
|----------|---------|
| "快速开发 X 算子" + 提供设计文档 | 跳过详细解释，直接执行完整流程 |
| "帮我开发新算子" + 无设计文档 | 提示用户需要提供设计文档，或引导使用 ascendc-operator-design skill |
| "继续算子开发" | 恢复模式，询问用户当前阶段，从中断处继续 |

## 反模式清单（NEVER DO THESE）

- ❌ 不要在用户未提供设计文档的情况下开始开发
- ❌ 不要跳过必要的开发阶段
- ❌ 不要忽略编译错误和警告
- ❌ 不要跳过精度验证步骤
- ❌ kernel代码生成必须等待tiling完成，不可并行
- ❌ 不要自己实现算子代码，必须调用对应的子 skill
- ❌ 不要跳过检查点验证，每个阶段必须验证完成后再进入下一阶段

---

## 阶段0：需求收集

**目标**：收集完成算子开发所需的所有信息

### 必须确认的信息

| 信息 | 格式要求 | 必填 | 说明 |
|------|----------|------|------|
| 算子名称 | snake_case | 是 | 如 `rms_norm`, `flash_attn` |
| 设计文档 | markdown | **是** | **必须包含 Tiling 策略和 Kernel 策略** |
| 功能描述 | 文本 | 是 | 算子的计算功能和业务场景 |
| PyTorch适配 | boolean | 否 | 是否需要 PyTorch 框架接入 |
| SoC平台 | string | 是 | 如 `ascend910b`, `ascend910_93` |
| CANN路径 | path | 是 | CANN 安装目录 |
| conda环境 | string | 否 | Python 虚拟环境名称 |

### 设计文档要求（必须提供）

设计文档**必须包含**以下内容：

1. **需求分析**
   - 算子功能说明和数学公式
   - 变量说明表

2. **原型设计**
   - aclnn 接口定义
   - 参数说明表
   - 数据类型支持

3. **规格约束**
   - 输入/输出 Tensor 约束
   - 硬件约束说明

4. **Tiling 切分策略**
   - 核间切分策略
   - 核内循环策略
   - UB 空间计算

5. **Kernel 实现策略**
   - 算子融合架构设计
   - 向量计算实现
   - 数据搬运流程

**如果用户未提供设计文档**：
- 提示用户需要提供设计文档
- 或引导用户使用 `ascendc-operator-design` skill 先完成算子设计

### 验收标准

- [ ] 算子名称已确认（snake_case 格式）
- [ ] **设计文档已提供且内容完整**
- [ ] 功能描述已明确
- [ ] SoC 平台已指定
- [ ] CANN 路径已确认

**只有当所有验收标准满足时**，才能进入阶段1。

---

## 阶段1：工程初始化

**调用 Skill**：`ascendc-operator-project-init`

**前置条件**：
- 阶段0已完成
- 设计文档已提供

### 执行方式

```
MANDATORY: 调用 ascendc-operator-project-init skill，按照该 skill 的流程执行：
1. 检测算子工程位置
2. 初始化工程环境（如需要）
3. 收集算子信息
4. 生成算子工程目录
```

### 检查点

- [ ] build.sh 文件存在
- [ ] ops/<op_name>/ 目录创建完成
- [ ] 目录结构完整（包含 op_host/, op_kernel/, examples/, tests/）

**只有当所有检查点满足时**，才能进入阶段2。

---

## 阶段2：代码生成（Sub-Agent 串行执行）

**工具**：Task (subagent_type: general-purpose)

**前置条件**：
- 阶段1已完成
- 设计文档已提供

### 依赖说明

**重要**：kernel 代码依赖 tiling 生成的数据结构定义，必须在同一 Sub-Agent 中串行执行。

### Sub-Agent 任务描述

```
执行 AscendC 算子代码生成任务：

1. MANDATORY: 调用 ascendc-operator-tiling-code-gen skill
   - 根据设计文档生成 op_host/ 目录下的代码
   - 生成文件：_def.cpp, _infershape.cpp, _tiling.h, _tiling.cpp
   - 验证：4 个文件生成完成

2. MANDATORY: 调用 ascendc-operator-kernel-code-gen skill
   - 根据设计文档生成 op_kernel/ 目录下的代码
   - 生成文件：.h, .cpp
   - 验证：2 个文件生成完成

3. 返回生成结果：列出所有生成的文件路径
```

### 检查点

- [ ] op_host/<op_name>_def.cpp 生成完成
- [ ] op_host/<op_name>_infershape.cpp 生成完成
- [ ] op_host/<op_name>_tiling.h 生成完成
- [ ] op_host/<op_name>_tiling.cpp 生成完成
- [ ] op_kernel/<op_name>.h 生成完成
- [ ] op_kernel/<op_name>.cpp 生成完成

**只有当所有检查点满足时**，才能进入阶段3。

---

## 阶段3：编译部署（Sub-Agent）

**工具**：Task (subagent_type: general-purpose)

**前置条件**：
- 阶段2已完成
- 所有代码文件已生成

### Sub-Agent 任务描述

```
执行 AscendC 算子编译部署任务：

MANDATORY: 调用 ascendc-operator-compile-debug skill，按照该 skill 的流程执行：

1. CANN 环境配置
   - 设置 ASCEND_HOME_PATH
   - 验证环境变量

2. 算子工程检查
   - 验证工程结构完整性

3. 环境检查
   - 检查编译依赖

4. 编译部署
   - 执行编译命令
   - 处理编译错误（最多重试 3 次）
   - 生成 run 包

5. 安装验证
   - 安装 run 包

返回编译结果：编译状态、run 包路径
```

### 检查点

- [ ] 编译成功，无错误
- [ ] run 包已生成（build_out/*.run）
- [ ] run 包已安装

**只有当所有检查点满足时**，才能进入阶段4。

---

## 阶段4：文档生成

**调用 Skill**：`ascendc-operator-doc-gen`

**前置条件**：
- 阶段3已完成
- 算子编译成功

### 执行方式

```
MANDATORY: 调用 ascendc-operator-doc-gen skill，按照该 skill 的流程执行：
1. 定位算子源文件
2. 提取参数信息
3. 查阅映射表和模板
4. 生成 README.md
5. 生成 aclnn 文档
```

### 输出产物

- ops/<op_name>/README.md
- ops/<op_name>/docs/aclnn<OpName>.md

### 检查点

- [ ] README.md 已生成
- [ ] aclnn 文档已生成
- [ ] 文档内容完整（参数说明、约束条件、调用示例）

---

## 阶段5：框架适配（条件执行）

**条件**：用户选择需要 PyTorch 适配

**调用 Skill**：`ascendc-operator-frame-adapter-torch`

**前置条件**：
- 阶段3已完成
- 算子已编译并安装

### 执行方式

```
MANDATORY: 调用 ascendc-operator-frame-adapter-torch skill，按照该 skill 的流程执行：
1. 分析用户需求并规划 torch 接口
2. 检查并初始化模板工程
3. 生成适配代码文件
4. 注册算子接口
5. 更新构建配置
6. 编译验证
7. 生成测试用例
8. 功能测试
9. 精度测试（可选）
```

### 检查点

- [ ] torch 接口已定义
- [ ] 适配代码已生成
- [ ] 编译成功
- [ ] Python 测试通过

---

## 阶段6：精度验证

**调用 Skill**：`ascendc-operator-precision-eval`

**前置条件**：
- 阶段3已完成（或阶段5，如需 PyTorch 适配）

### 执行方式

```
MANDATORY: 调用 ascendc-operator-precision-eval skill，按照该 skill 的流程执行：
1. 准备测试数据
2. 生成 CPU 参考数据
3. 执行单标杆/双标杆验证
4. 分析误差指标
5. 生成精度报告
```

### 检查点

- [ ] 精度测试已执行
- [ ] 误差指标在阈值范围内
- [ ] 精度报告已生成

---

## 状态跟踪表

| 阶段 | 前置条件 | 调用 Skill | 检查点 |
|------|----------|------------|--------|
| 0. 需求收集 | 无 | - | 设计文档+5项信息已确认 |
| 1. 工程初始化 | 阶段0完成 | ascendc-operator-project-init | build.sh存在，ops/<op_name>/创建 |
| 2. 代码生成 | 阶段1完成 | Sub-Agent (tiling + kernel) | 6个文件生成完成 |
| 3. 编译部署 | 阶段2完成 | Sub-Agent (compile-debug) | 编译通过，run包安装 |
| 4. 文档生成 | 阶段3完成 | ascendc-operator-doc-gen | README.md + aclnn文档 |
| 5. 框架适配 | 阶段3完成（条件） | ascendc-operator-frame-adapter-torch | torch绑定 + Python测试 |
| 6. 精度验证 | 阶段3/5完成 | ascendc-operator-precision-eval | 误差指标达标 |

---

## 错误恢复

### 从中断点恢复

当用户说"继续算子开发"时：

1. 检查 ops/<op_name>/ 目录状态
2. 根据已完成的文件判断当前阶段
3. 询问用户确认当前阶段
4. 从该阶段继续执行

### 阶段判断依据

| 已存在文件 | 当前阶段 |
|------------|----------|
| 无 ops/<op_name>/ | 从阶段1开始 |
| ops/<op_name>/ 存在，无 op_host/*.cpp | 从阶段2开始 |
| 代码文件存在，无 build_out/*.run | 从阶段3开始 |
| run包存在，无 README.md | 从阶段4开始 |

---

## 注意事项

1. **设计文档必须提供**：用户必须提供包含 Tiling 策略和 Kernel 策略的设计文档
2. **代码生成依赖**：kernel 依赖 tiling 数据结构，必须在同一 Sub-Agent 串行执行
3. **条件执行**：框架适配仅在用户需要 PyTorch 适配时执行
4. **阶段门控**：每个阶段必须验证检查点后才能进入下一阶段
5. **所有算子统一生成在 ops 目录下**
