---
name: catlass-module-import
description: 在算子工程根目录下引入 catlass 库并配置 CMake。在 OPS_PROJECT_ROOT 下克隆 catlass、修改工程 CMake 使 op_kernel 可 include catlass。Use when 用户需要获取 catlass 库、配置 catlass 开发环境、或开发 Catlass 算子前准备依赖。条件不明则追问。
---

# Catlass 模块导入

## 概述

从 gitcode.com/cann/catlass 克隆 catlass 到本地，并在当前算子工程中配置 CMake，使 op_kernel 能 `#include` catlass 头文件。工程目录术语与 Catlass 系列 skill 统一：**OPS_PROJECT_ROOT** = 含 `build.sh`、`ops/` 的工程根；**USER_OP_PROJECT** = `ops/<算子名>/`。详见 catlass-operator-dev 的 `references/project-directory-terms.md`。

## 何时使用

- 用户需要获取 catlass 库或配置 catlass 开发环境
- 开发 Catlass 算子前，工程根尚无 catlass 或需重新配置
- 其他 Catlass 相关 skill（如 design、code-gen）前置要求「先引入 catlass」时

## 前置条件

- 当前或可确定的 **OPS_PROJECT_ROOT**：含 `build.sh`、`ops/` 的目录。若无法确定（无 `build.sh`、`ops/`），先追问用户或先执行 ascendc-operator-project-init。
- 已安装 git；网络可访问 gitcode.com/cann/catlass。

## Do（必须）

- **条件不明则追问**：若无法确定工程根（无 `build.sh`、`ops/`），追问用户或先执行 ascendc-operator-project-init。
- 执行 clone 前 **cd 到 OPS_PROJECT_ROOT**（含 `build.sh`、`ops/` 的目录）；clone 得到 `<OPS_PROJECT_ROOT>/catlass/`。
- 只修改与 kernel 编译相关的 CMake（使 op_kernel 能 include catlass），不修改 catlass 自身或无关子目录的 CMake。

## Don't（禁止）

- 在 **ops/<算子名>/** 下克隆 catlass；使用 `git clone ... .` 覆盖当前目录。
- 在未确认当前目录为 OPS_PROJECT_ROOT 时执行 clone。

## 工作目录约定

- catlass 必须且仅能克隆在 **OPS_PROJECT_ROOT** 下，得到 `<OPS_PROJECT_ROOT>/catlass/`；禁止在 `ops/<算子名>/` 下克隆。
- 正确结构示例：
```
<OPS_PROJECT_ROOT>/
├── build.sh
├── CMakeLists.txt
├── catlass/          ← 只在此处有一份 catlass
├── ops/
│   ├── op_a/
│   └── op_b/
└── ...
```

## 操作步骤

### 第1步：确认工作目录为算子工程根目录

执行本技能前，**必须先切换到 OPS_PROJECT_ROOT**（包含 `build.sh`、`ops/` 的目录）。若当前在 `ops/<算子名>/` 或其它子目录，需先执行 `cd <OPS_PROJECT_ROOT>`。

```bash
# 检查当前目录是否为算子工程根（必须存在 build.sh 与 ops/）
if [ ! -f "build.sh" ] || [ ! -d "ops" ]; then
    echo "错误：当前目录不是算子工程根目录，请先 cd 到包含 build.sh 和 ops/ 的目录"
    exit 1
fi
echo "✅ 当前为算子工程根目录"
```

### 第2步：检查依赖工具

检查系统是否已安装必要的工具：

```bash
# 检查Git
if ! command -v git &> /dev/null; then
    echo "错误：未安装git工具，请先安装git"
    exit 1
fi

echo "✅ 所有依赖工具已安装"
```

### 第3步：在工程根目录下克隆仓库（最新版本）

**必须在 OPS_PROJECT_ROOT 下**执行克隆，得到 `<OPS_PROJECT_ROOT>/catlass/`，禁止在 `ops/<算子名>/` 下执行：

```bash
echo "\n正在克隆catlass最新版本到本地（算子工程根目录下）..."

# 再次确认在工程根
if [ ! -f "build.sh" ] || [ ! -d "ops" ]; then
    echo "错误：请在算子工程根目录下执行，不要进入 ops/<算子名>/ 再 clone"
    exit 1
fi

# 检查目标目录是否存在
if [ -d "catlass" ]; then
    read -p "目录 'catlass' 已存在，是否覆盖？(y/n): " OVERWRITE
    if [ "$OVERWRITE" != "y" ] && [ "$OVERWRITE" != "Y" ]; then
        echo "已取消克隆操作"
        exit 0
    fi
    # 删除现有目录
    rm -rf catlass
fi

# 克隆到当前目录下，得到 ./catlass/（禁止使用 git clone ... . 覆盖当前目录）
git clone https://gitcode.com/cann/catlass.git catlass

# 检查克隆是否成功
if [ $? -ne 0 ]; then
    echo "错误：克隆仓库失败，请检查网络连接"
    exit 1
fi

echo "✅ 克隆完成：$(pwd)/catlass"
```

### 第4步：修改现有工程的 CMakeLists.txt 文件

**约定**：`CATLASS_DIR` 指向**算子工程根目录下的 catlass**，即 `${CMAKE_SOURCE_DIR}/catlass` 或工程根下的 `./catlass`。

- **任务1**：查找当前工作目录下除 `catlass/` 以外的 CMakeLists.txt，对 `add_ops_compile_options` 或 `ascendc_include_directories` 进行修改：

```bash
find . -type f -name "CMakeLists.txt" -not -path "./catlass/*"  | while read -r file; do
    if grep -q "add_ops_compile_options" "$file" || grep -q "ascendc_include_directories" "$file"; then
        echo "处理文件：$file"
    fi
done
```

在找到的文件中添加内容（其中 `${CATLASS_DIR}` 为**工程根目录下的 catlass**，例如 `${CMAKE_SOURCE_DIR}/catlass`）：
- 若存在 `add_ops_compile_options`，添加：`add_ops_compile_options(... -I${CATLASS_DIR}/include)`
- 若存在 `ascendc_include_directories`，添加：`ascendc_include_directories(${CATLASS_DIR}/include)`

- **任务2**：查找 CMakeLists.txt 中存在 `project(...)` 且包含 `ASC` 编程语言的工程，在合适位置添加：
  `include_directories($<$<COMPILE_LANGUAGE:ASC>:${CATLASS_DIR}/include>)`  
  其中 `${CATLASS_DIR}` 指向工程根下的 catlass（如 `${CMAKE_SOURCE_DIR}/catlass`）。

```bash
find . -type f -name "CMakeLists.txt" -not -path "./catlass/*"  | while read -r file; do
    if grep -qE "project\([^)]+LANGUAGES[^)]*ASC" "$file"; then
        proj_path=$(dirname "$file")
        echo "在文件 $file 中发现 ASC 工程，路径为 $proj_path"
    fi
done
```

以上任务完成后，查看 catlass 库下的 README.md，确认是否需要其他配置，若有则一并加入。

### 注意事项

- **catlass 必须且仅能克隆在 OPS_PROJECT_ROOT 下**，得到 `<OPS_PROJECT_ROOT>/catlass/`。禁止在 `ops/<算子名>/` 下克隆。
- 使用 ascendc-operator-project-init 初始化后，OPS_PROJECT_ROOT 通常为 `ops-project`，clone 目标为 `ops-project/catlass`。
- 禁止使用 `git clone https://gitcode.com/cann/catlass.git .` 以免覆盖当前目录。

## 参考资料

- catlass-operator-dev 的 `references/project-directory-terms.md`：OPS_PROJECT_ROOT / USER_OP_PROJECT 定义。
- 克隆完成后可查看 `catlass/README.md` 确认是否需其他配置。