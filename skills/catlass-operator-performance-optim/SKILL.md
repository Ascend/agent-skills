---
name: catlass-operator-performance-optim
description: 指导 Catlass 算子性能调优。流程：阅读 catlass 优化指南、复用精度验证中的性能数据、按指南修改 tiling、迭代对比。调优策略以 catlass 文档为准。条件不明则追问。
---

# Catlass 算子性能调优

## 核心工作流

```
阅读优化指南 → 获取基准数据 → 修改 Tiling 配置 → 重新编译运行 → 对比迭代 → 确定最佳配置
```

---

## 前置条件

| 检查项 | 说明 |
|--------|------|
| 工程目录 | 存在 **OPS_PROJECT_ROOT**，且其下已有 `catlass/docs/1_Practice/10_matmul_optimization.md` |
| 算子状态 | 算子已可编译、可运行 |
| 性能数据 | 已有 **ascendc-operator-precision-eval** 产出的性能数据，或可自行运行算子获取基准数据 |

条件不明时**追问**用户。

---

## 调优原则

- 调优策略**以 catlass 官方优化指南为准**
- 每次修改**仅调整一个变量**，以便准确评估优化效果
- 记录所有尝试的配置和对应的性能数据

---

## NEVER / ALWAYS

**NEVER**：未读 catlass 优化指南就随意改 tiling 参数；一次修改多个变量；忽略硬件资源限制；修改代码后不重新编译

**ALWAYS**：先阅读 catlass 优化指南再动手；每次迭代记录配置与性能数据；性能下降时回滚配置；修改代码后使用 ascendc-operator-compile-debug 重新编译

---

## 步骤

### 1. 阅读优化指南

在 **OPS_PROJECT_ROOT** 下读取：`<OPS_PROJECT_ROOT>/catlass/docs/1_Practice/10_matmul_optimization.md`

理解可调参数：TileShape、DispatchPolicy、Swizzle 等。**请一定要阅读文档，按照其中的建议进行优化尝试，而并非随意修改参数**。

### 2. 获取基准数据

复用 **ascendc-operator-precision-eval** 过程中已有的性能数据作为对比基线。若尚无数据，可自行运行算子采集基准性能指标。

### 3. 修改 Tiling 配置

根据优化指南中的建议，修改算子的 tiling shape 配置：

| 修改项 | 说明 |
|--------|------|
| TileShape 大小 | 调整 L1/L0 层 TileShape |
| DispatchPolicy | 选取其他的调度策略 |
| Swizzle 策略 | 尝试修改数据搬运 Swizzle |

### 4. 重新编译与采集

修改代码后须重新编译（使用 **ascendc-operator-compile-debug**），再运行算子采集性能数据，与基准对比：

- 性能提升 → 记录配置，继续尝试其他优化建议
- 性能下降 → 回滚配置，尝试其他方案
- 性能稳定 → 在当前配置附近进行微调

### 5. 迭代与确定最佳配置

在合理的迭代次数内，找到性能最优的 tiling 配置。记录最佳配置的详细参数和对应的性能指标。

---

## 质量验证

- [ ] 已阅读 catlass 优化指南，非随意修改
- [ ] 每次迭代仅调整一个变量
- [ ] 所有尝试的配置和性能数据已记录
- [ ] 最佳配置已确定并记录参数与指标

---

## 参考资料

| 文档 | 用途 |
|------|------|
| `<OPS_PROJECT_ROOT>/catlass/docs/1_Practice/10_matmul_optimization.md` | 调优策略以此为准 |
| ascendc-operator-precision-eval | 性能数据来源 |
| ascendc-operator-compile-debug | 修改代码后重新编译使用 |
