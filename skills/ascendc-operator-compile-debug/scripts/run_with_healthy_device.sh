#!/bin/bash

# 自动选择健康NPU设备执行程序的脚本
# 支持处理"get platform info failed, drvErr=4"等设备不可用错误

run_with_healthy_device() {
    local test_program=$1
    local healthy_device=-1
    
    # 尝试使用npu-smi info查询设备状态
    if command -v npu-smi > /dev/null 2>&1; then
        echo "正在检查NPU设备状态..."
        
        # 直接查找状态为OK的设备行，只获取第一行
        local ok_device_line=$(npu-smi info | grep -E '^\| [0-9]+ ' | grep "OK" | head -1)
        
        if [[ -n "$ok_device_line" ]]; then
            # 提取第一列的设备ID，只取数字部分
            healthy_device=$(echo "$ok_device_line" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | awk '{print $1}')
            echo "找到健康设备: $healthy_device"
        else
            echo "未找到状态为OK的设备，将使用默认设备"
        fi
    else
        echo "npu-smi命令不可用，将使用默认设备"
    fi
    
    # 如果找到健康设备，使用该设备执行测试
    if [[ $healthy_device -ge 0 ]]; then
        echo "使用设备 $healthy_device 执行测试..."
        $test_program $healthy_device
        return $?
    fi
    
    # 如果没有找到健康设备，按序号顺序尝试执行
    echo "未找到健康设备，按序号顺序尝试执行..."
    
    # 获取设备总数
    local device_count=$(ls /dev/davinci* 2>/dev/null | grep -E "^/dev/davinci[0-9]+$" | wc -l)
    
    if [[ $device_count -eq 0 ]]; then
        echo "未检测到NPU设备"
        return 1
    fi
    
    # 按序号顺序尝试每个设备
    for ((i=0; i<$device_count; i++)); do
        echo "尝试使用设备 $i 执行测试..."
        $test_program $i
        
        # 检查是否出现特定错误
        if [[ $? -ne 0 ]]; then
            local output=$( 
                $test_program $i 2>&1
            )
            
            # 如果出现"get platform info failed, drvErr=4"错误，尝试下一个设备
            if echo "$output" | grep -q "get platform info failed, drvErr=4"; then
                echo "设备 $i 出现错误: get platform info failed, drvErr=4，尝试下一个设备..."
                continue
            fi
        fi
        
        # 如果执行成功或出现其他错误，退出循环
        return $?
    done
    
    echo "所有设备都无法正常执行测试"
    return 1
}

# 主函数
main() {
    if [[ $# -eq 0 ]]; then
        echo "用法: $0 <测试程序路径> [测试程序参数...]"
        echo "示例: $0 ./bin/opapi_test_add_custom"
        exit 1
    fi
    
    local test_program=$1
    shift  # 移除第一个参数（测试程序路径），保留其他参数
    
    # 检查测试程序是否存在且可执行
    if [[ ! -x "$test_program" ]]; then
        echo "错误: 测试程序 '$test_program' 不存在或不可执行"
        exit 1
    fi
    
    # 执行测试程序，自动选择健康设备
    run_with_healthy_device "$test_program" "$@"
    return $?
}

# 如果直接执行脚本，则调用主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
