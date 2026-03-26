---
name: ascendc-operator-compile-debug
description: 进行AscendC算子工程编译、部署与测试。当用户需要编译、部署和测试（生成aclnn测试样例test_aclnn_op_name.cpp）自定义算子时使用。
---

# AscendC Operator Compile & Debug

## 快速决策树

| 用户指令 | 核心流程 | 关键文件/命令 | 决策分支 |
|---------|---------|-------------|---------|
| 编译xxx算子 | 查找工程 → 环境检查 → 编译部署 → 测试 | CMakeLists.txt, build.sh | 1. 工程存在 → 环境检查<br>2. 工程不存在 → 报错 |
| 测试xxx算子 | 查找工程 → 环境检查 → 编译部署 → 测试 | test_aclnn_add_custom.cpp, aclnnAddCustom | 1. 工程存在 → 环境检查<br>2. 工程不存在 → 报错

## 工作流概览

### 前置步骤：设置CANN环境

在开始任何操作之前，需要先设置CANN环境变量：

```bash
# 询问用户CANN包路径
read -p "请输入CANN包路径（例如：/data/yyd/Ascend）: " CANN_PATH

# 查找set_env.sh脚本
SET_ENV_SCRIPT=""
if [ -f "$CANN_PATH/set_env.sh" ]; then
    SET_ENV_SCRIPT="$CANN_PATH/set_env.sh"
elif [ -f "$CANN_PATH/ascend-toolkit/set_env.sh" ]; then
    SET_ENV_SCRIPT="$CANN_PATH/ascend-toolkit/set_env.sh"
elif [ -f "$CANN_PATH/cann-*/set_env.sh" ]; then
    SET_ENV_SCRIPT=$(find "$CANN_PATH" -name "set_env.sh" | head -1)
else
    echo "错误：在指定的CANN路径下未找到set_env.sh脚本"
    exit 1
fi

# 加载CANN环境变量
source "$SET_ENV_SCRIPT"

# 验证ASCEND_HOME_PATH是否设置成功
if [ -z "$ASCEND_HOME_PATH" ]; then
    echo "错误：加载环境变量后未设置ASCEND_HOME_PATH"
    exit 1
fi

echo "CANN环境设置成功："
echo "- ASCEND_HOME_PATH: $ASCEND_HOME_PATH"
echo "- PYTHONPATH: $PYTHONPATH"
```

### 核心工作流

```
┌─────────────────────────────────┐
│      用户输入指令               │
└───────────┬─────────────────────┘
            ▼
┌─────────────────────────────────┐
│  1. CANN环境配置              │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│  2. 算子工程检查               │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│  3. 环境检查                   │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│  4. 编译部署                   │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│  5. 测试验证                   │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│  6. 结果反馈                   │
└─────────────────────────────────┘
```

### 详细阶段划分

1. **阶段 1：CANN环境配置** → 产出：正确配置的CANN环境变量
2. **阶段 2：算子工程检查** → 产出：工程存在性判断结果
3. **阶段 3：环境检查** → 产出：环境配置是否满足编译要求
4. **阶段 4：算子编译与部署** → 产出：编译后的算子包和安装
5. **阶段 5：测试样例开发与执行** → 产出：可执行的测试程序和验证结果

## 资源加载策略

- **阶段2**：仅加载 `operator-project-checking.md`
- **阶段3**：仅加载 `operator-environment-checking.md`
- **阶段4**：仅加载 `operator-compilation-deployment.md`
- **阶段5**：仅加载 `operator-testing.md`

**原则**：每个阶段只加载当前阶段所需的资源，避免资源过度加载

## 阶段 1：CANN环境配置

### 核心原则
- **用户指定**：由用户提供CANN包路径，确保使用正确的CANN版本
- **自动查找**：智能查找set_env.sh脚本，取最新的一份，支持不同的安装路径结构
- **验证配置**：确保环境变量设置成功，避免后续操作失败

### 目标
正确配置CANN环境变量，为后续编译部署提供必要的环境支持

### 步骤

```bash
# 询问用户CANN包路径
read -p "请输入CANN包路径（例如：/data/yyd/Ascend）: " CANN_PATH

# 查找set_env.sh脚本
SET_ENV_SCRIPT=""
if [ -f "$CANN_PATH/set_env.sh" ]; then
    SET_ENV_SCRIPT="$CANN_PATH/set_env.sh"
elif [ -f "$CANN_PATH/ascend-toolkit/set_env.sh" ]; then
    SET_ENV_SCRIPT="$CANN_PATH/ascend-toolkit/set_env.sh"
elif [ -f "$CANN_PATH/cann-*/set_env.sh" ]; then
    SET_ENV_SCRIPT=$(find "$CANN_PATH" -name "set_env.sh" | head -1)
else
    echo "错误：在指定的CANN路径下未找到set_env.sh脚本"
    exit 1
fi

# 加载CANN环境变量
source "$SET_ENV_SCRIPT"

# 验证ASCEND_HOME_PATH是否设置成功
if [ -z "$ASCEND_HOME_PATH" ]; then
    echo "错误：加载环境变量后未设置ASCEND_HOME_PATH"
    exit 1
fi

echo "CANN环境设置成功："
echo "- ASCEND_HOME_PATH: $ASCEND_HOME_PATH"
echo "- PYTHONPATH: $PYTHONPATH"
```

### 检查点
- [ ] 用户成功指定了CANN包路径
- [ ] 成功找到并加载了set_env.sh脚本
- [ ] ASCEND_HOME_PATH环境变量设置正确

## 阶段 2：算子工程检查

### 核心原则
- **严格检查**：确保用户指定的算子工程存在且结构完整
- **错误反馈**：工程不存在时立即报错并提示用户
- **结构验证**：按照标准目录结构检查工程完整性

### 目标
检查用户指定的算子工程是否存在，结构是否符合标准，确保后续编译部署能够正常进行

### 步骤

1. **接收用户指令**
   - 用户指令可能包括：编译xxx算子、测试xxx算子等
   - 提取算子名称和操作类型

2. **检查算子工程是否存在**
   ```bash
   # 提取用户指定的算子工程路径
   # 例如：用户可以输入相对路径"./AddCustom"或绝对路径"/data/operators/AddCustom"
   read -p "请输入算子工程路径: " OPERATOR_PATH
   
   # 设置SKILL_DIR变量，指向当前skill目录（动态获取）
   SKILL_DIR=$(dirname "$0")
   
   # 执行项目结构检查脚本
   bash "$SKILL_DIR/scripts/check_project.sh" "$OPERATOR_PATH"
   
   # 根据返回值进行后续操作
   if [ $? -ne 0 ]; then
       echo "错误：算子工程检查失败，请修复问题后重试"
       exit 1
   fi
   ```

**MANDATORY - READ ENTIRE FILE**：在继续之前，你必须完整阅读
[`operator-project-checking.md`](references/operator-project-checking.md) 以获取详细的检查流程和决策逻辑。

### 检查点
- [ ] 正确解析用户指令中的算子名称和操作类型
- [ ] 确认算子工程存在
- [ ] 验证算子工程目录结构完整

## 阶段 3：环境检查

### 核心原则
- **全面检查**：确保所有编译依赖都已正确配置
- **版本匹配**：确保编译器、CMake版本与CANN版本兼容
- **错误预判**：提前检查可能导致编译失败的因素

### 目标
检查编译环境是否满足要求，确保后续编译过程能够顺利进行

### 步骤

```bash
# 确保SKILL_DIR变量已设置
if [ -z "$SKILL_DIR" ]; then
    SKILL_DIR=$(dirname "$0")
fi

# 执行环境检查脚本
bash "$SKILL_DIR/scripts/check_environment.sh"

# 根据返回值进行后续操作
if [ $? -ne 0 ]; then
    echo "错误：环境检查失败，请修复问题后重试"
    exit 1
fi
```

**MANDATORY - READ ENTIRE FILE**：在继续之前，你必须完整阅读
[`operator-environment-checking.md`](references/operator-environment-checking.md) 以获取详细的环境检查流程。

### 检查点
- [ ] CANN环境变量设置正确
- [ ] 所有依赖工具已安装且版本满足要求
- [ ] 环境配置通过验证

## 阶段 3：算子编译与部署

### 核心原则
- **按流程执行**：严格按照编译部署步骤执行
- **错误处理**：妥善处理编译过程中可能出现的错误
- **正确安装**：确保算子包安装到正确的CANN环境目录

### 目标
编译算子工程并将其部署到CANN环境中

### 步骤

1. **使用CMake编译算子工程**
2. **解决常见编译错误**
3. **安装算子包到CANN环境**
4. **配置安装后环境变量**

**MANDATORY - READ ENTIRE FILE**：在继续之前，你必须完整阅读
[`operator-compilation-deployment.md`](references/operator-compilation-deployment.md) 以获取详细的编译命令和错误解决方案。

### 检查点
- [ ] 算子工程编译成功，生成了run包
- [ ] 算子包安装到了正确的CANN环境目录
- [ ] 安装后环境变量配置正确

## 阶段 4：测试样例开发与执行

### 目标
创建aclnn调用样例并执行验证算子功能

### 步骤
1. 开发测试样例代码
2. 搭建测试工程并编译
3. 执行测试程序验证功能

**MANDATORY - READ ENTIRE FILE**：在继续之前，你必须完整阅读
[`operator-testing.md`](references/operator-testing.md) 以获取详细的测试样例代码和执行步骤。

### 最终检查
- [ ] 测试样例编译成功
- [ ] 测试程序能够正常运行
- [ ] 算子执行结果符合预期

## 绝对不要做

- ❌ 不要自己读取build.sh，严格按照skill中的步骤执行编译。
- ❌ 不要使用错误的环境变量或路径配置
- ❌ 不要忽略编译错误，尤其是关于头文件和库依赖的错误
- ❌ 不要在没有测试验证的情况下认为算子功能正确
- ❌ 不要忘记设置LD_LIBRARY_PATH环境变量就执行测试程序
- ❌ 不要跳过阶段检查点，确保每个阶段完成后再进行下一阶段