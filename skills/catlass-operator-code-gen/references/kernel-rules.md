# op_kernel 生成

## Catlass 源码与 kernel 编译（与代码生成强相关）

- **放哪克隆**：只在 **OPS_PROJECT_ROOT**（与 `build.sh`、`ops/` 同级）需要 `catlass/`。缺则：`git clone https://gitcode.com/cann/catlass.git catlass`。不要克隆进 `ops/<算子名>/`。
- **为何常要手写 `op_kernel/CMakeLists.txt`**：`--genop` 往往只落下 `op_host/CMakeLists.txt`；父级 `ops/<算子>/CMakeLists.txt` 只会给**带子 CMake 的目录**做 `add_subdirectory`。没有 `op_kernel/CMakeLists.txt` 时，工程里的 `add_ops_compile_options` 不会作用到 kernel，表现为 **catlass 已存在仍找不到头文件**。
- **最小片段**（`CMAKE_SOURCE_DIR` = OPS_PROJECT_ROOT；`2201` = Atlas A2 / ascend910b，其它芯片按 `catlass/README.md` 调整 `CATLASS_ARCH`）：

```cmake
set(CATLASS_DIR "${CMAKE_SOURCE_DIR}/catlass")
add_ops_compile_options(ALL COMPUTE_UNIT ${ASCEND_COMPUTE_UNIT} OPTIONS -I${CATLASS_DIR}/include -DCATLASS_ARCH=2201)
```

- **dtype 与 L1 分块**：`03_matmul_add` 等示例多为 **half**；**float** 若沿用 `GemmShape<128,256,256>` 等大块，易触发 `block_mmad_pingpong.hpp` 的 **L1TileShape exceeding the L1 space**。需按仓库内 float 范例（如 `examples/15_gemm`）**缩小 L1/L0 TileShape**，并在设计文档中写明。

---

## Kernel 实现结构

1. 导入所需头文件
   - catlass 系列头文件
   - lib/matmul_intf.h（固定）
2. 编写 kernel 模板函数
3. 编写 kernel 入口
   - `GET_TILING_DATA` 取 tiling 数据
   - 从 tiling 数据构造 kernel 入口所需的一些结构体和常量，如 `GemmCoord problemShape`
   - 在 `TILING_KEY_IS(key)` 分支中实例化 kernel
   - 例：`using Kernel=xxx; using KernelParams=Kernel::Params; Params params{...};`（通常每个 key 对应一种 dtype/转置组合，但不限于这些情形。任何可能导致模板参数不同的参数组合，都应当被视为新的TILING_KEY_IS分支，如Swizzle）
4. 对于多 `TILING_KEY_IS` 分支内使用相同模板的情形，可以将固定的模板拆分到一个 `.h` 文件中，`.cpp` 只对对应 KEY 实例化对应模板，以使 cpp 文件中的内容更加清晰。

详细可参考 `examples/catlass_basic_matmul.cpp`。

## Host 调用 vs Device 调用（关键区分）

Catlass example 中存在两种 Kernel 调用模式，op_kernel 必须使用 Device 调用：

| 模式 | 适用场景 | 关键类 | 调用方式 |
|------|---------|--------|---------|
| **Device 调用** | op_kernel（算子工程） | 直接使用 `Kernel::BasicMatmul` 等 Kernel 类 | 构造 `Kernel::Params`，调用 `Kernel(params)` 执行 |
| Host 调用 | example 测试/演示 | `Gemm::Device::DeviceGemm<Kernel>` 适配器 | `Initialize` → `operator(stream, coreNum)` 管理 workspace 等 |

**op_kernel 中的 Device 调用写法（必须遵循）：**

```cpp
// 在 TILING_KEY_IS 分支内
using Kernel = Gemm::Kernel::BasicMatmul<BlockMmad, BlockEpilogue, BlockScheduler>;
Kernel::Params params{problemShape, gmA, layoutA, gmB, layoutB, gmC, layoutC, workspace};
Kernel kernel;
kernel(params);
```

**错误写法 — 不要在 op_kernel 中使用 Host 适配器：**

```cpp
// ❌ DeviceGemm 是 Host 侧适配器，仅用于 example/main 中调测，不可出现在 op_kernel
using MatmulAdapter = Gemm::Device::DeviceGemm<MatmulKernel>;
MatmulAdapter matmulOp;
matmulOp.Initialize(arguments, deviceWorkspace);
matmulOp(stream, aicCoreNum);
```

`catlass/examples` 中 `DeviceGemm` 适配器用于封装 Host 调用流程（管理 workspace 分配、stream 调度等），但算子工程的 op_kernel 运行在 AI Core 上，应直接实例化 Kernel 类并调用 `operator()`。Host 侧的 workspace 分配、tiling 数据准备由 op_host 的 Tiling 函数和框架调度完成。

---

## Workspace 固定写法（仅 op_kernel）

Host 侧 `GetWorkspaceSizes` 写法见 [tiling-rules.md](./tiling-rules.md)。

需把 GM workspace 交给 Catlass `Params` 时：

```cpp
#include "kernel_operator.h"
// ...
GM_ADDR userWs = const_cast<GM_ADDR>(AscendC::GetUserWorkspace(workspace));
// Catlass ... Params{ ..., userWs, ... };
```

**禁止**：`SetSysWorkspaceForce(workspace)`。

---

## 检查清单（op_kernel）

- [ ] catlass 头文件与 kernel_operator.h 均已包含
- [ ] `op_kernel/CMakeLists.txt` 存在且含对本算子 kernel 的 `add_ops_compile_options`（见上文「Catlass 源码与 kernel 编译」）
- [ ] TILING_KEY_IS 分支覆盖设计文档中所有 dtype/转置组合
- [ ] 各分支使用 Catlass 提供的 Kernel/Block/Tile 组合
- [ ] 使用 Device 调用：直接实例化 `Kernel` + `Kernel::Params`，未使用 `DeviceGemm` 适配器
- [ ] 未手写标量/逐元素计算
- [ ] 未 `#include` tiling.h（避免 DT_FLOAT 等宏冲突）
- [ ] 顶部有 `#define K_MAX_SHAPE_DIM 0`
- [ ] 若使用 GM workspace：按上文；Host 申报见 [tiling-rules.md](./tiling-rules.md)；**未**对 `workspace` 调 `SetSysWorkspaceForce`

TilingKey 与 Host 侧说明见 [tiling-rules.md](./tiling-rules.md)；端到端顺序中 op_kernel 步骤见 [SKILL.md](../SKILL.md)「Step 5」。

---

## OPC 预编译与工程脚本（易踩坑）

- **`TILING_KEY_IS(...)`**：预编译阶段要求括号内为**数字常量**（如 `TILING_KEY_IS(0)`），不要用 `constexpr` 变量名，否则报 “can not be processed as numeric variables”。
- **`GetUserWorkspace`**：使用 **`AscendC::GetUserWorkspace(workspace)`**（与模板里无命名空间的全局形式区分）。
- **`custom_compile_options.ini` 与 `SHORT_SOC_VERSION`**：`ascend910b` 在描述里会归一为 `ascend910`，而 OPC 运行时短 SoC 常为 **`ascend910b`**，导致 Catlass 的 `-I` 未进编译命令。若在工程 `scripts/util/opdesc_parser.py` 中已在写入 `ascend910` 时同步写入 `ascend910b`，可消除该不一致（本仓库已按此方式修补时适用）。**仅允许改算子目录时**：在 `op_kernel/CMakeLists.txt` 对同一 Op 类名 **连写两条** `add_ops_compile_options(<OpClassName> COMPUTE_UNIT ascend910b ...)` 与 `add_ops_compile_options(... COMPUTE_UNIT ascend910b1 ...)`（OPTIONS 相同），分别覆盖映射后的 `ascend910` 与运行时 `ascend910b`。
- **`MatmulActivation` + GM workspace**：`ToUnderlyingArguments(..., uint8_t *workspace)` 的指针为**非 gm**，**禁止**将 `GM_ADDR`（`__gm__`）`reinterpret_cast` 成 `uint8_t *`（bisheng 报错）。应在 Device 侧按头文件中的字段顺序**手写** `typename MatmulKernel::Params{ ..., userWs, epilogueParams }`，其中 `userWs` 为 `GetUserWorkspace` 的 `GM_ADDR`，`BlockEpilogue::Params` 的首指针同为该 `GM_ADDR`（与 `matmul_activation.hpp` 中 `ToUnderlyingArguments` 逻辑一致）。
- **OPC 拷贝 kernel 源**：`prepare_compile_from_config` 常只拷贝 `op_kernel/` 下顶层 `*.*`；仅放在子目录的自定义头可能不进编译临时目录。自定义 Tile 头文件宜放在 **`op_kernel/` 根目录**（如 `tile_xxx.hpp`）。
- **Epilogue 向量长与矩阵规模**：固定模板 `COMPUTE_LENGTH` 的 `TileElemWise*` 与**过小**的 \(M\times N\) 或尾块组合时，运行期可能在 AIV 上报 **UB 越界**（如 `VEC instruction error: the ub address out of bounds`）。`test_aclnn` 形状宜取 **L1 Tile M（如 128）、N（如 256）的整数倍**；若 `AscendC::Tanh` 异常，可用 **Exp/Muls/Adds/Div** 实现 \(\tanh\)（与 `TileElemWiseSilu` 同风格）。
- **MatmulEpilogue 与独立输出缓冲**：`MatmulEpilogue::ToUnderlyingArguments` 将 epilogue 的 X/D 设为同一指针；若需要 **Y = A@B − X** 且 **y 与 x3 为不同 GM**，须在 Device 侧**手动构造** `MatmulKernel::Params` / `BlockEpilogue::Params`（`ptrX=x3`，`ptrD=y`），勿照搬仅含 `Arguments` 的 Host 适配器路径。
