#!/bin/bash

# 检查算子工程目录结构和必要文件

# 参数：算子工程路径（可以是相对路径或绝对路径）
if [ -z "$1" ]; then
    echo "错误：请提供算子工程路径"
    echo "用法：$0 <算子工程路径>"
    exit 1
fi

OPERATOR_PATH=$1
PROJECT_EXISTS=false

# 检查指定路径是否存在且是目录
if [ -d "$OPERATOR_PATH" ]; then
    echo "✅ 算子工程在路径 $OPERATOR_PATH 存在"
    PROJECT_EXISTS=true
else
    echo "错误：算子工程路径 $OPERATOR_PATH 不存在或不是目录，请指定正确的算子工程路径"
    exit 1
fi

if [ "$PROJECT_EXISTS" = true ]; then
    echo "检查算子工程目录结构..."
    
    # 简化的必要目录和文件检查项
    ALL_OK=true
    
    # 检查算子工程目录最外层是否存在 CMakeLists.txt
    if [ ! -f "$OPERATOR_PATH/CMakeLists.txt" ]; then
        echo "❌ 算子工程目录最外层缺少必要文件: CMakeLists.txt"
        ALL_OK=false
    fi
    
    # 检查是否存在ops目录，如果存在则检查其中的算子结构
    if [ -d "$OPERATOR_PATH/ops" ]; then
        echo "✅ 检测到ops目录结构"
        
        # 获取所有算子目录
        OPERATOR_DIRS=$(find "$OPERATOR_PATH/ops" -maxdepth 1 -type d | grep -v "$OPERATOR_PATH/ops$" | sort)
        
        if [ -n "$OPERATOR_DIRS" ]; then
            for OP_DIR in $OPERATOR_DIRS; do
                OP_NAME=$(basename "$OP_DIR")
                echo -e "\n检查算子 $OP_NAME 的目录结构..."
                
                # 检查当前算子目录下是否存在 op_host 目录
                if [ ! -d "$OP_DIR/op_host" ]; then
                    echo "❌ 算子 $OP_NAME 缺少必要目录: op_host"
                    ALL_OK=false
                else
                    # 检查op_host目录下的必要文件
                    if [ ! -f "$OP_DIR/op_host/CMakeLists.txt" ]; then
                        echo "❌ 算子 $OP_NAME 的op_host目录下缺少必要文件: CMakeLists.txt"
                        ALL_OK=false
                    fi
                    
                    # 检查op_host目录下的文件名是否符合规则
                    if [ ! -f "$OP_DIR/op_host/${OP_NAME}_def.cpp" ]; then
                        echo "❌ 算子 $OP_NAME 的op_host目录下缺少必要文件: ${OP_NAME}_def.cpp"
                        ALL_OK=false
                    fi
                    
                    if [ ! -f "$OP_DIR/op_host/${OP_NAME}_infershape.cpp" ]; then
                        echo "❌ 算子 $OP_NAME 的op_host目录下缺少必要文件: ${OP_NAME}_infershape.cpp"
                        ALL_OK=false
                    fi
                    
                    if [ ! -f "$OP_DIR/op_host/${OP_NAME}_tiling.cpp" ]; then
                        echo "❌ 算子 $OP_NAME 的op_host目录下缺少必要文件: ${OP_NAME}_tiling.cpp"
                        ALL_OK=false
                    fi
                    
                    if [ ! -f "$OP_DIR/op_host/${OP_NAME}_tiling.h" ]; then
                        echo "❌ 算子 $OP_NAME 的op_host目录下缺少必要文件: ${OP_NAME}_tiling.h"
                        ALL_OK=false
                    fi
                fi
                
                # 检查当前算子目录下是否存在 op_kernel 目录
                if [ ! -d "$OP_DIR/op_kernel" ]; then
                    echo "❌ 算子 $OP_NAME 缺少必要目录: op_kernel"
                    ALL_OK=false
                else
                    # 检查op_kernel目录下的文件名是否符合规则
                    if [ ! -f "$OP_DIR/op_kernel/${OP_NAME}.cpp" ]; then
                        echo "❌ 算子 $OP_NAME 的op_kernel目录下缺少必要文件: ${OP_NAME}.cpp"
                        ALL_OK=false
                    fi
                    
                    if [ ! -f "$OP_DIR/op_kernel/${OP_NAME}.h" ]; then
                        echo "❌ 算子 $OP_NAME 的op_kernel目录下缺少必要文件: ${OP_NAME}.h"
                        ALL_OK=false
                    fi
                fi
                
                if [ "$ALL_OK" = true ]; then
                    echo "✅ 算子 $OP_NAME 的目录结构和必要文件检查通过"
                fi
            done
        else
            echo "⚠️ ops目录下没有找到算子目录"
            ALL_OK=false
        fi
    else
        # 传统结构检查：检查是否存在 op_host 目录及其下的必要文件
        echo "✅ 检测到传统目录结构"
        
        if [ ! -d "$OPERATOR_PATH/op_host" ]; then
            echo "❌ 缺少必要目录: op_host"
            ALL_OK=false
        elif [ ! -f "$OPERATOR_PATH/op_host/CMakeLists.txt" ]; then
            echo "❌ op_host 目录下缺少必要文件: CMakeLists.txt"
            ALL_OK=false
        fi
    fi
    
    # # 检查算子工程目录最外层是否存在 CMakePresets.json
    # if [ ! -f "$OPERATOR_PATH/CMakePresets.json" ]; then
    #     echo "❌ 算子工程目录最外层缺少必要文件: CMakePresets.json"
    #     ALL_OK=false
    # fi
    
    if [ "$ALL_OK" = true ]; then
        echo "✅ 算子工程目录结构和必要文件检查通过"
        exit 0
    else
        echo "❌ 算子工程目录结构不完整或缺少必要文件"
        exit 1
    fi
fi