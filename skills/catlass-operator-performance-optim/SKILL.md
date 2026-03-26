---
name: catlass-operator-performance-optim
description: 指导 Catlass 算子性能调优。流程：阅读 catlass 优化指南、调用 ascendc 性能 skill 做数据采集、按指南修改 tiling、迭代对比。Use when 用户要对 Catlass 算子做性能调优、优化 tiling、或提升算子性能。调优策略以 catlass 文档为准，不执行 ascendc 自带的调优建议。条件不明则追问。
---

# Catlass 算子性能调优

## 概述

在已有 Catlass 算子的基础上，按 catlass 官方优化指南进行 tiling 与策略调优；性能数据通过 ascendc-operator-performance-optim 的采集能力获取，具体调优动作以 catlass 文档为准并迭代验证。

## 何时使用

- 用户要对 Catlass 算子做性能调优、优化 tiling 或提升算子性能
- 算子已能正确运行，需要系统性优化延迟/吞吐

## 前置条件

- 存在 **OPS_PROJECT_ROOT**，且其下已有 `catlass/docs/contents/advanced/catlass_optimize_guidance.md`
- 算子已可编译、可运行（便于采集基准数据）

## Do（必须）

- **条件不明则追问**：算子路径、目标 SoC、是否已有基准数据等不明时追问用户。
- 在 **OPS_PROJECT_ROOT** 下读取优化指南（路径 `<OPS_PROJECT_ROOT>/catlass/docs/contents/advanced/catlass_optimize_guidance.md`）；调优策略以该文档为准。
- 性能数据采集：**调用 ascendc-operator-performance-optim** 的采集部分获取基准数据，不依赖其自带的调优建议；按本 skill 与 catlass 优化指南修改 tiling 并迭代。

## Don't（禁止）

- 未读 catlass 优化指南就随意改 tiling 参数。
- 调用 ascendc-operator-performance-optim 时执行其调优建议而忽略 catlass 文档中的特殊调优说明。

## 功能说明

按以下流程进行 Catlass 算子性能调优：

1. 阅读Catlass优化指南文档
2. 运行性能分析工具获取基准数据
3. 根据优化指南修改tiling配置
4. 重新运行性能分析并记录数据
5. 迭代优化直至找到最佳配置

## 使用步骤

### 1. 阅读优化指南

在 **OPS_PROJECT_ROOT** 下读取 Catlass 优化指南（`catlass/docs/contents/advanced/catlass_optimize_guidance.md`）。

### 2. 运行性能分析

**调用 ascendc-operator-performance-optim**，仅执行其中的**性能采集**部分获取基准数据；调优手段以 catlass 优化指南为准。记录性能指标（延迟、吞吐量等）。

### 3. 修改Tiling配置

根据优化指南中的建议，修改算子的tiling shape配置。常见的修改点包括：

- 调整TileShape大小
- 选取其他的DispatchPolicy
- 尝试修改Swizzle策略

请一定要阅读文档，按照其中的建议进行优化尝试，而并非随意修改参数。

### 4. 重新运行性能分析

应用修改后，再次运行性能分析技能：

```bash
ascendc-operator-performance-optim
```

### 5. 比较与迭代

比较前后两次的性能数据，根据结果决定下一步优化方向：

- 如果性能提升明显，继续尝试其他优化建议
- 如果性能下降，回滚配置并尝试其他方案
- 如果性能趋于稳定，考虑在当前配置附近进行微调

### 6. 确定最佳配置

在合理的迭代次数内，找到性能最优的tiling配置。记录下最佳配置的详细参数和对应的性能指标。

## 注意事项

- 确保每次修改仅调整一个变量，以便准确评估优化效果
- 考虑硬件资源限制，避免配置过大导致资源耗尽
- 记录所有尝试的配置和对应的性能数据，以便分析优化趋势
- 如果性能提升不明显，考虑参考优化指南中的其他建议

## 示例工作流

1. 读取优化指南文档
2. 运行性能分析获取基准数据：延迟=100ms
3. 根据指南修改tiling shape: Tile_X=64 → Tile_X=128
4. 重新运行性能分析：延迟=85ms（提升15%）
5. 继续调整Tile_Y: Tile_Y=32 → Tile_Y=64
6. 重新运行性能分析：延迟=78ms（进一步提升8%）
7. 继续优化直到性能提升不明显
8. 确定最佳配置：Tile_X=128, Tile_Y=64，延迟=78ms

## 参考资料

- **catlass 优化指南**：`<OPS_PROJECT_ROOT>/catlass/docs/contents/advanced/catlass_optimize_guidance.md` — 调优策略以此为准；先阅读再改 tiling。
- **ascendc-operator-performance-optim**：仅使用其性能采集能力获取基准数据，不执行其自带的调优建议。