#!/bin/bash

# ============================================================================
# AscendC算子工程检测脚本
# 功能：检测当前目录或子目录中是否存在AscendC算子工程
# 输出格式：
#   - PROJECT_FOUND:<path>          找到唯一的工程
#   - MULTIPLE_PROJECTS:<path1> <path2> ...  找到多个工程
#   - PROJECT_NOT_FOUND             未找到工程
# ============================================================================

# 函数：检查指定路径是否为算子工程根目录
# 判断标准：
#   - 必须同时存在 build.sh 和 CMakeLists.txt
#   - 至少存在一个辅助目录：ops/, examples/, scripts/
is_ops_project() {
    local dir="$1"
    # 必须同时存在 build.sh 和 CMakeLists.txt
    [ -f "${dir}/build.sh" ] && [ -f "${dir}/CMakeLists.txt" ] && \
    ([ -d "${dir}/ops" ] || [ -d "${dir}/examples" ] || [ -d "${dir}/scripts" ])
}

# 检测策略1：当前目录
if is_ops_project "."; then
    echo "PROJECT_FOUND:."
    exit 0
fi

# 检测策略2：一级子目录
found_projects=()
for dir in */; do
    dir="${dir%/}"  # 去除末尾斜杠
    if [ -d "$dir" ] && is_ops_project "$dir"; then
        found_projects+=("$dir")
    fi
done

# 输出检测结果
if [ ${#found_projects[@]} -eq 1 ]; then
    echo "PROJECT_FOUND:${found_projects[0]}"
    exit 0
elif [ ${#found_projects[@]} -gt 1 ]; then
    echo "MULTIPLE_PROJECTS:${found_projects[*]}"
    exit 0
else
    echo "PROJECT_NOT_FOUND"
    exit 1
fi
