# aclnn*.md API文档模板

```markdown
# aclnn{算子名称}

## 产品支持情况

| 产品                                                         | 是否支持 |
| :----------------------------------------------------------- | :------: |
| <term>Ascend 950PR/Ascend 950DT</term>                 |    √     |
| <term>Atlas A3 训练系列产品/Atlas A3 推理系列产品</term> |    √     |
| <term>Atlas A2 训练系列产品/Atlas A2 推理系列产品</term> |    √     |
| <term>Atlas 200I/500 A2 推理产品</term> |      ×     |
| <term>Atlas 推理系列产品</term> |      ×     |
| <term>Atlas 训练系列产品</term> |      ×     |

## 功能说明

- 接口功能：{简要描述算子功能}

- 计算公式：

$$
{公式}
$$

## 函数原型

每个算子分为[两段式接口](../../../docs/zh/context/两段式接口.md)，必须先调用"aclnn{算子名称}GetWorkspaceSize"接口获取计算所需workspace大小以及包含了算子计算流程的执行器，再调用"aclnn{算子名称}"接口执行计算。


```Cpp
aclnnStatus aclnn{算子名称}GetWorkspaceSize(
  const aclTensor *{输入参数1},
  const aclTensor *{输入参数2},
  char            *{属性参数},
  const aclTensor *{输出参数},
  uint64_t        *workspaceSize,
  aclOpExecutor  **executor)
```

```Cpp
aclnnStatus aclnn{算子名称}(
  void          *workspace,
  uint64_t       workspaceSize,
  aclOpExecutor *executor,
  aclrtStream    stream)
```

## aclnn{算子名称}GetWorkspaceSize

- **参数说明：**
  <table style="undefined;table-layout: fixed; width: 1565px">
      <colgroup>
          <col style="width: 146px">
          <col style="width: 135px">
          <col style="width: 326px">
          <col style="width: 246px">
          <col style="width: 275px">
          <col style="width: 101px">
          <col style="width: 190px">
          <col style="width: 146px">
      </colgroup>
      <thead>
          <tr>
              <th>参数名</th>
              <th>输入/输出</th>
              <th>描述</th>
              <th>使用说明</th>
              <th>数据类型</th>
              <th>数据格式</th>
              <th>维度(shape)</th>
              <th>非连续Tensor</th>
          </tr>
      </thead>
      <tbody>
          <tr>
              <td>{参数名}（aclTensor*）</td>
              <td>输入/输出</td>
              <td>{参数描述}</td>
              <td>{使用说明}</td>
              <td>{数据类型}</td>
              <td>ND</td>
              <td>{维度}</td>
              <td>√</td>
          </tr>
          <tr>
              <td>{属性名}（char*）</td>
              <td>输入</td>
              <td>{属性描述}</td>
              <td>Host侧的char*常量。当前支持{支持的值}。</td>
              <td>-</td>
              <td>-</td>
              <td>-</td>
              <td>-</td>
          </tr>
      </tbody>
  </table>
  
- **返回值**

  aclnnStatus: 返回状态码，具体参见[aclnn返回码](../../../docs/zh/context/aclnn返回码.md)。

  第一段接口完成入参校验，出现以下场景时报错：

  <table>
    <thead>
      <tr>
        <th>返回值</th>
        <th>错误码</th>
        <th>描述</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>ACLNN_ERR_PARAM_NULLPTR</td>
        <td>161001</td>
        <td>传入的参数是空指针时。</td>
      </tr>
      <tr>
        <td>ACLNN_ERR_PARAM_INVALID</td>
        <td>161002</td>
        <td>参数数据类型不在支持的范围之内。</td>
      </tr>
    </tbody>
  </table>

## aclnn{算子名称}

- **参数说明**：

  <table>
    <thead>
      <tr>
        <th>参数名</th>
        <th>输入/输出</th>
        <th>描述</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>workspace</td>
        <td>输入</td>
        <td>在Device侧申请的workspace内存地址。</td>
      </tr>
      <tr>
        <td>workspaceSize</td>
        <td>输入</td>
        <td>在Device侧申请的workspace大小，由第一段接口获取。</td>
      </tr>
      <tr>
        <td>executor</td>
        <td>输入</td>
        <td>op执行器，包含了算子计算流程。</td>
      </tr>
      <tr>
        <td>stream</td>
        <td>输入</td>
        <td>指定执行任务的Stream。</td>
      </tr>
    </tbody>
  </table>

- **返回值**：

  aclnnStatus：返回状态码，具体参见[aclnn返回码](../../../docs/zh/context/aclnn返回码.md)。

## 约束说明

- 确定性计算：
  - aclnn{算子名称}默认确定性实现。
  - {具体约束条件}

## 调用示例

示例代码如下，仅供参考，具体编译和执行过程请参考[编译与运行样例](../../../docs/zh/context/编译与运行样例.md)。

```Cpp
// 完整示例代码
```
```

## 参数表格列说明

### GetWorkspaceSize参数表（8列）

| 列名 | 说明 |
|------|------|
| 参数名 | 参数名称及类型，如`paramName（aclTensor*）` |
| 输入/输出 | 输入或输出 |
| 描述 | 参数功能描述 |
| 使用说明 | 具体使用注意事项 |
| 数据类型 | 支持的数据类型 |
| 数据格式 | ND/NZ等 |
| 维度(shape) | 支持的维度格式 |
| 非连续Tensor | √/× |

### 执行参数表（3列）

| 列名 | 说明 |
|------|------|
| 参数名 | workspace/workspaceSize/executor/stream |
| 输入/输出 | 固定为输入 |
| 描述 | 参数功能描述 |
