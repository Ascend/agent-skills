---
name: model-migration-analysis
description: 自驾模型NPU适配技能。当用户需要将新的自动驾驶模型或VLA世界模型适配到昇腾NPU时触发，提供从模型分析、算子替换、适配方案到优化总结的完整流程。
---

# 自驾模型NPU适配技能

## 概述

本技能用于指导将新的自动驾驶模型（传统感知模型、规控模型、VLA世界模型等）适配到昇腾NPU平台。基于DrivingSDK仓库的丰富适配经验，提供系统化的适配流程。

## 触发场景

- 用户有新的自动驾驶模型需要适配到NPU
- 用户询问如何将某个开源模型迁移到昇腾平台
- 用户需要分析模型的NPU兼容性
- 用户需要优化已适配模型的性能

## 适配流程

### Phase 1: 模型分析

#### 1.1 获取模型基本信息

收集以下信息：
```
1. 模型名称和类型（感知/规控/VLA世界模型）
2. 开源仓库地址（GitHub URL）
3. 训练/推理框架（PyTorch版本、MMLab系列等）
4. 主要依赖库及版本
5. 训练数据集
```

#### 1.2 分析模型结构

- **Backbone分析**：识别主干网络（ResNet、ViT、Llama等）
- **核心模块分析**：识别关键算子（BEV Pool、Deformable Attention、Sparse Conv等）
- **训练流程分析**：定位训练入口脚本（通常为`tools/train.py`）

#### 1.3 识别不兼容算子

通过以下方式识别NPU不支持的算子：

1. **CUDA算子**：搜索代码中的`.cuda()`、`torch.cuda`、自定义CUDA扩展
2. **GPU专用库**：如`torch_scatter`、`bev_pool_v2`等
3. **高维操作**：NPU不支持6维以上的matmul
4. **特殊算子**：如`torch.linalg.slogdet`等走CPU计算的算子

常用检测命令：
```bash
# 搜索CUDA相关代码
grep -r "\.cuda()" --include="*.py" .
grep -r "torch.cuda" --include="*.py" .
grep -r "from torch_scatter" --include="*.py" .
```

### Phase 2: 适配方案设计

#### 2.1 接口替换方案

**transfer_to_npu自动迁移**：
```python
import torch_npu
from torch_npu.contrib import transfer_to_npu
```

**DDP适配**：
```python
# 原始代码
from mmcv.parallel import MMDataParallel, MMDistributedDataParallel
# 替换为
from mmcv.device.npu import NPUDataParallel, NPUDistributedDataParallel
```

#### 2.2 算子替换方案

根据模型类型选择合适的融合算子：

| 模型类型 | 常用替换算子 | 导入方式 |
|---------|-------------|---------|
| BEV感知 | bev_pool_v3, multi_scale_deformable_attn | `from mx_driving import bev_pool_v3, multi_scale_deformable_attn` |
| 检测 | npu_gaussian, boxes_iou_bev, nms3d | `from mx_driving import npu_gaussian, boxes_iou_bev` |
| ResNet骨干 | npu_add_relu, npu_max_pool2d | `from mx_driving import npu_add_relu, npu_max_pool2d` |
| 稀疏卷积 | SparseConv3d, SubMConv3d | `from mx_driving import SparseConv3d, SubMConv3d` |
| 可变形卷积 | deform_conv2d, modulated_deform_conv2d | `from mx_driving import deform_conv2d` |
| VLA/LLM | npu_rms_norm, npu_fusion_attention | `torch_npu.npu_rms_norm`, `torch_npu.npu_fusion_attention` |

**算子替换示例**（BEVFormer的multi_scale_deformable_attn）：
```python
# 原始代码
output = MultiScaleDeformableAttnFunction.apply(
    value, spatial_shapes, level_start_index, sampling_locations,
    attention_weights, self.im2col_step)

# 替换为
import mx_driving
output = mx_driving.multi_scale_deformable_attn(
    value, spatial_shapes, level_start_index, 
    sampling_locations, attention_weights)
```

#### 2.3 优化器替换

```python
# 原始代码
optimizer = dict(type='AdamW', lr=2e-4, weight_decay=1e-07)
# 替换为融合优化器
optimizer = dict(type='NpuFusedAdamW', lr=2e-4, weight_decay=1e-07)
```

### Phase 3: 适配实施

提供两种适配方式，选择其一即可：

#### 方式一：Patch文件方式（推荐用于复杂模型）

**适用场景**：模型修改较多、需要修改三方库、需要精确控制修改点

**步骤**：

1. **克隆模型源码并指定commit**：
```bash
git clone <model_repo_url>
cd <model_dir>
git checkout <commit_id>
```

2. **创建patch文件**：
```bash
# 修改需要适配的文件后
git diff > model_npu.patch
```

3. **应用patch**：
```bash
git apply --reject --whitespace=fix model_npu.patch
```

4. **创建patch.py（可选，结合一键Patcher）**：
```python
from mx_driving.patcher import PatcherBuilder, Patch

def my_patch(root_module, options):
    # 自定义补丁逻辑
    pass

my_patcher_builder = (
    PatcherBuilder()
    .add_module_patch("mmcv", Patch(msda))
    .add_module_patch("projects.xxx", Patch(my_patch))
)
```

5. **修改训练入口**：
```python
# train.py
from mx_driving.patcher import default_patcher_builder

if __name__ == '__main__':
    with default_patcher_builder.build() as patcher:
        main()
```

#### 方式二：一键Patcher方式（推荐用于简单模型）

**适用场景**：模型修改较少、希望无侵入式迁移

**步骤**：

1. **创建migrate_to_ascend目录**：
```bash
mkdir migrate_to_ascend
```

2. **创建patch.py**：
```python
from mx_driving.patcher import PatcherBuilder, Patch, default_patcher_builder
from mx_driving.patcher.mmengine_patch import stream, ddp
from mx_driving.patcher.mmcv_patch import msda, dc, mdc
from mx_driving.patcher.mmdet_patch import resnet_add_relu, resnet_maxpool
from mx_driving.patcher.torch_patch import index
from mx_driving.patcher.numpy_patch import numpy_type

# 屏蔽未安装的CUDA依赖
import sys
from types import ModuleType
sys.modules['mmdet3d.ops.scatter_v2'] = ModuleType('mmdet3d.ops.scatter_v2')
sys.modules['torch_scatter'] = ModuleType('torch_scatter')

# 自定义补丁
def my_custom_patch(root_module, options):
    # 实现自定义替换逻辑
    pass

my_patcher_builder = (
    default_patcher_builder
    .add_module_patch("projects.xxx", Patch(my_custom_patch))
)
```

3. **复制并修改训练脚本**：
```bash
cp tools/train.py migrate_to_ascend/
# 在migrate_to_ascend/train.py中添加patcher context
```

4. **创建启动脚本**：
```bash
# train_8p.sh
export TASK_QUEUE_ENABLE=2
export CPU_AFFINITY_CONF=1
export COMBINED_ENABLE=1
export PYTORCH_NPU_ALLOC_CONF="expandable_segments:True"

python migrate_to_ascend/train.py --config xxx
```

### Phase 4: 性能优化

#### 4.1 环境变量优化

```bash
# 流水优化
export TASK_QUEUE_ENABLE=2        # L2流水优化
export CPU_AFFINITY_CONF=1        # 粗粒度绑核
export COMBINED_ENABLE=1          # 非连续算子组合优化
export PYTORCH_NPU_ALLOC_CONF="expandable_segments:True"  # 内存池扩展

# HCCL通信优化
export HCCL_WHITELIST_DISABLE=1
export HCCL_CONNECT_TIMEOUT=1200
```

#### 4.2 Host Bound问题优化

| 问题类型 | 优化方法 | 预期收益 |
|---------|---------|---------|
| 小算子下发多 | 向量化处理，减少for循环 | 减少CPU开销30-50% |
| CPU计算 | 转为NPU小算子拼接 | 消除CPU瓶颈 |
| 同步等待 | 规避.item()、.cpu()调用 | 提升流水效率 |

**向量化示例**：
```python
# 原始：循环单点插值
for i in range(1, num_len):
    ratio = i / num_len
    res[i-1] = (1 - ratio) * start_pt + ratio * end_pt

# 优化：向量化计算
ratios = torch.arange(1, inter_num + 1, dtype=start_pt.dtype, device=start_pt.device) / (inter_num + 1)
ratios = ratios.view(-1, 1)
return (1 - ratios) * start_pt + ratios * end_pt
```

#### 4.3 高性能内存库

```bash
# 安装tcmalloc
export LD_PRELOAD=/usr/local/lib/lib/libtcmalloc.so.4
```

### Phase 5: 验证与总结

#### 5.1 功能验证

```bash
# 运行训练脚本验证
bash test/train_full_8p.sh --epochs=1
```

#### 5.2 性能Profiling

```python
# 在patcher中添加profiling
my_patcher_builder.with_profiling("./profiling/", level=1, skip_first=20)
```

#### 5.3 适配总结模板

```
## 模型适配总结

### 基本信息
- 模型名称：xxx
- 开源地址：xxx
- 适配commit：xxx

### 适配修改
| 修改类型 | 修改文件 | 修改内容 |
|---------|---------|---------|
| 算子替换 | xxx.py | bev_pool_v2 → bev_pool_v3 |
| 优化器替换 | config.py | AdamW → NpuFusedAdamW |
| 接口适配 | train.py | 添加transfer_to_npu |

### 性能优化
| 优化手段 | 预期收益 |
|---------|---------|
| TASK_QUEUE_ENABLE=2 | 提升流水效率 |
| NpuFusedAdamW | 减少优化器开销 |
| bev_pool_v3 | 提升BEV池化性能 |

### 训练结果
| 芯片 | 卡数 | Batch Size | FPS | 精度指标 |
|-----|-----|-----------|-----|---------|
| Atlas 800T A2 | 8p | 8 | xx | xx |
```

## 参考资源

### DrivingSDK资源
- **模型案例**：`DrivingSDK/model_examples/`
- **API文档**：`DrivingSDK/docs/zh/api/README.md`
- **优化指导**：`DrivingSDK/docs/zh/migration_tuning/model_optimization.md`
- **Patcher文档**：`DrivingSDK/docs/zh/features/patcher.md`

### 高性能算子清单

| 类别 | 算子 | 说明 |
|-----|-----|-----|
| 通用 | scatter_mean, scatter_add, unique_voxel | 点云处理 |
| 采样 | bev_pool_v3, multi_scale_deformable_attn | BEV特征 |
| 检测 | boxes_iou_bev, nms3d, npu_gaussian | 目标检测 |
| 稀疏 | SparseConv3d, SubMConv3d | 稀疏卷积 |
| 融合 | npu_add_relu, npu_max_pool2d, deform_conv2d | 算子融合 |

### 昇腾社区资源
- [PyTorch框架训练环境准备](https://www.hiascend.com/document/detail/zh/ModelZoo/pytorchframework/ptes)
- [torch_npu优化文档](https://www.hiascend.com/document/detail/zh/Pytorch/700/ptmoddevg/trainingmigrguide/)

## 注意事项

1. **版本兼容**：注意PyTorch、mmcv、mmdet等版本匹配
2. **网络问题**：GitHub克隆超时时配置代理或本地克隆后scp
3. **CUDA残留**：确保无CUDA路径污染，检查`site.getsitepackages()`
4. **混合精度**：部分模型FP16训练可能不稳定，需验证
5. **数据集**：nuScenes等数据集需用户自行下载
