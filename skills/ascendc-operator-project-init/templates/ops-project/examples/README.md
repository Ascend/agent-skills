## 简介

> 说明：
> - 目前算子库中大部分算子运行在AI Core上，少部分算子运行在AI CPU上。默认情况下，项目中提到的算子指AI Core算子。
> - 关于AI Core和AI CPU的介绍请参见[《Ascend C算子开发》](https://hiascend.com/document/redirect/CannCommunityOpdevAscendC)中“概念原理和术语 > 硬件架构与数据处理原理”。

本项目提供了AI Core算子和AI CPU算子的开发和调用样例，请开发者根据实际情况参考对应实现。

## 目录说明
```
├── examples                       
│   ├── add_example                # AI Core算子名
│   │   ├── CMakeLists.txt         # 算子编译配置文件，保留原文件即可   
│   │   ├── examples               # 算子使用示例
│   │   ├── op_graph               # 算子构图相关目录
│   │   ├── op_host                # 算子信息库、Tiling、InferShape相关实现
│   │   └── op_kernel              # 算子kernel目录
│   ├── add_example_aicpu          # AI CPU算子名
│   │   ├── CMakeLists.txt         # 算子编译配置文件，保留原文件即可   
│   │   ├── examples               # 算子使用示例
│   │   ├── op_graph               # 算子构图相关目录
│   │   ├── op_host                # 算子信息库、InferShape相关实现
│   │   └── op_kernel_aicpu        # 算子kernel目录
│   ├── CMakeLists.txt             # 算子编译配置文件，保留原文件即可
│   └── README.md                  # 算子说明文档

```

## 算子开发样例
|样例目录| 	样例介绍	           |算子开发|算子调用 |
|---|------------------|---|---|
| add_example | 	实现两个张量相加功能的算子。	 | 算子端到端开发过程参见[AI Core算子开发指南](../docs/zh/develop/aicore_develop_guide.md) |调用参见[README](add_example/README.md)|
|add_example_aicpu| 	实现两个张量相加功能的算子。	 |算子端到端开发过程参见[AI CPU算子开发指南](../docs/zh/develop/aicpu_develop_guide.md)| 调用参见[README](add_example_aicpu/README.md) |
|fast_kernel_launch_example| 	实现一种PyTorch场景下快速端到端开发算子的样例。	 |算子端到端开发过程参见[PyTorch算子快速开发指南](./fast_kernel_launch_example/README.md)| 调用参见[README](fast_kernel_launch_example/README.md) |