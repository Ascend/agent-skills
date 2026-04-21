# 模型迁移至 MindSpeed-MM FSDP2 后端指导手册

## 目录

1. [概述](#1-概述)
2. [迁移前评估清单](#2-迁移前评估清单)
3. [分步骤迁移实施流程](#3-分步骤迁移实施流程)
4. [常见问题解决方案库](#4-常见问题解决方案库)
5. [代码模板与配置示例](#7-代码模板与配置示例)

---

## 1. 概述

### 1.1 文档目的

本文档旨在提供将多模态大模型迁移至 MindSpeed-MM 框架 FSDP2 后端的标准化指导，确保迁移过程高效、可复现、风险可控。

### 1.2 适用范围

- 多模态 Vision-Language 模型（如 InternVL, Qwen-VL, LLaVA 等）
- 纯语言模型（如 Qwen, LLaMA, InternLM 等）
- 音频/视频模型（如 CosyVoice, FunASR 等）

### 1.3 前提条件

- 源仓模型代码可访问
- 目标模型已在 HuggingFace 或本地存储可用
- 具备 FSDP2 分布式训练环境

---

## 2. 迁移前评估清单

### 2.1 模型兼容性检查

| 检查项 | 评估内容 | 通过标准 |
|-------|---------|---------|
| 模型架构 | 确认模型类型（纯 LLM / VLM / 多模态） | 模型类可继承 BaseModel |
| 预训练加载 | 确认模型加载方式（AutoModel / 自定义） | 支持 from_pretrained |
| 配置格式 | 确认配置文件格式 | HuggingFace Config 或自定义 |
| 依赖项 | 确认模型依赖的外部库 | 已在环境中安装 |


### 2.2 评估模板

```yaml
## 模型迁移评估报告

模型名称: <模型名称>
模型类型: [ ] 纯LLM  [ ] VLM  [ ] 多模态
模型大小: <参数数量>

```

---

## 3. 分步骤迁移实施流程

### Phase 1: 模型层迁移

#### Step 1.1: 创建模型目录结构

```
mindspeed_mm/fsdp/models/<model_name>/
├── __init__.py
└── modeling_<model_name>.py
```

#### Step 1.2: 实现模型类

```python
# modeling_<model_name>.py

from mindspeed_mm.fsdp.models.base_model import BaseModel
from mindspeed_mm.fsdp.utils.register import model_register

@model_register.register("<model_id>")
class <ModelName>ForTraining(BaseModel):

    @classmethod
    def from_pretrained(
        cls,
        pretrained_model_name_or_path=None,
        *model_args,
        config=None,
        trust_remote_code=True,
        **kwargs
    ):
        ...

    @classmethod
    def _from_config(cls, config):
        # 从配置创建模型的实现
        ...
```

#### Step 1.4: 模型迁移检查清单

- [ ] 模型类正确继承 BaseModel
- [ ] 使用 @model_register.register 注册
- [ ] from_pretrained 方法正确实现
- [ ] _from_config 方法正确实现（支持 meta device 初始化）
- [ ] 特殊 token 处理正确
- [ ] embedding 扩展逻辑正确
- [ ] use_cache 正确禁用

### Phase 2: 数据集层迁移

#### Step 2.1: 创建数据集目录结构

```
mindspeed_mm/fsdp/data/datasets/<model_name>/
├── __init__.py
└── <model_name>_dataset.py
```

#### Step 2.2: 实现数据集类

```python
# <model_name>_dataset.py

@data_register.register("<dataset_type>")
class <ModelName>SupervisedDataset(Dataset):

    def __init__(self, basic_param, preprocess_param, dataset_param):
        ...

    def __len__(self):
        return len(self.raw_data)

    def __getitem__(self, idx):
        ...

    def _load_annotations(self, paths):
        """加载标注数据"""
        ...

    def _preprocess_image(self, image):
        """图像预处理"""
        ...

    def _build_text_ret(self, conversations, num_patches):
        """构建文本输入"""
        ...

    def collate_fn(self, features):
        """Batch 拼接"""
        return concat_pad_data_collator(features, pad_id=self.tokenizer.pad_token_id)
```

#### Step 2.3: 核心预处理函数复用

举例：从源仓直接拷贝的核心函数：

```python
# 以下函数应直接从源仓拷贝，无需修改
def expand2square(pil_img, background_color):
    """图像填充至正方形"""
    ...

def build_transform(is_train, input_size, pad2square=False, normalize_type='imagenet'):
    """图像预处理"""
    ...

def dynamic_preprocess(image, min_num=1, max_num=6, image_size=448, use_thumbnail=False):
    """动态图像切分"""
    ...

def preprocess_internvl3_5_gpt_oss(...):  # 对话模板预处理
    """对话格式处理 - 可能需要适配 token 格式"""
    ...
```

#### Step 2.4: 数据集迁移检查清单

- [ ] 数据集类使用 @data_register.register 注册
- [ ] 正确实现 __len__ 和 __getitem__
- [ ] 核心预处理函数直接从源仓拷贝
- [ ] Tokenizer 特殊 token 处理正确
- [ ] collate_fn 正确实现 batch 拼接
- [ ] 数据路径解析兼容绝对路径和相对路径

### Phase 3: 配置与启动

#### Step 3.1: 创建训练配置

```yaml
# examples/fsdp2/<model_name>/<model_name>_config.yaml

parallel:
  tensor_parallel_size: 1
  fully_shard_parallel_size: auto
  fsdp_plan:
    apply_modules:
      - <vision_module_pattern>    # 如 vision_model.encoder.layers.{*}
      - mlp1
      - <llm_module_pattern>       # 如 language_model.model.layers.{*}
    param_dtype: bf16
    reduce_dtype: fp32
  recompute: true
  ring_attention_size: 1
  ulysses_parallel_size: 1
  expert_parallel_size: 1

data:
  dataset_param:
    dataset_type: <dataset_type>      # 与 @data_register.register 中的名称一致
    preprocess_parameters:
      model_name_or_path: <model_path>
      trust_remote_code: true
    basic_parameters:
      template: <template_name>
      dataset: <dataset_path>
      cutoff_len: 8192

model:
  model_id: <model_id>                # 与 @model_register.register 中的名称一致
  model_name_or_path: <model_path>
  trust_remote_code: true
  attn_implementation: flash_attention_2

training:
  micro_batch_size: 1
  gradient_accumulation_steps: 1
  lr: 1.0e-4
  lr_decay_style: cosine
  lr_warmup_ratio: 0.03
  train_iters: 1000
  optimizer: adamw
  plugin:
    - mindspeed_mm/fsdp/models/<model_name>
    - mindspeed_mm/fsdp/data/datasets/<model_name>
```

#### Step 3.2: 创建启动脚本

```bash
# examples/fsdp2/<model_name>/finetune_<model_name>.sh

source /home/CANN/CANN8.5.0/ascend-toolkit/set_env.sh
export NON_MEGATRON=true
export HCCL_CONNECT_TIMEOUT=1200
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True

NPUS_PER_NODE=8
MASTER_ADDR=localhost
MASTER_PORT=6000
NNODES=1
NODE_RANK=0

DISTRIBUTED_ARGS="
    --nproc_per_node $NPUS_PER_NODE \
    --nnodes $NNODES \
    --node_rank $NODE_RANK \
    --master_addr $MASTER_ADDR \
    --master_port $MASTER_PORT
"

torchrun $DISTRIBUTED_ARGS mindspeed_mm/fsdp/train/trainer.py \
    examples/fsdp2/<model_name>/<model_name>_config.yaml
```

#### Step 3.3: 配置检查清单

- [ ] model_id 与注册名称一致
- [ ] dataset_type 与注册名称一致
- [ ] plugin 路径正确指向模型和数据集目录
- [ ] apply_modules 覆盖所有需要分片的模块
- [ ] 数据路径配置正确

---

## 4. 常见问题解决方案库

### 4.1 模型加载问题

| 错误模式 | 原因 | 解决方案 |
|---------|------|---------|
| `KeyError: '<model_id>'` | 模型未正确注册 | 检查 @model_register.register 装饰器 |
| `OSError: Unable to load model` | 模型路径错误 | 确认 model_name_or_path 正确 |
| `trust_remote_code=True required` | 自定义模型文件缺失 | 设置 trust_remote_code=True |

### 4.2 数据处理问题

| 错误模式 | 原因 | 解决方案 |
|---------|------|---------|
| `ValueError: dataset_type not found` | 数据集未注册 | 检查 @data_register.register |
| `FileNotFoundError` | 数据路径错误 | 检查 dataset_dir 和 dataset 配置 |
| `KeyError: 'conversations'` | 数据格式不匹配 | 检查 attr 配置的字段映射 |

### 4.3 分布式训练问题

| 错误模式 | 原因 | 解决方案 |
|---------|------|---------|
| `RuntimeError: No FSDP modules` | apply_modules 配置错误 | 检查 fsdp_plan.apply_modules |
| `CUDA out of memory` | batch size 过大或分片策略不当 | 减小 micro_batch_size 或启用重计算 |
| ` NCCL timeout` | 通信问题 | 增加 HCCL_CONNECT_TIMEOUT |

### 4.4 FSDP2 分片问题

| 错误模式 | 原因 | 解决方案 |
|---------|------|---------|
| 模块未正确分片 | 模块名称模式不匹配 | 使用 {*} 通配符匹配所有子模块 |
| 部分参数未分片 | 遗漏某些模块 | 确保 apply_modules 覆盖所有参数模块 |
| 梯度同步问题 | reduce_dtype 配置不当 | 使用 fp32 进行梯度 reduce |

### 4.5 Tokenizer 问题

| 错误模式 | 原因 | 解决方案 |
|---------|------|---------|
| 特殊 token 未识别 | 未添加到 tokenizer | 使用 tokenizer.add_tokens() 添加 |
| 词汇表大小不匹配 | embedding 未扩展 | 在 _post_init_model 中扩展 embedding |
| pad_token 未设置 | tokenizer 配置问题 | 设置 tokenizer.pad_token = tokenizer.eos_token |

---


---

## 7. 代码模板与配置示例

### 7.1 模型类模板

```python
# mindspeed_mm/fsdp/models/<model_name>/modeling_<model_name>.py


@model_register.register("<model_id>")
class <ModelName>ForTraining(BaseModel):

    @classmethod
    def from_pretrained(
        cls,
        pretrained_model_name_or_path=None,
        *model_args,
        config=None,
        trust_remote_code=True,
        **kwargs
    ):
        ...

    @classmethod
    def _from_config(cls, config):
        ...
```

### 7.2 数据集类模板

```python
# mindspeed_mm/fsdp/data/datasets/<model_name>/<model_name>_dataset.py


# ============ 核心预处理函数（直接从源仓拷贝）============

def expand2square(pil_img, background_color):
    ...


def build_transform(is_train, input_size, pad2square=False, normalize_type="imagenet"):
    ...



# ============ 数据集类 =====================

@data_register.register("<dataset_type>")
class <ModelName>SupervisedDataset(Dataset):

    def __init__(self, basic_param, preprocess_param, dataset_param):
        ...

    def __len__(self):
        return len(self.raw_data)


    def __getitem__(self, idx):
        ...

    def collate_fn(self, features):
        ...
```

### 7.3 完整配置示例

```yaml
# examples/fsdp2/<model_name>/<model_name>_config.yaml

parallel:
  tensor_parallel_size: 1
  fully_shard_parallel_size: auto
  fsdp_plan:
    apply_modules:
      - vision_model.encoder.layers.{*}
      - mlp1
      - language_model.model.embed_tokens
      - language_model.model.layers.{*}
      - language_model.lm_head
    param_dtype: bf16
    reduce_dtype: fp32
  recompute: true
  recompute_plan:
    apply_modules:
      - language_model.model.layers.{*}
  ring_attention_size: 1
  ulysses_parallel_size: 1
  expert_parallel_size: 1

data:
  dataset_param:
    dataset_type: <dataset_type>
    preprocess_parameters:
      model_name_or_path: /path/to/model
      trust_remote_code: true
    basic_parameters:
      template: <template_name>
      dataset_dir: /path/to/data/
      dataset: /path/to/data/train.jsonl
      cutoff_len: 8192

  dataloader_param:
    pin_memory: true
    shuffle: true
    dataloader_mode: sampler
    drop_last: true
    sampler_type: BaseRandomBatchSampler
    num_workers: 4

model:
  model_id: <model_id>
  model_name_or_path: /path/to/model
  trust_remote_code: true
  attn_implementation: flash_attention_2
  freeze: []
  loss_cfg:
    loss_type: raw

training:
  micro_batch_size: 1
  gradient_accumulation_steps: 1
  seed: 42
  lr: 1.0e-4
  lr_decay_style: cosine
  lr_warmup_ratio: 0.03
  weight_decay: 0.05
  train_iters: 1000
  clip_grad: 1.0
  optimizer: adamw
  save_interval: 200
  plugin:
    - mindspeed_mm/fsdp/models/<model_name>
    - mindspeed_mm/fsdp/data/datasets/<model_name>

tools:
  profile:
    enable: false
  memory_profile:
    enable: false
```

---

## 附录

### A. 术语表

| 术语 | 说明 |
|-----|------|
| FSDP2 | Fully Sharded Data Parallel v2，PyTorch 分布式训练策略 |
| BaseModel | MindSpeed-MM 模型基类 |
| model_register | 模型注册表 |
| data_register | 数据集注册表 |
| Dynamic Preprocess | 动态图像切分技术 |

