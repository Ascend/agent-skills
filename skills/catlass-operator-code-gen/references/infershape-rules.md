# InferShape（`*_infershape.cpp`）

宏与注册范式由 **ascendc-operator-tiling-code-gen** 负责；本节仅说明 **Catlass 场景**下形状与 dtype 规则。

**重要提示**：`infershape.cpp` 中必须进行函数注册，参考 **ascendc-operator-tiling-code-gen** 中的 `example_infershape.cpp`。

## 逻辑

- **形状**：从输入 shape 推导输出 shape。Catlass **Gemm** 场景下：输出为 **(M, N)**；**M、N、K** 由 **OpDef 转置类布尔属性**（如 `transpose_a` / `transpose_b`）与 **输入二维 shape** 共同决定，并按设计文档中的 **内维 K 对齐表** 校验；**不得**用「多种 shape 模式依次尝试」推断转置（方阵下不唯一）。
- **InferDataType**：无特殊要求下，输出 dtype 与输入 dtype 一致。用户可能添加一个指定输出类型的参数，若有则优先取用户指定的dtype。
- **函数注册**：在 infershape.cpp 中使用 `IMPL_OP_INFERSHAPE` 注册 InferShape；如需则使用 `IMPL_OP_INFERDATATYPE` 注册 InferDataType。

## 检查清单（infershape）

- [ ] `*_infershape.cpp` 中使用 `IMPL_OP_INFERSHAPE` 宏注册 InferShape 函数
- [ ] `*_infershape.cpp` 中使用 `IMPL_OP_INFERDATATYPE` 宏注册 InferDataType 函数（如果需要）

文件落盘见 [code-structure.md](./code-structure.md)；端到端顺序见 [SKILL.md](../SKILL.md)「Step 4」。