# MindSpeed-MM FSDP2 模型迁移指导手册（开发者可直接上手版）

## 1. 手册定位

- 面向对象：开发者 + AI Agent。
- 目标：读完即可按标准流程迁移一个新模型到 MindSpeed-MM FSDP2。
- 范围：`examples/fsdp2`、`mindspeed_mm/fsdp/models`、`mindspeed_mm/fsdp/data`。

## 2. 先理解框架：你在迁移什么

### 2.1 最小链路

`torchrun -> trainer.py -> import_plugin -> ModelHub.build -> build_mm_dataset/build_mm_dataloader -> model(**batch_data)`

### 2.2 核心接口

| 类别 | 关键接口 | 你必须满足的契约 |
|---|---|---|
| 模型 | `@model_register.register(model_id)` | 配置中的 `model.model_id` 可解析到模型类 |
| 数据 | `@data_register.register(dataset_type)` | 配置中的 `dataset_type` 可解析到 dataset 构建函数 |
| 配置 | `training.plugin` | 插件路径可导入，触发注册 |
| 训练输入 | `model(**batch_data)` | batch 字段与模型 forward 一致 |

## 3. 从现有案例抽取迁移模式

### 3.1 案例分组

| 分组 | 案例 | 特点 |
|---|---|---|
| 多模态图文 | `internvl3_5`、`qwen3vl`、`qwen3_5`、`kimik2_5` | 视觉分支 + 文本模板 + 图像预处理 |
| 音频/语音 | `qwen3tts`、`cosyvoice3`、`funasr` | 任务化数据 schema，声学相关配置更多 |
| 生成式多模态 | `ltx2` | 预计算特征输入，非标准图文数据格式 |

### 3.2 共性模板

- 都有 `parallel/data/model/training/tools` 配置骨架。
- 都依赖 `training.plugin` 注入模型和数据插件。
- 都通过 `trainer.py` 统一启动。

### 3.3 差异源头

- 模型结构差异决定 `fsdp_plan.apply_modules`。
- 数据形态差异决定 `dataset_type` 与 `basic_parameters` 结构。
- 任务目标差异决定 loss 与评估字段。

## 4. 标准迁移流程（一步不省）

### Step 0：迁移前评估

- [ ] 源仓入口脚本定位（train entry）
- [ ] 源仓数据处理核心函数定位
- [ ] 模型特殊 token/特征注入机制确认
- [ ] 数据格式与模态分支清单确认
- [ ] 目标仓已有最相似案例确认

输出物：
- 源-目标映射表（Model/Dataset/Config）
- 风险清单（高/中/低）

### Step 1：模型插件接入

操作：
1. 新增 `mindspeed_mm/fsdp/models/<model_name>/modeling_<model_name>.py`
2. 实现 `@model_register.register("<model_id>")`
3. 兼容 `from_pretrained` + `_from_config`
4. 若有特殊 token，完成 token 注入与 embedding 扩展

通过标准：
- `model_id` 能被 `ModelHub.build` 解析
- 模型对象可构建且 forward 契约不报错

### Step 2：数据插件接入

操作：
1. 新增 `mindspeed_mm/fsdp/data/datasets/<model_name>/<model_name>_dataset.py`
2. 实现 `@data_register.register("<dataset_type>")`
3. 优先复用源仓核心预处理函数
4. 保证 `__getitem__` 返回字段完整

最小字段建议：
- `input_ids`
- `labels`
- `attention_mask`
- `position_ids`（若模型使用）
- `pixel_values`（若多模态）
- `image_flags`（若多模态）

### Step 3：配置迁移

操作：
1. 新增 `examples/fsdp2/<model_name>/<model_name>_config.yaml`
2. 写入 `model_id`、`dataset_type`、`training.plugin`
3. 配置 `parallel.fsdp_plan.apply_modules`
4. 严格区分 `basic_parameters` 与 `*_extra`

强规则：
- `basic_parameters` 仅放 dataclass 已声明字段
- 模型专属字段放 `*_extra`

### Step 4：启动脚本迁移

操作：
1. 新增 `finetune_<model>.sh`
2. 先单机单卡，再放大多卡
3. 命令入口统一 `mindspeed_mm/fsdp/train/trainer.py`

### Step 5：质量门禁

#### 功能门禁
- [ ] 预处理函数可运行
- [ ] 模型构建成功
- [ ] 单步前后向成功

#### 可靠性门禁
- [ ] 路径类型兼容（str/list）
- [ ] 错误配置有可读报错
- [ ] checkpoint 保存/恢复可用

#### 性能门禁
- [ ] step-time 基线
- [ ] 峰值显存基线
- [ ] 通信开销占比

## 5. 情况分类与迁移策略

### 5.1 图文对话类（InternVL/Qwen3VL/Kimi）

重点：
- 模板拼接函数
- 图像切分与 transform
- 多图样本处理
- 视觉 token 注入

典型风险：
- 模板 token 不一致导致 label mask 错误
- 图像 patch 数与 token 数映射错误

### 5.2 大模型 MoE 类（Qwen3.5 大参数）

重点：
- `expert_parallel_size`
- `ep_plan`
- MoE 专属参数

典型风险：
- EP/FSDP 组合导致通信开销和显存行为异常

### 5.3 语音类（Qwen3TTS/FunASR/CosyVoice3）

重点：
- 数据 schema 非图文通用格式
- 特定任务字段与损失配置

典型风险：
- 按图文套路迁移导致字段缺失

### 5.4 预计算特征类（LTX2）

重点：
- 数据不是原始图像，而是预计算 latent/condition
- dataset 与 collate 需支持特征文件组织

典型风险：
- 误用图像预处理 pipeline

## 6. 常见故障库（带定位流程）

| 症状 | 根因 | 定位顺序 | 修复动作 |
|---|---|---|---|
| `KeyError: model_id` | 模型未注册或 plugin 未导入 | 检查 plugin -> 装饰器 -> model_id | 统一命名并修正 plugin |
| `dataset_type not found` | 数据未注册 | 检查 dataset 插件与装饰器 | 修复注册名与路径 |
| `unexpected keyword` | 严格字段越界 | 检查 `basic_parameters` | 移入 `*_extra` |
| `multiple values for config` | 模型加载签名冲突 | 检查 ModelHub 调用和模型签名 | 统一参数解析 |
| `list.endswith` | dataset 类型假设错误 | 打印 dataset 类型 | 路径标准化 |

## 7. 可复用模板

### 7.1 模型模板

```python
@model_register.register("<model_id>")
class XxxForTraining(BaseModel):
    @classmethod
    def from_pretrained(cls, pretrained_model_name_or_path=None, *args, config=None, **kwargs):
        ...
```

### 7.2 数据模板

```python
@data_register.register("<dataset_type>")
def get_xxx_dataset(basic_param, preprocess_param, dataset_param, **kwargs):
    return XxxDataset(...)
```

### 7.3 配置模板

```yaml
data:
  dataset_param:
    dataset_type: <dataset_type>
    <model>_extra: {}
model:
  model_id: <model_id>
training:
  plugin:
    - mindspeed_mm/fsdp/models/<model>
    - mindspeed_mm/fsdp/data/datasets/<model>
```

## 8. 开发者落地清单

- [ ] 有最相似案例对照
- [ ] 完成模型/数据双注册
- [ ] 配置三元一致（model_id/dataset_type/plugin）
- [ ] 执行功能、可靠性、性能门禁
- [ ] 输出证据化迁移记录

## 9. 关键案例引用

- [internvl3_5_1b_config.yaml](examples/fsdp2/internvl3_5/internvl3_5_1b_config.yaml)
- [qwen3vl_30B_config.yaml](examples/fsdp2/qwen3vl/qwen3vl_30B_config.yaml)
- [qwen3_5_122B_config.yaml](examples/fsdp2/qwen3_5/qwen3_5_122B_config.yaml)
- [kimik2_5_config.yaml](examples/fsdp2/kimik2_5/kimik2_5_config.yaml)
- [qwen3tts_config.yaml](examples/fsdp2/qwen3tts/qwen3tts_config.yaml)
- [ltx2_config_t2v.yaml](examples/fsdp2/ltx2/ltx2_config_t2v.yaml)
- [funasr_config.yaml](examples/fsdp2/funasr/funasr_config.yaml)
- [cosyvoice3_config.yaml](examples/fsdp2/cosyvoice3/cosyvoice3_config.yaml)
