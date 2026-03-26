# Segsum

## 产品支持情况

|产品             |  是否支持  |
|:-------------------------|:----------:|
|  <term>Ascend 950PR/Ascend 950DT</term>   |     ×    |
|  <term>Atlas A3 训练系列产品/Atlas A3 推理系列产品</term>   |     √    |
|  <term>Atlas A2 训练系列产品/Atlas A2 推理系列产品</term>     |     √    |
|  <term>Atlas 200I/500 A2 推理产品</term>    |     ×    |
|  <term>Atlas 推理系列产品</term>    |     ×    |
|  <term>Atlas 训练系列产品</term>    |     ×    |


## 功能说明

- 算子功能：进行分段和计算。生成对角线为0的半可分矩阵，且上三角为-inf。
- 计算公式（以4D输入为例）：

  1. 输入self由（N1,N2,N3,N4）升维成（N1,N2,N3,N4,1）。
  2. 进行广播得到（N1,N2,N3,N4,N4）。
  3. 生成（N4,N4）类型为bool的三角矩阵A，上三角为True，下三角为False，对角线为True。
  4. 用0填充输入self里面与矩阵A中值为True的位置相对应的元素。
    
    $$
    self_i=
    \begin{cases}self_i,\quad A_i==False
    \\0, \quad A_i==True
    \end{cases}
    $$

  5. 以self的倒数第二维进行cumsum累加。从维度视角来看的某个元素（其它维度下标不变，当前维度下标依次递增），$selfTemp\_{i}$是输出张量中对应位置的元素。

     $$
     selfTemp_{i} = self_{1} + self_{2} + self_{3} + ...... + self_{i}
     $$

  6. 生成（N4,N4）类型为bool的三角矩阵B，上三角为True，下三角为False，对角线为False。
  7. 用-inf填充selfTemp里面与矩阵B中值为True的位置相对应的元素。
    
     $$
     out_i=
     \begin{cases}selfTemp_i,\quad B_i==False
     \\-inf, \quad B_i==True
     \end{cases}
     $$
     
  8. 计算selfTemp里面每个元素的指数。
    
     $$
     out_i=e^{selfTemp_i}
     $$

## 参数说明

<table style="undefined;table-layout: fixed; width: 1005px"><colgroup>
  <col style="width: 170px">
  <col style="width: 170px">
  <col style="width: 352px">
  <col style="width: 213px">
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
      <td>x</td>
      <td>输入</td>
      <td>进行分段和计算的输入，对应公式中的`self`。</td>
      <td>FLOAT32、FLOAT16、BFLOAT16</td>
      <td>ND</td>
    </tr>
    <tr>
      <td>y</td>
      <td>输出</td>
      <td>完成分段和计算后的输出，对应公式中的`out`。输出维度必须比输入维度大1，支持4D或5D。当输入`x`为3D时，输出前3维的维度大小与`x`的保持一致，最后1维的维度大小与第3维保持一致。当输入`x`为4D时，输出前4维的维度大小与`x`的保持一致，最后1维的维度大小与第4维保持一致。数据类型与输入`x`的数据类型保持一致。</td>
      <td>FLOAT32、FLOAT16、BFLOAT16</td>
      <td>ND</td>
    </tr>
  </tbody></table>


## 约束说明

无

## 调用说明

| 调用方式   | 样例代码           | 说明                                         |
| ---------------- | --------------------------- | --------------------------------------------------- |
| aclnn接口  | [test_aclnn_segsum](examples/test_aclnn_segsum.cpp) | 通过[aclnnExpSegsum](docs/aclnnExpSegsum.md)接口方式调用Segsum算子。 |