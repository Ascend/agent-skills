---
name: catlass-operator-code-gen
description: 根据CATLASS算子设计文档生成算子工程交付件
---

# Catlass 算子代码生成

## 核心工作流

```
设计文档解析 → Catlass 实现参考选型 → op_host 生成 → op_kernel 生成 → test_aclnn 生成 → 质量验证
```

---

## 设计文档遵守规范（CRITICAL）

**MANDATORY：设计文档是代码生成的唯一依据，须 100% 遵守。**

| 设计文档章节 | 必须遵守的内容 | 验证方式 |
|-------------|---------------|---------|
| 算子名 | 含 `catlass` 子串，snake_case 目录名与 CamelCase 类名一致 | 目录、OpDef、test_aclnn 中命名一致 |
| I/O 与 dtype | 输入输出 shape、dtype、format | OpDef 与 test_aclnn 中 tensor 一致 |
| 核心组件 | ArchTag、BlockMmad、BlockEpilogue、BlockScheduler、Kernel 类型；**自定义 Tile** 时设计文档须已含 §3.3.1 契约 | op_kernel 与 [custom-epilogue.md](references/custom-epilogue.md) 一致 |
| 参考 example | 指定的 catlass example 路径与选型理由 | 实现与选型一致（非整份粘贴） |
| TilingKey | 各分支对应 dtype/转置等 | Host `SetTilingKey` 与 `TILING_KEY_IS` 一一对应 |
| Workspace | 固定写法 | [tiling-rules.md](references/tiling-rules.md)、[kernel-rules.md](references/kernel-rules.md)「Workspace 固定写法」 |

---

## 前置条件

| 检查项 | 说明 |
|--------|------|
| 设计文档 | 含算子名、I/O、dtype、转置、参考 example、Kernel/Block/Epilogue；常为 `USER_OP_PROJECT/design_<op_name>.md`（catlass-operator-design） |
| 工程 | `OPS_PROJECT_ROOT` 已定，含 `build.sh`、`ops/` |
| Catlass | `<OPS_PROJECT_ROOT>/catlass/` 含 `include/`、`examples/`；缺则在工程根 `git clone https://gitcode.com/cann/catlass.git catlass`（勿在 `ops/<op>/` 内克隆）。kernel 侧 `-I` 与 `CATLASS_ARCH` 见 [references/kernel-rules.md](references/kernel-rules.md) 开篇 |

条件不明时**追问**用户。

---

## Catlass 实现参考选型（写 kernel 前）

在 `catlass/examples/` 中按设计文档选定**实现参考**（读结构、抄组件组合思路，**不是**把 example 当 `ops/` 迁移源）：

1. 找与算子形态最接近的示例。
2. 确定可复用的 Kernel/Block/Epilogue；**算子工程 op_kernel 须 Device 调用**，见 [references/kernel-rules.md](references/kernel-rules.md)「Host 调用 vs Device 调用」。
3. 将 tiling 常量、Workspace、`TILING_KEY_IS` 分支与 Host 侧对齐；适配到 `ops/<op_name>/`，避免整文件粘贴。

工程化目录与文件落盘：见 [references/code-structure.md](references/code-structure.md)。

---

## 端到端步骤（执行顺序）

### Step 0：生成骨架（强制）

在 `OPS_PROJECT_ROOT`：`bash build.sh --genop=ops/<op_name>`。  
目录自检：见 [code-structure.md](references/code-structure.md)。

### Step 1：清理模板、补齐 `op_kernel/CMakeLists.txt`

确认 `ops/<op_name>/` 已生成；删无用模板；`op_kernel/CMakeLists.txt` 须含 catlass 编译选项（见 [kernel-rules.md](references/kernel-rules.md)）。

### Step 2：对照设计文档列清单

算子名、I/O、dtype、转置、参考路径、Kernel/Block/Epilogue、Workspace、TilingKey 分支。

### Step 3：锁定实现参考

同上文「Catlass 实现参考选型」。

### Step 4：写 op_host

按 [tiling-rules.md](references/tiling-rules.md)、[infershape-rules.md](references/infershape-rules.md)、[def-rules.md](references/def-rules.md) 覆盖 `*_tiling.h`、`*_tiling.cpp`、`*_infershape.cpp`、`*_def.cpp`；def 与 tiling/infershape **分文件**，仅通过注册与命名一致关联。

### Step 5：写 op_kernel

按 [kernel-rules.md](references/kernel-rules.md)：`GET_TILING_DATA`、`TILING_KEY_IS`、Device 调用、`#define K_MAX_SHAPE_DIM 0`、勿 `#include` tiling.h。设计文档约定**自定义 Tile Epilogue** 时，按 [custom-epilogue.md](references/custom-epilogue.md) 增加 `op_kernel/custom_epilogue/*.hpp` 与 CMake `-I`。

### Step 6：写 test_aclnn

按 [example-rules.md](references/example-rules.md) 覆盖 `examples/test_aclnn_<op_name>.cpp`。

### Step 7：验证

- 结构自检：[code-structure.md](references/code-structure.md)  
- tiling / def / infershape / kernel：各 `*-rules.md` 检查清单；workspace 见 [kernel-rules.md](references/kernel-rules.md)「Workspace 固定写法」  
- 测试示例：[example-rules.md](references/example-rules.md)（改算子后须 **pkg + 安装** 再 `--run_example`）  
- 编译与运行：**ascendc-operator-compile-debug**

---

## 常见陷阱

**NEVER**：跳过 `--genop`；tiling/infershape 并进 def；漏 `IMPL_OP_*` 注册；def 里 `SetTiling`/`SetInferShape`；目录名无 `catlass`；Kernel 内用 `if` 代替 TilingKey；op_kernel 用 `DeviceGemm`；op_kernel `#include` tiling.h；**对 Gemm 仅用 shape 推断转置**（方阵歧义 + Tiling 无 stride）；kernel 里 **`SetSysWorkspaceForce(workspace)`** + **`GetUserWorkspace`**；**仅** `--run_example` 却不 **`--pkg` 安装**；OpDef 上 **dtype 个数与 format 列表长度不一致**；对 `GM_ADDR` workspace 做 **`reinterpret_cast<uint8_t*>`** 再喂给 `MatmulActivation::ToUnderlyingArguments`。

**ALWAYS**：先 opgen 再覆盖；三文件分文件注册；严格按设计文档组件选型；`op_kernel/CMakeLists.txt` 配 catlass；编译调试用 **ascendc-operator-compile-debug**；workspace 用 [kernel-rules.md](references/kernel-rules.md) 固定写法；改算子后 **`--pkg` 安装 `.run` 再跑示例**。

---

## references 索引（按需打开）

| 文件 | 内容 |
|------|------|
| [references/code-structure.md](references/code-structure.md) | 目录树、文件职责索引、genop 与路径自检 |
| [references/example-rules.md](references/example-rules.md) | **仅** test_aclnn 写法与 `--run_example` |
| [references/tiling-rules.md](references/tiling-rules.md) | tiling.h / tiling.cpp |
| [references/def-rules.md](references/def-rules.md) | def.cpp |
| [references/infershape-rules.md](references/infershape-rules.md) | infershape.cpp |
| [references/kernel-rules.md](references/kernel-rules.md) | Catlass 依赖与 `op_kernel/CMakeLists`、Device 调用 |
| [references/custom-epilogue.md](references/custom-epilogue.md) | 自定义 Tile Epilogue 头文件与 CMake（设计已定稿后） |

---

## 参考资料（库路径与相关 skill）

| 文档/目录 | 用途 |
|-----------|------|
| catlass/examples/advanced/basic_matmul_aclnn | 工程化 op_host / op_kernel / 测试组织对照 |
| catlass/examples/03_matmul_add | MatmulEpilogue + BlockEpilogue 组合参考 |
| catlass/include/catlass/gemm/kernel/matmul_epilogue.hpp | Epilogue / Workspace 细节 |
| [如何使用 workspace](https://www.hiascend.com/document/detail/zh/CANNCommunityEdition/900beta1/opdevg/Ascendcopdevg/atlas_ascendc_10_0092.html) | 与固定写法对照 |
| ascendc-operator-tiling-code-gen | tiling 宏与注册范式 |
| ascendc-operator-compile-debug | 编译、安装、跑示例 |
| catlass-operator-design | 设计文档 |
