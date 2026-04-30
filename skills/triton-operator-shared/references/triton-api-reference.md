# Triton-Ascend API 列表 (A2/A3)

> Triton 3.2.0, triton-ascend 后端
> 平台: Ascend 910A2 / 910A3 (910B1 / 910B3)

---

## 1. triton 顶层接口

### 1.1 JIT 编译

| API | 签名 | 说明 |
|-----|------|------|
| `triton.jit` | `jit(fn=None, *, version=None, repr=None, launch_metadata=None, do_not_specialize=None, do_not_specialize_on_alignment=None, debug=None, noinline=None, options=None)` | 将 Python 函数 JIT 编译为 Triton kernel |
| `triton.compile` | `compile(src, target=None, options=None)` | 从源码编译 Triton kernel |

### 1.2 自动调优

| API | 签名 | 说明 |
|-----|------|------|
| `triton.autotune` | `autotune(configs, key, hints=None, prune_configs_by=None, reset_to_zero=None, restore_value=None, pre_hook=None, post_hook=None, warmup=None, rep=None, use_cuda_graph=False, do_bench=None, auto_profile_dir=None)` | 通过基准测试多组 Config 自动选择最优 kernel 配置 |
| `triton.heuristics` | `heuristics(values)` | 基于运行时参数启发式推断编译期常量 |
| `triton.Config` | `Config(kwargs, num_warps=4, num_stages=2, num_ctas=1, num_buffers_warp_spec=0, num_consumer_groups=0, reg_dec_producer=0, reg_inc_consumer=0, maxnreg=None, pre_hook=None, force_simt_template=False, enable_linearize=False, **bishengir_options)` | kernel 启动配置参数集 |

### 1.3 工具函数

| API | 签名 | 说明 |
|-----|------|------|
| `triton.reinterpret` | `reinterpret(tensor, dtype)` | 将张量数据按新类型重新解释，不做数值转换 |
| `triton.cdiv` | `cdiv(x, div)` | 向上取整除法: ceil(x / div) |
| `triton.next_power_of_2` | `next_power_of_2(n)` | 返回 >= n 的最小 2 的幂 |

---

## 2. triton.language (tl) - 编程模型

| API | 签名 | 说明 |
|-----|------|------|
| `tl.program_id` | `program_id(axis)` | 返回当前 program (block) 在指定轴上的索引 |
| `tl.num_programs` | `num_programs(axis)` | 返回指定轴上 program (block) 的总数量 |

---

## 3. triton.language (tl) - 内存操作

| API | 签名 | 说明 |
|-----|------|------|
| `tl.load` | `load(pointer, mask=None, other=None, boundary_check=(), padding_option='', cache_modifier='', eviction_policy='', volatile=False, care_padding=True)` | 从 `pointer` 指向的内存加载张量。`mask` 控制加载哪些元素，`other` 为遮蔽位置的默认值 |
| `tl.store` | `store(pointer, value, mask=None, boundary_check=(), cache_modifier='', eviction_policy='')` | 将张量写入 `pointer` 指向的内存。`mask` 控制写入哪些元素 |
| `tl.make_block_ptr` | `make_block_ptr(base, shape, strides, offsets, block_shape, order)` | 创建分块指针，用于带显式 shape/stride 布局的分块内存访问 |
| `tl.multibuffer` | `multibuffer(src, size)` | 创建张量的多缓冲副本，提升内存级并行度 |

---

## 4. triton.language (tl) - 张量描述符

| API | 签名 | 说明 |
|-----|------|------|
| `tl.make_tensor_descriptor` | `make_tensor_descriptor(base, shape, strides, block_shape)` | 创建基于描述符的内存访问张量描述符 |
| `tl.load_tensor_descriptor` | `load_tensor_descriptor(desc, offsets)` | 从张量描述符的指定偏移位置加载数据 |
| `tl.store_tensor_descriptor` | `store_tensor_descriptor(desc, offsets, value)` | 向张量描述符的指定偏移位置写入数据 |

---

## 5. triton.language (tl) - 张量构造

| API | 签名 | 说明 |
|-----|------|------|
| `tl.arange` | `arange(start, end)` | 创建值在 [start, end) 范围内的 1D 张量，长度必须为 2 的幂 |
| `tl.full` | `full(shape, value, dtype)` | 创建指定形状、用 `value` 填充的张量 |
| `tl.zeros` | `zeros(shape, dtype)` | 创建指定形状的全零张量 |
| `tl.zeros_like` | `zeros_like(input)` | 创建与 `input` 形状和类型相同的全零张量 |

---

## 6. triton.language (tl) - 张量操作

| API | 签名 | 说明 |
|-----|------|------|
| `tl.reshape` | `reshape(input, *shape, can_reorder=False)` | 张量变形。`can_reorder=True` 允许内存重排以提升性能 |
| `tl.view` | `view(input, *shape)` | (已废弃，使用 `reshape(can_reorder=True)`) 以新形状查看张量 |
| `tl.expand_dims` | `expand_dims(input, axis)` | 在指定轴插入大小为 1 的新维度 |
| `tl.permute` | `permute(input, *dims)` | 按给定顺序重排维度 |
| `tl.trans` | `trans(input, *dims)` | 转置张量维度 |
| `tl.cat` | `cat(input, other, can_reorder=False)` | 沿新的最后维度拼接两个张量。`can_reorder=True` 允许元素重排 |
| `tl.broadcast` | `broadcast(input, other)` | 将两个张量广播到相同形状 |
| `tl.broadcast_to` | `broadcast_to(input, *shape)` | 将张量广播到目标形状 |
| `tl.ravel` | `ravel(input)` | 展平为 1D 张量 |
| `tl.flip` | `flip(ptr, dim=-1)` | 沿指定维度翻转元素 |
| `tl.split` | `split(a)` | 沿最后维度（必须大小为 2）将张量拆分为两个。`join` 的逆操作 |
| `tl.join` | `join(a, b)` | 沿新的最后维度合并两个张量。`split` 的逆操作 |
| `tl.interleave` | `interleave(*args)` | 逐元素交错多个张量 |
| `tl.extract_slice` | `extract_slice(ful, offsets, sizes, strides)` | 从 `ful` 中按给定偏移/大小/步长提取子张量切片 |
| `tl.insert_slice` | `insert_slice(ful, sub, offsets, sizes, strides)` | 将 `sub` 按给定偏移/大小/步长插入到 `ful` |

---

## 7. triton.language (tl) - 索引

| API | 签名 | 说明 |
|-----|------|------|
| `tl.gather` | `gather(src, index, axis)` | 沿 `axis` 按 `index` 指定的位置从 `src` 中收集元素 |
| `tl.get_element` | `get_element(src, indice)` | 从 `src` 中获取指定索引的单个元素 |
| `tl.index_select` | `index_select(src, idx, bound, lstdim_blksiz, offsets, numels)` | 按索引张量从 `src` 中选取元素（Ascend 专用签名） |
| `tl.swizzle2d` | `swizzle2d(x, y, size_x, size_y)` | 计算 2D swizzle 索引，用于避免共享内存 bank 冲突 |
| `tl.advance` | `advance(base, offsets)` | 将分块指针按给定偏移量前进 |

---

## 8. triton.language (tl) - 线性代数

| API | 签名 | 说明 |
|-----|------|------|
| `tl.dot` | `dot(input, other, acc=None, input_precision=None, allow_tf32=None, max_num_imprecise_acc=None, out_dtype=float32)` | 2D 输入块的矩阵乘法。可选累加到 `acc` |
| `tl.dot_scaled` | `dot_scaled(lhs, lhs_scale, lhs_format, rhs, rhs_scale, rhs_format, acc=None, out_dtype=float32, lhs_k_pack=True, rhs_k_pack=True)` | 带 FP8 缩放的矩阵乘法。`*_format` 控制缩放布局 (如 "e4m3"、"e5m2") |

---

## 9. triton.language (tl) - 算术运算

| API | 签名 | 说明 |
|-----|------|------|
| `tl.add` | `add(x, y, sanitize_overflow=True)` | 逐元素加法。`sanitize_overflow` 控制整数溢出行为 |
| `tl.fma` | `fma(x, y, z)` | 融合乘加: x * y + z |
| `tl.umulhi` | `umulhi(x, y)` | 无符号乘法，返回结果的高位 |
| `tl.where` | `where(condition, x, y)` | 逐元素条件选择：条件为真选 `x`，否则选 `y` |
| `tl.abs` | `abs(x)` | 逐元素取绝对值 |

---

## 10. triton.language (tl) - 类型转换

| API | 签名 | 说明 |
|-----|------|------|
| `tl.cast` | `cast(input, dtype, fp_downcast_rounding=None, bitcast=False, overflow_mode=None)` | 类型转换。`bitcast=True` 直接重解释比特位不做数值转换；`fp_downcast_rounding` 控制浮点降精度舍入方式；`overflow_mode` 控制整数溢出行为 |

---

## 11. triton.language (tl) - 规约

| API | 签名 | 说明 |
|-----|------|------|
| `tl.sum` | `sum(input, axis=None)` | 沿轴求和规约 |
| `tl.max` | `max(input, axis=None)` | 沿轴求最大值规约 |
| `tl.min` | `min(input, axis=None)` | 沿轴求最小值规约 |
| `tl.argmax` | `argmax(input, axis)` | 沿轴返回最大元素的索引 |
| `tl.argmin` | `argmin(input, axis)` | 沿轴返回最小元素的索引 |
| `tl.xor_sum` | `xor_sum(input, axis=None, keep_dims=False)` | 沿轴异或规约 |
| `tl.reduce` | `reduce(input, axis, combine_fn, keep_dims=False)` | 使用自定义组合函数的通用规约 |

---

## 12. triton.language (tl) - 扫描

| API | 签名 | 说明 |
|-----|------|------|
| `tl.associative_scan` | `associative_scan(input, axis, combine_fn, reverse=False)` | 使用可结合组合函数的前缀扫描（inclusive scan） |
| `tl.cumsum` | `cumsum(input, axis)` | 沿轴累加求和 |
| `tl.cumprod` | `cumprod(input, axis)` | 沿轴累乘 |

---

## 13. triton.language (tl) - 排序

| API | 签名 | 说明 |
|-----|------|------|
| `tl.sort` | `sort(ptr, dim=-1, descending=False)` | 沿维度排序 |
| `tl.topk` | `topk(input, k)` | 返回最大的 k 个值及其索引 |

---

## 14. triton.language (tl) - 统计

| API | 签名 | 说明 |
|-----|------|------|
| `tl.histogram` | `histogram(input, num_bins)` | 对整数输入计算 `num_bins` 个区间的直方图 |

---

## 15. triton.language (tl) - 神经网络

| API | 签名 | 说明 |
|-----|------|------|
| `tl.softmax` | `softmax(input)` | 数值稳定的 softmax（沿最后维度） |
| `tl.sigmoid` | `sigmoid(input)` | 逐元素 sigmoid: 1 / (1 + exp(-x)) |

---

## 16. triton.language (tl) - 比较

| API | 签名 | 说明 |
|-----|------|------|
| `tl.maximum` | `maximum(x, y, propagate_nan=NONE)` | 逐元素取两个张量的最大值 |
| `tl.minimum` | `minimum(x, y, propagate_nan=NONE)` | 逐元素取两个张量的最小值 |
| `tl.clamp` | `clamp(x, min, max, propagate_nan=NONE)` | 将值截断到 [min, max] 范围 |

---

## 17. triton.language (tl) - 原子操作

| API | 签名 | 说明 |
|-----|------|------|
| `tl.atomic_add` | `atomic_add(pointer, val, mask=None, sem=None, scope=None)` | 原子加。`sem` 控制内存序 (如 "acquire"、"release"、"acq_rel") |
| `tl.atomic_and` | `atomic_and(pointer, val, mask=None, sem=None, scope=None)` | 原子按位与 |
| `tl.atomic_or` | `atomic_or(pointer, val, mask=None, sem=None, scope=None)` | 原子按位或 |
| `tl.atomic_xor` | `atomic_xor(pointer, val, mask=None, sem=None, scope=None)` | 原子按位异或 |
| `tl.atomic_xchg` | `atomic_xchg(pointer, val, mask=None, sem=None, scope=None)` | 原子交换 |
| `tl.atomic_max` | `atomic_max(pointer, val, mask=None, sem=None, scope=None)` | 原子取最大值 |
| `tl.atomic_min` | `atomic_min(pointer, val, mask=None, sem=None, scope=None)` | 原子取最小值 |
| `tl.atomic_cas` | `atomic_cas(pointer, cmp, val, sem=None, scope=None)` | 原子比较并交换：当前值等于 `cmp` 时写入 `val` |

---

## 18. triton.language (tl) - 同步

| API | 签名 | 说明 |
|-----|------|------|
| `tl.debug_barrier` | `debug_barrier()` | 插入屏障，同步 block 内所有线程 |
| `tl.sync_block_set` | `sync_block_set(sender, receiver, event_id)` | 设置 block 间通信的同步事件 |
| `tl.sync_block_wait` | `sync_block_wait(sender, receiver, event_id)` | 等待来自其他 block 的同步事件 |
| `tl.sync_block_all` | `sync_block_all(mode, event_id)` | 所有参与 block 间的屏障同步 |

---

## 19. triton.language (tl) - 调试

| API | 签名 | 说明 |
|-----|------|------|
| `tl.device_print` | `device_print(prefix, *args, hex=False)` | 设备端运行时打印张量值 |
| `tl.device_assert` | `device_assert(cond, msg='')` | 设备端断言，失败时触发 trap |
| `tl.static_assert` | `static_assert(cond, msg='')` | 编译期断言 |
| `tl.static_print` | `static_print(*values)` | 编译期打印 |

---

## 20. triton.language (tl) - 编译器提示

| API | 签名 | 说明 |
|-----|------|------|
| `tl.multiple_of` | `multiple_of(input, values)` | 提示 `input` 每个元素是对应 `values` 值的倍数 |
| `tl.max_contiguous` | `max_contiguous(input, values)` | 提示最大连续内存区域大小 |
| `tl.max_constancy` | `max_constancy(input, values)` | 提示最大常量值区域大小 |
| `tl.assume` | `assume(cond)` | 假设条件恒为真，用于编译器优化 |
| `tl.compile_hint` | `compile_hint(ptr, hint_name, hint_val=None)` | 为指针提供命名的编译提示 |

---

## 21. triton.language (tl) - 随机数生成

| API | 签名 | 说明 |
|-----|------|------|
| `tl.philox` | `philox(seed, c0, c1, c2, c3, n_rounds=10)` | 底层 Philox 伪随机数生成器，运行 `n_rounds` 轮并返回 4 个状态张量 |
| `tl.rand` | `rand(seed, offset, dtype=float32)` | 生成 [0, 1) 均匀分布随机浮点数 |
| `tl.rand4x` | `rand4x(seed, offset, dtype=float32)` | 4 路并行生成 [0, 1) 均匀分布随机浮点数 |
| `tl.randint` | `randint(seed, offset, low, high, dtype=int32)` | 生成 [low, high) 范围随机整数 |
| `tl.randint4x` | `randint4x(seed, offset, low, high, dtype=int32)` | 4 路并行生成 [low, high) 范围随机整数 |
| `tl.randn` | `randn(seed, offset, dtype=float32)` | 生成标准正态分布随机浮点数 (均值=0, 标准差=1) |
| `tl.randn4x` | `randn4x(seed, offset, dtype=float32)` | 4 路并行生成标准正态分布随机浮点数 |
| `tl.pair_uniform_to_normal` | `pair_uniform_to_normal(u1, u2)` | Box-Muller 变换：将两个均匀分布采样转换为一个正态分布采样 |
| `tl.uint_to_uniform_float` | `uint_to_uniform_float(x)` | 将无符号整数转换为 [0, 1) 均匀分布浮点数 |

---

## 22. triton.language (tl) - 高级接口

| API | 签名 | 说明 |
|-----|------|------|
| `tl.inline_asm_elementwise` | `inline_asm_elementwise(asm, constraints, args, dtype, is_pure, pack)` | 逐元素内联汇编。`pack` 控制 SIMD 宽度 |

---

## 23. triton.language (tl) - 数学函数

可通过 `tl.函数名()` 或 `tl.math.函数名()` 两种方式调用。

| API | 签名 | 说明 |
|-----|------|------|
| `tl.sqrt` | `sqrt(x)` | 平方根 |
| `tl.sqrt_rn` | `sqrt_rn(x)` | 平方根（向偶数舍入） |
| `tl.rsqrt` | `rsqrt(x)` | 平方根倒数: 1 / sqrt(x) |
| `tl.exp` | `exp(x)` | 指数函数（底数 e） |
| `tl.exp2` | `exp2(x)` | 指数函数（底数 2） |
| `tl.log` | `log(x)` | 自然对数 |
| `tl.log2` | `log2(x)` | 以 2 为底的对数 |
| `tl.sin` | `sin(x)` | 正弦 |
| `tl.cos` | `cos(x)` | 余弦 |
| `tl.tanh` | `tanh(x)` | 双曲正切 |
| `tl.erf` | `erf(x)` | 误差函数 |
| `tl.ceil` | `ceil(x)` | 向上取整（向 +inf 方向） |
| `tl.floor` | `floor(x)` | 向下取整（向 -inf 方向） |
| `tl.div_rn` | `div_rn(x, y)` | 除法（向偶数舍入） |
| `tl.fdiv` | `fdiv(x, y, ieee_rounding=False)` | 浮点除法，可选 IEEE 舍入模式 |

---

## 24. triton.language.extra.ascend.libdevice - 基础数学

Ascend 专用数学库。导入方式: `from triton.language.extra.ascend import libdevice`

| API | 签名 | 说明 |
|-----|------|------|
| `libdevice.abs` | `abs(x)` | 绝对值 |
| `libdevice.ceil` | `ceil(x)` | 向上取整（向 +inf 方向） |
| `libdevice.copysign` | `copysign(x, y)` | 返回 `x` 的值带上 `y` 的符号 |
| `libdevice.div_rn` | `div_rn(x, y)` | 除法（向偶数舍入） |
| `libdevice.div_rz` | `div_rz(x, y)` | 除法（向零截断） |
| `libdevice.erf` | `erf(x)` | 误差函数 |
| `libdevice.exp` | `exp(x)` | 指数函数（底数 e） |
| `libdevice.exp2` | `exp2(x)` | 指数函数（底数 2） |
| `libdevice.expm1` | `expm1(x)` | exp(x) - 1，对较小 x 精度更高 |
| `libdevice.fdiv` | `fdiv(x, y, ieee_rounding=False)` | 浮点除法，可选 IEEE 舍入模式 |
| `libdevice.floor` | `floor(x)` | 向下取整（向 -inf 方向） |
| `libdevice.fma` | `fma(x, y, z)` | 融合乘加: x * y + z |
| `libdevice.fmod` | `fmod(x, y)` | 浮点取余 |
| `libdevice.hypot` | `hypot(x, y)` | sqrt(x^2 + y^2) |
| `libdevice.ilogb` | `ilogb(x)` | 整数二进制对数（浮点值的指数部分） |
| `libdevice.ldexp` | `ldexp(x, y)` | x * 2^y |
| `libdevice.log` | `log(x)` | 自然对数 |
| `libdevice.log10` | `log10(x)` | 以 10 为底的对数 |
| `libdevice.log1p` | `log1p(x)` | log(1 + x)，对较小 x 精度更高 |
| `libdevice.log2` | `log2(x)` | 以 2 为底的对数 |
| `libdevice.nearbyint` | `nearbyint(x)` | 四舍五入到最近整数（返回浮点数） |
| `libdevice.nextafter` | `nextafter(x, y)` | 返回 x 朝 y 方向的下一个可表示浮点数 |
| `libdevice.pow` | `pow(x, y)` | x 的 y 次幂 |
| `libdevice.reciprocal` | `reciprocal(x)` | 1 / x |
| `libdevice.round` | `round(x)` | 四舍五入（0.5 远离零方向） |
| `libdevice.rsqrt` | `rsqrt(x)` | 平方根倒数: 1 / sqrt(x) |
| `libdevice.signbit` | `signbit(x)` | x 为负数返回 1，否则返回 0 |
| `libdevice.sqrt` | `sqrt(x)` | 平方根 |
| `libdevice.sqrt_rn` | `sqrt_rn(x)` | 平方根（向偶数舍入） |
| `libdevice.trunc` | `trunc(x)` | 向零截断取整 |
| `libdevice.umulhi` | `umulhi(x, y)` | 无符号乘法，返回高位 |

---

## 25. triton.language.extra.ascend.libdevice - 三角函数

| API | 签名 | 说明 |
|-----|------|------|
| `libdevice.acos` | `acos(x)` | 反余弦。输入范围: [-1, 1] |
| `libdevice.acosh` | `acosh(x)` | 反双曲余弦。输入范围: x >= 1 |
| `libdevice.asin` | `asin(x)` | 反正弦。输入范围: [-1, 1] |
| `libdevice.asinh` | `asinh(x)` | 反双曲正弦 |
| `libdevice.atan` | `atan(x)` | 反正切 |
| `libdevice.atan2` | `atan2(x, y)` | 双参数反正切 x/y，根据符号确定象限 |
| `libdevice.atanh` | `atanh(x)` | 反双曲正切。输入范围: (-1, 1) |
| `libdevice.cos` | `cos(x)` | 余弦 |
| `libdevice.cosh` | `cosh(x)` | 双曲余弦 |
| `libdevice.sin` | `sin(x)` | 正弦 |
| `libdevice.sinh` | `sinh(x)` | 双曲正弦 |
| `libdevice.tan` | `tan(x)` | 正切 |
| `libdevice.tanh` | `tanh(x)` | 双曲正切 |

---

## 26. triton.language.extra.ascend.libdevice - 特殊函数

| API | 签名 | 说明 |
|-----|------|------|
| `libdevice.cyl_bessel_i0` | `cyl_bessel_i0(x)` | 第一类修正贝塞尔函数，0 阶 |
| `libdevice.erfinv` | `erfinv(x)` | 反误差函数。输入范围: (-1, 1) |
| `libdevice.gamma` | `gamma(x)` | Gamma 函数 |
| `libdevice.lgamma` | `lgamma(x)` | 对数 Gamma 函数: log(|Gamma(x)|) |

---

## 27. triton.language.extra.ascend.libdevice - 检查函数

| API | 签名 | 说明 |
|-----|------|------|
| `libdevice.isinf` | `isinf(x)` | x 为 +inf 或 -inf 时返回 1，否则返回 0 |
| `libdevice.isnan` | `isnan(x)` | x 为 NaN 时返回 1，否则返回 0 |

---

## 28. triton.language.extra.ascend.libdevice - 神经网络

| API | 签名 | 说明 |
|-----|------|------|
| `libdevice.relu` | `relu(x)` | ReLU: max(0, x) |

---

## 29. triton.language.extra.ascend.libdevice - Ascend 专有操作

| API | 签名 | 说明 |
|-----|------|------|
| `libdevice.flip` | `flip(x, dim)` | 沿指定维度翻转元素 |
| `libdevice.gather_out_to_ub` | `gather_out_to_ub(src, index_tile, index_boundary, dim, src_stride, index_shape, offsets, other=None)` | 将全局内存输出 Gather 到 UB (统一缓冲区)，用于 Ascend NPU 数据搬运优化 |
| `libdevice.index_put` | `index_put(ptr, index, value, dim, dst_shape, dst_offset)` | 按索引位置将值写入目标张量 |
| `libdevice.index_select_simd` | `index_select_simd(src, dim, index, src_shape, src_offset, read_shape)` | 利用 Ascend 向量核心 SIMD 优化的索引选择 |
| `libdevice.set_element` | `set_element(tensor, indices, values)` | 在给定索引处设置张量元素值 |

---

## 30. triton.testing

| API | 签名 | 说明 |
|-----|------|------|
| `triton.testing.Benchmark` | `Benchmark(x_names, x_vals, line_arg, line_vals, line_names, plot_name, args, xlabel='', ylabel='', x_log=False, y_log=False, styles=None)` | 定义参数扫描的基准测试配置 |
| `triton.testing.perf_report` | `perf_report(benchmarks)` | 装饰器，根据基准测试结果生成性能报告 |
| `triton.testing.do_bench` | `do_bench(fn, warmup=25, rep=100, grad_to_none=None, quantiles=None, return_mode='mean')` | 测量可调用对象的执行时间，返回耗时 (ms) |
| `triton.testing.do_bench_npu` | `do_bench_npu(fn, warmup=5, active=30, prof_dir=None, keep_res=False)` | NPU 专用基准测试，使用 msprof 采集性能数据，返回耗时 (ms) |
| `triton.testing.assert_close` | `assert_close(x, y, atol=None, rtol=None, err_msg='')` | 断言两个张量在容差范围内逐元素相近 |

---

## 31. triton.runtime

| API | 签名 | 说明 |
|-----|------|------|
| `triton.runtime.libentry` | `libentry()` | 库入口 kernel 装饰器，Ascend 上自动缓存。从 `triton.runtime.libentry` 导入 |
| `triton.runtime.libtuner` | `libtuner(configs, key, prune_configs_by=None, reset_to_zero=None, restore_value=None, pre_hook=None, post_hook=None, warmup=25, rep=100, use_cuda_graph=False)` | 自动调优 + 库入口缓存组合装饰器，Ascend 专用。从 `triton.runtime.libentry` 导入 |
| `triton.runtime.JITFunction` | `JITFunction(fn, version=None, do_not_specialize=None, ...)` | 核心 JIT 函数类，由 `@triton.jit` 装饰器创建 |
| `triton.runtime.Config` | `Config(kwargs, num_warps=4, num_stages=2, ...)` | 自动调优的 kernel 配置 |
| `triton.runtime.Autotuner` | `Autotuner(fn, arg_names, configs, key, ...)` | 自动调优器类，管理基于基准测试的配置选择 |
| `triton.runtime.Heuristics` | `Heuristics(fn, arg_names, values)` | 启发式参数推断类 |
| `triton.runtime.AutoTilingTuner` | `AutoTilingTuner(fn, arg_names, configs, key, ...)` | Ascend 专用自动 Tiling 调优器，自动生成 tiling 配置 |
| `triton.runtime.TileGenerator` | `TileGenerator(kernel_meta)` | Ascend 专用 Tile 生成器，计算最优分块参数 |

---

## 32. triton.backends.ascend

### 32.1 后端编译器

导入方式: `from triton.backends.ascend.compiler import ...`

| API | 说明 |
|-----|------|
| `AscendBackend` | Ascend 后端，实现 Triton 编译流水线各阶段 (TTIR -> Linalg -> LLIR -> 二进制) |
| `AscendAttrsDescriptor` | Ascend kernel 参数属性描述符（整除性、对齐、常量属性等） |
| `NPUOptions` | NPU 编译选项。主要字段: `num_warps`、`num_stages`、`num_ctas`、`compile_mode`、`force_simt_template`、`force_simt_only`、`sanitize_overflow`、`enable_linearize`、`enable_nd2nz_on_vector`、`enable_select_analysis`、`enable_hivm_auto_cv_balance`、`disable_auto_inject_block_sync`、`enable_auto_bind_sub_block`、`inject_barrier_all`、`inject_block_all`、`multibuffer`、`set_workspace_multibuffer`、`parallel_mode`、`warp_size`、`stream`、`sync_solver`、`tile_mix_cube_loop`、`tile_mix_vector_loop`、`unit_flag`、`num_buffers_warp_spec`、`num_consumer_groups`、`reg_dec_producer`、`reg_inc_consumer`、`enable_warp_specialization`、`enable_persistent`、`optimize_epilogue`、`max_num_imprecise_acc_default`、`allowed_dot_input_precisions`、`extern_libs`、`kernel_name`、`debug`、`enable_fp_fusion`、`allow_fp8e4nv` |

### 32.2 后端驱动

导入方式: `from triton.backends.ascend.driver import ...`

| API | 说明 |
|-----|------|
| `NPUDriver` | NPU 设备驱动。方法: `get_current_device()`、`get_current_stream()`、`get_current_target()`、`get_device_interface()`、`get_empty_cache_for_benchmark()`、`set_current_device()`、`is_active()`、`get_benchmarker()` |
| `NPULauncher` | NPU kernel 启动器，处理参数打包和 kernel 分发 |
| `NPUUtils` | NPU 工具函数。方法: `get_aicore_num()`、`get_aivector_core_num()`、`get_arch()`、`get_device_properties()`、`load_binary()`、`set_device_limit()` |

---

## 33. 数据类型

| 类型常量 | 名称 | 位宽 | 说明 |
|----------|------|------|------|
| `tl.int1` | bool | 1 | 布尔类型 |
| `tl.int8` | int8 | 8 | 8 位有符号整数 |
| `tl.int16` | int16 | 16 | 16 位有符号整数 |
| `tl.int32` | int32 | 32 | 32 位有符号整数 |
| `tl.int64` | int64 | 64 | 64 位有符号整数 |
| `tl.uint8` | uint8 | 8 | 8 位无符号整数 |
| `tl.uint16` | uint16 | 16 | 16 位无符号整数 |
| `tl.uint32` | uint32 | 32 | 32 位无符号整数 |
| `tl.uint64` | uint64 | 64 | 64 位无符号整数 |
| `tl.float16` | fp16 | 16 | IEEE 754 半精度浮点 |
| `tl.float32` | fp32 | 32 | IEEE 754 单精度浮点 |
| `tl.float64` | fp64 | 64 | IEEE 754 双精度浮点 |
| `tl.bfloat16` | bf16 | 16 | BFloat16 (8 位指数, 7 位尾数) |
| `tl.float8e4nv` | fp8e4nv | 8 | FP8 E4M3, NVIDIA 变体（用于矩阵乘法输入输出） |
| `tl.float8e4b8` | fp8e4b8 | 8 | FP8 E4M3, Ascend 变体 |
| `tl.float8e4b15` | fp8e4b15 | 8 | FP8 E4M3, Ascend 变体 (bias=15) |
| `tl.float8e5` | fp8e5 | 8 | FP8 E5M2（用于梯度） |
| `tl.float8e5b16` | fp8e5b16 | 8 | FP8 E5M2, bias=16 变体 |
| `tl.void` | void | 0 | 空类型（无数据） |
