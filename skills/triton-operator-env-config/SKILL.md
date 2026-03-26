---
name: triton-ascend-environment
description: 在 Ascend 昇腾平台上校验并构建triton算子开发所需环境,包括CANN、Python/torch/torch_npu/triton-ascend依赖和PATH环境变量等设置
TRIGGER when:
  keywords: triton、triton-ascsend、CANN、torch_npu、环境配置、算子开发
  tasks: triton算子开发前环境检查,依次检查python、python包、CANN环境配置，最终执行算子样例验证
---

# Triton 算子开发环境

---

## 1. 依次检查环境（必做顺序）

必须在同一终端会话下执行
python包的检查的前提是python环境符合要求

### 1.1 CANN 环境配置

1. 执行`npu-smi info`，检查是否成功加载驱动
2. 再执行`which bisheng`，检查是否成功加载CANN环境获取到npuir编译器，应该输出路径
3. 如果没有输出，尝试加载 CANN 环境：
   - 优先：`source /usr/local/Ascend/cann/set_env.sh`
   - 备选：`source /usr/local/Ascend/ascend-toolkit/set_env.sh`
4. 再次执行第1步和第2步检查，如果不成功，需要等待用户去检查解决CANN的环境配置，可以提醒去https://www.hiascend.com/cann/download 上下载安装CANN

### 1.2 Python版本

**如果遇到python问题，最优先使用miniconda创建环境解决**
1. 检查当前 python 的路径：`which python3`
2. 若失败尝试执行：`export PATH="/usr/bin:$PATH"`
3. 再次执行第1步检查，如果不成功，则需要提醒用户安装3.11版本python，安装方式优先使用下面miniconda的方法
4. 如果存在python3，检查python版本：`python3 --version`，**必须在3.9到3.11之间**，如果不在需要提醒用户安装3.11版本，用下面的方法安装

### 1.3 Python环境安装

1. 如果用户需要安装python环境，先使用`conda init bash`检查是否有conda环境，有则跳转第5步，如果没有则执行第2步安装
2. 执行`uname -m`确认当前系统架构
   如果系统架构为aarch64，执行：`wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh`
   如果系统架构为x86_64，执行：`wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh`
3. 执行安装脚本：`bash Miniconda3-latest-Linux-x86_64.sh`或`bash Miniconda3-latest-Linux-aarch64.sh`，按照提示安装后激活miniconda环境
4. 检查是否成功安装miniconda环境：`conda init bash`
5. 创建一个python环境，执行：`conda create -n triton python=3.11`
6. 激活python环境，执行：`conda activate triton`

### 1.4 torch配置

**必须保证前面的步骤都成功**
1. 执行：`pip list | grep "torch"`
2. 检查torch版本，需要为 2.7.1，torch_npu版本需要与torch配套
3. 如果版本不符合要求提示用户安装2.7.1版本torch，下面为安装步骤
4. 执行：`pip install torch==2.7.1`
5. 如果没有安装torch_npu包，执行：`pip install torch_npu==2.7.1`
6. 检查torch环境是否配置成功：`python3 -c "import torch; print(torch.__version__)"，应该输出2.7.1，torch_npu版本需要与torch配套
7. 运行一个简单的torch代码，检查是否成功加载npu设备：`python3 -c "import torch; a = torch.randn(2, 3); print(a)"`，应该输出类似结果：`tensor([[2.86, 1.0406, 1.5811], [0.8329, 1.0024, 1.3639]])`

### 1.5 triton-ascend配置
1. 执行：`pip list | grep "triton"`
2. 如果安装了原生的triton，需要先卸载triton和triton-ascend包
3. 安装最新的triton-ascend包：`pip install triton-ascend`

---

## 2. 环境验证

用于确认当前终端环境可以正常执行triton算子。

1. 下载源码: `git clone https://gitcode.com/Ascend/triton-ascend.git`
2. 执行用例：`python3 ./triton-ascend/third_party/ascend/tutorials/01-vector-add.py`

执行该算子样例后，如出现类似结果则表明其计算符合预期，difference为0.0则视为验证通过
```
tensor([0.8329, 1.0024, 1.3639,  ..., 1.0796, 1.0406, 1.5811], device='npu:0')
tensor([0.8329, 1.0024, 1.3639,  ..., 1.0796, 1.0406, 1.5811], device='npu:0')
The maximum difference between torch and triton is 0.0
```

---

## 3. 故障处理

| 现象 | 动作 |
|------|------|
| **找不到 C++ compiler** | 安装编译器：`apt-get install g++` |
| **已按上表重试仍失败** | 保留完整终端报错与已执行的命令序列，便于本地或后续排查 |

---

## 注意事项

- 如果上述流程后还有问题，可以到./triton-ascend/docs/zh/quick_start.md查看是否有新的配套要求