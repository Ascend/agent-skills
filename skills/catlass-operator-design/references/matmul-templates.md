# Catlass 矩阵乘法模板总结

## 样例模板清单

### 00_basic_matmul
- 理论模板：`Common模板`
- 工程优化：`流水优化（Multi Buffer）`
- 关键交付件
  - host：[00_basic_matmul](catlass/examples/00_basic_matmul/basic_matmul.cpp)
  - kernel：[basic_matmul.hpp](catlass/include/catlass/gemm/kernel/basic_matmul.hpp)
  - blockMmad：[block_mmad_pingpong.hpp](catlass/include/catlass/gemm/block/block_mmad_pingpong.hpp)
- dispatchPolicy：`MmadAtlasA2Pingpong`

### 04_padding_matmul
- 理论模板：`Common模板`
- 工程优化：
  - `流水优化（Multi Buffer）`
  - `读取带宽优化（padding）- PaddingMatrixND`
- 关键交付件
  - host：[04_padding_matmul](catlass/examples/04_padding_matmul/padding_matmul.cpp)
  - kernel：[padding_matmul.hpp](catlass/include/catlass/gemm/kernel/padding_matmul.hpp)
  - blockMmad：[block_mmad_pingpong.hpp](catlass/include/catlass/gemm/block/block_mmad_pingpong.hpp)
- dispatchPolicy：`MmadAtlasA2Pingpong`

### 06_optimized_matmul
- 理论模板：`Common模板`
- 工程优化：
  - `流水优化（Multi Buffer）`
  - `流水优化（Preload）`
  - `读取带宽优化（Padding）- PaddingMatrixNZ`
  - `读取带宽优化（ShuffleK）`
  - `读取带宽优化（小M下指令替换）`（需要修改样例使能）
- 关键交付件
  - host：[06_optimized_matmul](catlass/examples/06_optimized_matmul/optimized_matmul.cpp)
  - kernel：[optimized_matmul.hpp](catlass/include/catlass/gemm/kernel/optimized_matmul.hpp)
  - Padding前处理组件：[padding_matmul.hpp](catlass/include/catlass/gemm/kernel/padding_matmul.hpp)
  - blockMmad：[block_mmad_preload.hpp](catlass/include/catlass/gemm/block/block_mmad_preload.hpp)
- dispatchPolicy：`MmadAtlasA2Preload`

### 09_splitk_matmul
- 理论模板：`多核切K模板 MultiCoreSplitK`
- 工程优化：`流水优化（Multi Buffer）`
- 关键交付件
  - host：[09_splitk_matmul](catlass/examples/09_splitk_matmul/optimized_matmul.cpp)
  - kernel：[splitk_matmul.hpp](catlass/include/catlass/gemm/kernel/splitk_matmul.hpp)
  - blockMmad：[block_mmad_pingpong.hpp](catlass/include/catlass/gemm/block/block_mmad_pingpong.hpp)
- dispatchPolicy：`MmadAtlasA2Pingpong`

### 21_basic_matmul_preload_zN
- 理论模板：`Common模板`
- 工程优化：
  - `流水优化（Multi Buffer）`
  - `流水优化（Preload）`
  - `读取带宽优化（ShuffleK）`
- 关键交付件
  - host：[21_basic_matmul_preload_zN](catlass/examples/09_splitk_matmul/basic_matmul_preload_zN.cpp)
  - kernel：[basic_matmul_preload.hpp](catlass/include/catlass/gemm/kernel/basic_matmul_preload.hpp)
  - blockMmad：[block_mmad_preload.hpp](catlass/include/catlass/gemm/block/block_mmad_preload.hpp)
- dispatchPolicy：`MmadAtlasA2Preload`

### 22_padding_splitk_matmul
- 理论模板：`多核切K模板 MultiCoreSplitK`
- 工程优化：
  - `流水优化（Multi Buffer）`
  - `读取带宽优化（padding）- PaddingMatrixND`
- 关键交付件
  - host：[22_padding_splitk_matmul](catlass/examples/22_padding_splitk_matmul/padding_splitk_matmul.cpp)
  - kernel：[padding_splitk_matmul.hpp](catlass/include/catlass/gemm/kernel/padding_splitk_matmul.hpp)
  - Padding前处理组件：[padding_matmul.hpp](catlass/include/catlass/gemm/kernel/padding_matmul.hpp)
  - SplitkReduceAdd后处理组件：[splitk_matmul.hpp](catlass/include/catlass/gemm/kernel/splitk_matmul.hpp)
  - blockMmad：[block_mmad_pingpong.hpp](catlass/include/catlass/gemm/block/block_mmad_pingpong.hpp)
- dispatchPolicy：`MmadAtlasA2Pingpong`

### 25_matmul_full_loadA
- 理论模板：`Common模板`
- 工程优化：
  - `流水优化（Multi Buffer）`(全载的A矩阵在L1上不使用多buffer)
  - `读取带宽优化（L1常驻）`
- 关键交付件
  - host：[25_matmul_full_loadA](catlass/examples/09_splitk_matmul/25_matmul_full_loadA.cpp)
  - kernel：[matmul_full_loadA.hpp](catlass/include/catlass/gemm/kernel/matmul_full_loadA.hpp)
  - blockMmad：[block_mmad_pingpong_full_loadA.hpp](catlass/include/catlass/gemm/block/block_mmad_pingpong_full_loadA.hpp)
- dispatchPolicy：`MmadAtlasA2FullLoadA`
- BlockScheduler：`GemmIdentityBlockSwizzleL1FullLoad`

### 31_small_matmul
- 理论模板：`Common模板`
- 工程优化：
  - `流水优化（Multi Buffer）`
  - `Scalar开销消减`
- 关键交付件
  - host：[31_small_matmul](catlass/examples/31_small_matmul/small_matmul.cpp)
  - kernel：[small_matmul.hpp](catlass/include/catlass/gemm/kernel/small_matmul.hpp)
  - blockMmad：[block_mmad_small.hpp](catlass/include/catlass/gemm/block/block_mmad_small.hpp)
- dispatchPolicy：`MmadAtlasA2Small`

### 34_single_core_splitk_matmul
- 理论模板：`单核切K模板 SingleCoreSplitK`
- 工程优化：
  - `流水优化（Multi Buffer）`
  - `读取带宽优化（Padding）- PaddingMatrixNZ`
  - `写出带宽优化`
- 关键交付件
  - host：[34_single_core_splitk_matmul](catlass/examples/34_single_core_splitk_matmul/single_core_splitk.cpp)
  - kernel：[single_core_slicek_matmul.hpp](catlass/include/catlass/gemm/kernel/single_core_slicek_matmul.hpp)
  - Padding前处理组件和RemovePaddingNDAndCast后处理组件：[padding_matmul.hpp](catlass/include/catlass/gemm/kernel/padding_matmul.hpp)
  - blockMmad：[block_mmad_single_core_splitk.hpp](catlass/include/catlass/gemm/block/block_mmad_single_core_splitk.hpp)
- dispatchPolicy：`MmadAtlasA2SingleCoreSplitk`
- BlockScheduler：`SingleCoreSplitkGemmIdentityBlockSwizzle`

## 理论模板清单

### Common模板
- 采用 $M$、$N$ 方向分核，按照$m_1$、$n_1$切分
- 产生$rac{MN}{m_1n_1}$个基本任务块、分配给AIC核完成搬运和计算
- 每个基本任务块需要搬运$m_1K+Kn_1$的数据、计算得到$m_1n_1$的结果并搬出

### 多核切K模板 MultiCoreSplitK
- 在$M$、$N$方向切分的基础上，引入$K$轴切分
- 产生$rac{MNK}{m_1n_1k}$个基本任务块、分配给AIC核完成搬运和计算
- 每个基本任务块需要搬运$m_1k+kn_1$的数据、计算得到$m_1n_1$的结果并搬出
- 更易负载均衡，但写出数据量增加，并产生后处理ReduceAdd的开销

### 单核切K模板 SingleCoreSplitK
- 为了减少读取数据量，进一步增大抽象上的$m_1$、$n_1$
- 考虑将$m_1k_1$的tile块直接与对应的所有$k_1n_1$的tile块完成计算
- 输出$m_0n_0$的tile块没法在$L0C$常驻累加，需要及时搬出，通过`atomicAdd`在`GM`上累加
- 搬入数据量减少，写出数据量增加

## 工程优化清单

### 流水优化（Multi Buffer）
- 在L1/L0A/L0B/L0C上启用多buffer，使得流水尽可能并行
- 提升效率，所有blockMmad组件均使能

### 流水优化（Preload）
- 针对GM->L1过程，读取当前轮次的数据时，计算上一轮读取的数据
- 减缓MTE2上的搬运空泡
- 对应dispatchPolicy：`MmadAtlasA2Preload`、`MmadAtlasA2PreloadAsync`等

### 读取带宽优化（Padding）
- 针对Stride非512B对齐、搬运指令限制、ND2NZ随路转换带宽损失等问题
- 三种重排方式：`PaddingMatrixND`、`PaddingMatrixBlockND`、`PaddingMatrixNZ`

### 读取带宽优化（ShuffleK）
- 根据$CoreIdx$来偏移起始搬运序号$j$，从时间上错开，避免同地址访问冲突
- 减少数据读取冲突，提高读取带宽

### 读取带宽优化（小M下指令替换）
- 当$M$很小时（例如$M$ < 8），采用`for`循环每次搬运一行，并在每一行调用`DataCopy`进行多次搬运

### 读取带宽优化（L1常驻）
- 采用tile块常驻L1的方式，减少tile块数据的重复读取，等效提升了读取带宽
- 例如`25_matmul_full_loadA`和`34_single_core_splitk_matmul`

### Scalar开销消减
- 对于小Shape场景，消减冗余的scalar计算
- kernel内不使用 BlockScheduler，手动计算每个物理核对应的任务块
- 消除基本块循环，简化offset相关计算

### 写出带宽优化
- 针对写出时`dstStride`未进行512B对齐、NZ2ND随路格式转换带宽损失等问题
- 四种重排方式，使用局部或全量workSpace

## 模板选择指南

1. 先尝试基于[00_basic_matmul]进行TileShape调优并获得**性能基线**

2. 依次识别是否满足各模板适合场景：
   - [31_small_matmul]：基本任务块小于AIC数，且$K$轴较小
   - [09_splitk_matmul]或[22_padding_splitk_matmul]：基本任务块小于一半AIC数且$K$轴够大，或基本任务块小于3块且$K$轴不会小
   - [06_optimized_matmul]和[21_basic_matmul_preload_zN]：泛化性更强，适用于剩余场景

3. 当Stride非512B对齐时可以考虑使用Padding前处理，但需要考虑Padding带来的开销以及MIX算子编译启动的开销

4. 全载特性的使用[25_matmul_full_loadA]和单核切K方案[34_single_core_splitk_matmul]的适用场景待完善