#!/bin/bash

# 检查CANN环境变量是否设置
if [ -z "$ASCEND_HOME_PATH" ]; then
    echo "错误：ASCEND_HOME_PATH环境变量未设置"
    echo "请先完成前置步骤：设置CANN环境"
    exit 1
fi

# 检查Python是否存在并满足版本要求
python3 --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "错误：未找到Python3"
    echo "请安装Python3: apt-get install python3"
    exit 1
fi

# 检查Python版本（3.7.0 <= version <= 3.10）
PYTHON_VERSION=$(python3 --version | grep -oP 'Python \K[0-9]+\.[0-9]+\.[0-9]+')
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
PYTHON_PATCH=$(echo $PYTHON_VERSION | cut -d. -f3)

if (( PYTHON_MAJOR < 3 )) || (( PYTHON_MAJOR == 3 && PYTHON_MINOR < 7 )); then
    echo "错误：Python版本过低（当前版本: $PYTHON_VERSION）"
    echo "请安装Python 3.7.0或更高版本"
    exit 1
fi

if (( PYTHON_MAJOR > 3 )) || (( PYTHON_MAJOR == 3 && PYTHON_MINOR > 10 )); then
    echo "警告：Python版本过高（当前版本: $PYTHON_VERSION）"
    echo "建议使用Python 3.10或更低版本以确保兼容性"
fi

# 检查gcc编译器是否存在并满足版本要求
gcc --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "错误：未找到gcc编译器"
    echo "请安装gcc: apt-get install gcc"
    exit 1
fi

# 检查gcc版本（至少7.3.0）
GCC_VERSION=$(gcc --version | grep -oP 'gcc \(.*\) \K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
GCC_MAJOR=$(echo $GCC_VERSION | cut -d. -f1)
GCC_MINOR=$(echo $GCC_VERSION | cut -d. -f2)

if (( GCC_MAJOR < 7 )) || (( GCC_MAJOR == 7 && GCC_MINOR < 3 )); then
    echo "错误：gcc版本过低（当前版本: $GCC_VERSION）"
    echo "请安装gcc 7.3.0或更高版本"
    exit 1
fi

# 检查g++编译器是否存在
g++ --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "错误：未找到g++编译器"
    echo "请安装g++: apt-get install g++"
    exit 1
fi

# 检查CMake是否存在并满足版本要求
cmake --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "错误：未找到CMake"
    echo "请安装CMake: apt-get install cmake"
    exit 1
fi

# 检查CMake版本（至少3.16.0）
CMAKE_VERSION=$(cmake --version | grep -oP 'cmake version \K[0-9]+\.[0-9]+')
if (( $(echo "$CMAKE_VERSION < 3.16" | bc -l) )); then
    echo "错误：CMake版本过低（当前版本: $CMAKE_VERSION）"
    echo "请安装3.16或更高版本的CMake"
    exit 1
fi

# 检查pigz是否存在（可选，提升打包速度）
pigz --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "警告：未找到pigz工具"
    echo "建议安装pigz以提升打包速度: apt-get install pigz"
else
    PIGZ_VERSION=$(pigz --version | grep -oP 'pigz \K[0-9]+\.[0-9]+')
    if (( $(echo "$PIGZ_VERSION < 2.4" | bc -l) )); then
        echo "警告：pigz版本过低（当前版本: $PIGZ_VERSION）"
        echo "建议安装pigz 2.4或更高版本"
    fi
fi

# 检查dos2unix是否存在
dos2unix --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "错误：未找到dos2unix工具"
    echo "请安装dos2unix: apt-get install dos2unix"
    exit 1
fi

# 检查gawk是否存在
gawk --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "错误：未找到gawk工具"
    echo "请安装gawk: apt-get install gawk"
    exit 1
fi

# 检查make是否存在
make --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "错误：未找到make工具"
    echo "请安装make: apt-get install make"
    exit 1
fi

# 检查npu-smi工具是否可用
npu-smi info > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "警告：未找到npu-smi工具，无法自动获取SOC版本"
else
    # 自动获取SOC版本（从npu-smi输出的第二列提取，如910B3）
    # 找到包含NPU信息的行，然后提取第二个字段（SOC版本）
    SOC_VERSION=$(npu-smi info | grep -E "^\| [0-9]+\s+" | head -1 | awk -F'[[:space:]]+' '{print $3}')
    # 如果找到了有效的SOC版本，则添加Ascend前缀
    if [ -n "$SOC_VERSION" ]; then
        SOC_VERSION="Ascend${SOC_VERSION}"
        echo "自动获取的SOC版本: $SOC_VERSION"
    else
        echo "警告：无法从npu-smi输出中识别SOC版本"
    fi
fi

# 检查PYTHONPATH是否包含CANN Python路径
if [[ "$PYTHONPATH" != *"$ASCEND_HOME_PATH/python/site-packages"* ]]; then
    echo "警告：PYTHONPATH中未包含CANN Python路径"
    export PYTHONPATH=$ASCEND_HOME_PATH/python/site-packages:$PYTHONPATH
    echo "已将CANN Python路径添加到PYTHONPATH"
fi

echo "环境检查通过，可以开始编译算子工程"
exit 0