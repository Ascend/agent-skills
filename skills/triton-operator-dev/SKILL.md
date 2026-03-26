---
name: triton-operator-dev
description: 昇腾Triton 算子全流程开发任务编排。当用户需要开发 Triton 算子时使用，覆盖环境配置→需求设计→代码生成→文档生成→性能优化完整流程。
---

# Triton 算子全流程开发

## 任务编排

| 阶段 | Skill | 产出 |
|------|-------|------|
| 1 | [triton-operator-env-config](triton-operator-env-config/SKILL.md) | 可用的开发环境 |
| 2 | [triton-operator-design](triton-operator-design/SKILL.md) | 算子需求文档 |
| 3 | [triton-operator-code-gen](triton-operator-code-gen/SKILL.md) | 可执行代码 |
| 4 | [triton-operator-doc-gen](triton-operator-doc-gen/SKILL.md) | 接口文档 |
| 5 | [triton-operator-performance-optim](triton-operator-performance-optim/SKILL.md) | 优化后代码 |

## 子 Skill 概览

### 1. triton-operator-env-config
- **触发**: 首次开发或环境异常
- **核心**: 依次检查 CANN → Python → torch → triton-ascend
- **验证**: 运行 `01-vector-add.py`

### 2. triton-operator-design
- **触发**: 需要设计新算子
- **核心**: 需求分析 → 原型设计 → 规格约束 → 特性实现
- **关键**: 必须包含 Tiling 策略具体计算方法

### 3. triton-operator-code-gen
- **触发**: 已有需求文档，需要生成代码
- **流程**: 确认计算逻辑 → 设计 Tiling → 生成 Kernel → 生成测试
- **依赖**: 必须先阅读 `references/hardware-architecture.md` 和 `references/templates.md`

### 4. triton-operator-doc-gen
- **触发**: 需要生成接口文档
- **产出**: 标准化的昇腾 NPU 接口文档（产品支持表、参数说明、调用示例）

### 5. triton-operator-performance-optim
- **触发**: 性能不达标
- **流程**: 性能诊断 → 基础调优 → 硬件特化 → 高级优化
- **关键**: 必须先用 Profiler 定位瓶颈

## 快速决策

| 场景 | 跳过阶段 |
|------|----------|
| 环境已配置 | 1 |
| 已有设计文档 | 2 |
| 只需文档 | 1,2,3,5 |
| 只需代码 | 1,2,4,5 |
| 只需优化 | 1,2,3,4 |

## 通用反模式

- ❌ 忽略 UB 大小（192KB）
- ❌ 归约操作不使用 FP32
- ❌ BLOCK 非 16 倍数（Cube 单元）
- ❌ 忘记 Mask（Ascend 零容错）
- ❌ 混淆 Vector Core 和 Cube Core 用途
