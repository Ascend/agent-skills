# 算子工程检查

本文档是 msopen-operator-developer Skill 的参考文档，包含算子工程检查的详细流程和决策逻辑。

## 目录

1. [概述](#概述)
2. [指令解析](#指令解析)
3. [工程检查流程](#工程检查流程)
4. [决策逻辑](#决策逻辑)
5. [常见场景处理](#常见场景处理)

## 概述

算子工程检查是整个工作流的第一个阶段，用于确定用户指定的算子工程是否存在，并根据用户指令和检查结果确定后续操作路径。这个阶段的核心目标是提高工作效率，优先处理已有的算子工程，避免重复创建。

## 指令解析

### 支持的指令类型

Skill支持以下几种主要的用户指令：

1. **编译指令**：
   - 示例："帮我编译AddCustom算子"
   - 关键字：编译、build、compile

2. **生成指令**：
   - 示例："帮我生成AddCustom算子工程"
   - 关键字：生成、create、generate、new

3. **测试指令**：
   - 示例："帮我测试AddCustom算子"
   - 关键字：测试、test、run、验证

### 指令解析逻辑

```bash
# 示例：解析用户输入的指令
USER_INPUT="帮我编译AddCustom算子"

# 提取操作类型
if echo "$USER_INPUT" | grep -qE "(编译|build|compile)"; then
    OPERATION="compile"
elif echo "$USER_INPUT" | grep -qE "(生成|create|generate|new)"; then
    OPERATION="generate"
elif echo "$USER_INPUT" | grep -qE "(测试|test|run|验证)"; then
    OPERATION="test"
else
    echo "不支持的指令类型，请重新输入"
    exit 1
fi

# 提取算子名称
# 假设算子名称是最后一个空格后的字符串，且以"算子"结尾
OPERATOR_NAME=$(echo "$USER_INPUT" | awk '{print $NF}' | sed 's/算子$//')

# 检查是否成功提取到算子名称
if [ -z "$OPERATOR_NAME" ]; then
    echo "无法从指令中提取算子名称，请明确指定算子名称"
    exit 1
fi

echo "解析结果："
echo "- 操作类型: $OPERATION"
echo "- 算子名称: $OPERATOR_NAME"
```

## 工程检查流程

### 1. 检查当前目录

首先检查当前目录下是否存在指定的算子工程目录：

```bash
# 检查算子工程目录是否存在
if [ -d "$OPERATOR_NAME" ]; then
    echo "✅ 算子工程 $OPERATOR_NAME 在当前目录下存在"
    PROJECT_EXISTS=true
else
    echo "❌ 算子工程 $OPERATOR_NAME 在当前目录下不存在"
    PROJECT_EXISTS=false
fi
```

### 2. 检查目录结构完整性

如果工程存在，进一步检查目录结构是否完整，按照校验规则进行验证。可以通过执行`scripts/check_project.sh`脚本快速完成项目结构检查：

```bash
# 执行项目结构检查脚本（支持相对路径或绝对路径）
bash $SKILL_DIR/scripts/check_project.sh "$OPERATOR_PATH"

# 根据返回值进行后续操作
if [ $? -eq 0 ]; then
    echo "项目结构检查通过，继续执行后续操作"
else
    echo "项目结构检查失败，请修复问题后重试"
    exit 1
fi
```

脚本将检查以下内容：

- op_host目录是否存在
- op_host/CMakeLists.txt是否存在
- op_kernel目录是否存在
- op_kernel/CMakeLists.txt是否存在
- 算子工程根目录下的build.sh是否存在
- 算子工程根目录下的CMakeLists.txt是否存在

所有检查通过后，脚本将返回0并继续执行后续操作；否则返回1并提示错误信息。

### 3. 检查算子状态

根据操作类型，检查算子的当前状态：

```bash
if [ "$OPERATION" = "compile" ] && [ "$PROJECT_EXISTS" = true ]; then
    # 检查是否已经编译过
    if [ -d "$OPERATOR_PATH/build_out" ] && [ "$(ls -A "$OPERATOR_PATH/build_out")" ]; then
        echo "⚠️  算子工程已经编译过，存在build_out目录"
        read -p "是否重新编译？(y/n): " REBUILD_OPTION
        if [ "$REBUILD_OPTION" != "y" ]; then
            echo "跳过编译，直接进行部署测试"
            SKIP_COMPILE=true
        fi
    fi
elif [ "$OPERATION" = "test" ] && [ "$PROJECT_EXISTS" = true ]; then
    # 检查是否有测试目录
    if [ -d "$OPERATOR_PATH/test" ]; then
        echo "✅ 算子工程包含test目录"
    else
        echo "⚠️  算子工程缺少test目录，需要创建测试样例"
    fi
fi
```

## 决策逻辑

根据指令类型和工程存在性，确定后续操作路径：

```bash
# 决策逻辑
if [ "$OPERATION" = "compile" ]; then
    if [ "$PROJECT_EXISTS" = true ]; then
        echo "决策：直接进入阶段3（算子编译与部署）"
        # 执行阶段3
    else
        echo "决策：算子工程不存在，询问用户是否创建"
        read -p "是否需要创建该算子工程？(y/n): " CREATE_OPTION
        if [ "$CREATE_OPTION" = "y" ]; then
            echo "决策：进入阶段1（算子工程生成）"
            # 执行阶段1
        else
            echo "操作已取消"
            exit 0
        fi
    fi
elif [ "$OPERATION" = "generate" ]; then
    if [ "$PROJECT_EXISTS" = true ]; then
        echo "决策：算子工程已存在，询问用户是否覆盖"
        read -p "算子工程已存在，是否覆盖？(y/n): " OVERWRITE_OPTION
        if [ "$OVERWRITE_OPTION" = "y" ]; then
            echo "决策：进入阶段1（算子工程生成），覆盖现有工程"
            # 执行阶段1，覆盖现有工程
        else
            echo "操作已取消"
            exit 0
        fi
    else
        echo "决策：直接进入阶段1（算子工程生成）"
        # 执行阶段1
    fi
elif [ "$OPERATION" = "test" ]; then
    if [ "$PROJECT_EXISTS" = true ]; then
        echo "决策：直接进入阶段4（测试样例开发与执行）"
        # 执行阶段4
    else
        echo "决策：算子工程不存在，询问用户是否创建"
        read -p "是否需要创建该算子工程？(y/n): " CREATE_OPTION
        if [ "$CREATE_OPTION" = "y" ]; then
            echo "决策：依次执行阶段1→阶段2→阶段4"
            # 执行阶段1→阶段2→阶段4
        else
            echo "操作已取消"
            exit 0
        fi
    fi
fi
```

## 常见场景处理

### 场景1：用户输入模糊指令

**用户输入**："帮我处理AddCustom算子"

**处理逻辑**：
1. 无法确定具体操作类型（编译/生成/测试）
2. 询问用户具体需要执行的操作

```bash
# 处理模糊指令的示例
USER_INPUT="帮我处理AddCustom算子"

if ! echo "$USER_INPUT" | grep -qE "(编译|build|compile|生成|create|generate|new|测试|test|run|验证)"; then
    echo "请明确指定需要执行的操作（编译/生成/测试）"
    read -p "请输入操作类型（编译/生成/测试）: " OPERATION
    
    # 验证操作类型
    if ! echo "$OPERATION" | grep -qE "(编译|build|compile|生成|create|generate|new|测试|test|run|验证)"; then
        echo "不支持的操作类型"
        exit 1
    fi
fi
```

### 场景2：用户指定的算子名称不存在

**用户输入**："帮我编译MyCustomOperator算子"

**处理逻辑**：
1. 检查当前目录下是否存在MyCustomOperator目录
2. 如果不存在，询问用户是否创建
3. 如果用户选择创建，进入算子工程生成阶段
4. 如果用户选择不创建，结束操作

### 场景3：用户提供了JSON文件路径

**用户输入**："帮我使用my_operator.json生成算子工程"

**处理逻辑**：
1. 检查提供的JSON文件是否存在
2. 如果存在，使用该文件生成算子工程
3. 如果不存在，提示用户文件不存在，并提供生成样例JSON的选项

```bash
# 处理用户提供JSON文件的示例
USER_INPUT="帮我使用my_operator.json生成算子工程"

# 提取JSON文件路径
JSON_FILE=$(echo "$USER_INPUT" | grep -o "[0-9a-zA-Z_\.\/]*\.json")

if [ -n "$JSON_FILE" ]; then
    if [ -f "$JSON_FILE" ]; then
        echo "使用用户提供的JSON文件: $JSON_FILE"
        CUSTOM_JSON_FILE=$JSON_FILE
    else
        echo "错误：JSON文件 $JSON_FILE 不存在"
        read -p "是否生成样例JSON文件？(y/n): " GENERATE_OPTION
        if [ "$GENERATE_OPTION" = "y" ]; then
            # 生成样例JSON文件
            :
        else
            echo "操作已取消"
            exit 0
        fi
    fi
fi
```

### 场景4：用户需要编译多个算子

**用户输入**："帮我编译AddCustom和MulCustom算子"

**处理逻辑**：
1. 解析用户指令，提取多个算子名称
2. 依次检查每个算子工程是否存在
3. 对每个存在的工程进行编译部署
4. 对不存在的工程，询问用户是否创建

```bash
# 处理多个算子的示例
USER_INPUT="帮我编译AddCustom和MulCustom算子"

# 提取所有算子名称（假设用"和"分隔）
OPERATOR_NAMES=$(echo "$USER_INPUT" | sed 's/帮我编译//;s/算子//;s/和/ /g')

echo "提取到的算子名称: $OPERATOR_NAMES"

# 遍历每个算子名称
for OPERATOR_NAME in $OPERATOR_NAMES; do
    echo -e "\n--- 处理算子: $OPERATOR_NAME ---
"
    
    # 检查算子工程是否存在
    if [ -d "$OPERATOR_NAME" ]; then
        echo "编译算子工程: $OPERATOR_NAME"
        # 执行编译操作
        :
    else
        echo "算子工程 $OPERATOR_NAME 不存在"
        read -p "是否创建该算子工程？(y/n): " CREATE_OPTION
        if [ "$CREATE_OPTION" = "y" ]; then
            echo "创建算子工程: $OPERATOR_NAME"
            # 执行创建操作
            :
        fi
    fi
done
```

## 最佳实践

1. **优先检查**：始终先检查用户指定的算子工程是否存在，避免重复创建
2. **清晰反馈**：向用户提供明确的检查结果和决策建议
3. **灵活适配**：支持多种用户指令和场景
4. **用户友好**：当工程不存在时，提供创建选项；当用户未提供JSON时，生成样例JSON
5. **错误处理**：妥善处理各种错误情况，如文件不存在、指令不明确等

## 注意事项

1. 确保正确解析用户指令，特别是算子名称和操作类型
2. 检查算子工程目录结构的完整性，避免后续操作失败
3. 根据操作类型和工程状态，提供合理的决策选项
4. 保持与用户的良好沟通，确保用户了解当前状态和后续操作
5. 记录检查结果和决策过程，便于后续调试和问题定位