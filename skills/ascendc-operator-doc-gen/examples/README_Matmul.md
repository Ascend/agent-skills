# MatMulV3


##  产品支持情况

| 产品 | 是否支持 |
| ---- | :----:|
|Ascend 950PR/Ascend 950DT|√|
|Atlas A3 训练系列产品/Atlas A3 推理系列产品|√|
|Atlas A2 训练系列产品/Atlas A2 推理系列产品|√|
|Atlas 200I/500 A2推理产品|×|
|Atlas 推理系列产品|√|
|Atlas 训练系列产品|×|
|Kirin X90 处理器系列产品|√|
|Kirin 9030 处理器系列产品|√|

## 功能说明

- 算子功能：完成通用矩阵乘计算。
- 计算公式：

  $$
  C=op(A) @ op(B) + bias
  $$
  其中，$op(A)$，$op(B)$ 和 $op(C)$ 分别是维度为 $(M, K)$, $(K, N)$ 和 $(M, N)$的矩阵。$bias$ 是维度为$(1, N)$或$(N)$的向量。

## 参数说明

<table style="undefined;table-layout: fixed; width: 1576px"><colgroup>
  <col style="width: 170px">
  <col style="width: 170px">
  <col style="width: 310px">
  <col style="width: 212px">
  <col style="width: 100px">
  </colgroup>
  <thead>
    <tr>
      <th>参数名</th>
      <th>输入/输出/属性</th>
      <th>描述</th>
      <th>数据类型</th>
      <th>数据格式</th>
    </tr></thead>
  <tbody>
    <tr>
      <td>a</td>
      <td>输入</td>
      <td>矩阵乘运算中的左矩阵。</td>
      <td>FLOAT16, BFLOAT16, FLOAT32</td>
      <td>ND, FRACTAL_NZ</td>
    </tr>
    <tr>
      <td>b</td>
      <td>输入</td>
      <td>矩阵乘运算中的右矩阵。</td>
      <td>FLOAT16, BFLOAT16, FLOAT32</td>
      <td>ND, FRACTAL_NZ</td>
    </tr>
    <tr>
      <td>bias</td>
      <td>输入</td>
      <td>矩阵乘运算后累加的偏置，对应公式中的bias。</td>
      <td>FLOAT16, BFLOAT16, FLOAT32</td>
      <td>ND</td>
    </tr>
    <tr>
      <td>c</td>
      <td>输出</td>
      <td>通用矩阵乘运算的计算结果。</td>
      <td>FLOAT16, BFLOAT16, FLOAT32</td>
      <td>ND, FRACTAL_NZ</td>
    </tr>
  </tbody></table>

- Atlas 推理系列产品：只支持FLOAT16数据格式，输入b只支持FRACTAL_NZ格式。
- Atlas A2 训练系列产品/Atlas A2 推理系列产品：不支持FRACTAL_NZ格式，bias不支持BFLOAT16数据格式。
- Atlas A3 训练系列产品/Atlas A3 推理系列产品：不支持FRACTAL_NZ格式，bias不支持BFLOAT16数据格式。
- Ascend 950PR/Ascend 950DT：只有输入b支持FRACTAL_NZ格式。

## 约束说明

- 支持空tensor，空tensor场景下不支持bias。
- 支持连续tensor，[非连续tensor](../../docs/zh/context/非连续的Tensor.md)只支持转置场景。

## 调用说明

| 调用方式   | 样例代码           | 说明                                         |
| ---------------- | --------------------------- | --------------------------------------------------- |
| aclnn接口  | [test_aclnn_addmm](examples/test_aclnn_addmm_aclnninplace_addmm.cpp) | 通过<br> - [aclnnAddmm&aclnnInplaceAddmm](./docs/aclnnAddmm&aclnnInplaceAddmm.md)<br> - [aclnnMatmul](docs/aclnnMatmul.md)<br> - [aclnnMatmulWeightNz](docs/aclnnMatmulWeightNz.md)<br> - [aclnnMm](docs/aclnnMm.md)<br>- [aclnnAddmmWeightNz](docs/aclnnAddmmWeightNz.md)<br>等方式调用MatMulV3算子。 |