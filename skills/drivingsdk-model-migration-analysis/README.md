# 模型NPU适配技能

## 简介

本技能用于指导将新的自动驾驶模型（传统感知模型、规控模型、VLA世界模型等）适配到昇腾NPU平台。

## 使用方法

当您有一个新的模型需要适配到NPU时，可以直接告诉我：

```
我有一个新的模型 xxx 需要适配到昇腾NPU，模型地址是 https://github.com/xxx/xxx
```

我会按照以下流程帮您完成适配：

1. **模型分析**：分析模型结构、训练方式、不支持的算子
2. **适配方案**：设计接口替换、算子替换、优化方案
3. **适配实施**：提供具体的patch或patcher代码
4. **优化建议**：给出性能优化建议和预期收益

## Prompt示例

### 示例1：新模型适配
```
我需要将 BEVFormer_v2 适配到昇腾NPU，请帮我分析适配方案
```

### 示例2：算子替换咨询
```
我的模型使用了 bev_pool_v2 算子，在NPU上应该怎么替换？
```

### 示例3：性能优化
```
我的模型在NPU上训练很慢，请帮我分析可能的优化点
```

## 支持的模型类型

| 模型类型 | 示例模型 | 适配成熟度 |
|---------|---------|-----------|
| BEV感知 | BEVFormer, BEVDet, BEVDepth | 高 |
| 3D检测 | CenterPoint, DETR3D, Sparse4D | 高 |
| 车道线检测 | MapTR, LaneSegNet | 高 |
| 规控预测 | UniAD, VAD, QCNet | 高 |
| VLA世界模型 | OpenVLA, Pi-0, GR00T | 中 |
| 世界模型 | Cosmos, OpenDWM | 中 |

## 参考资源

- [DrivingSDK仓库](https://gitcode.com/Ascend/DrivingSDK)
- [昇腾社区文档](https://www.hiascend.com/document)
