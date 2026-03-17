#!/bin/bash
# NPU Health Check Script
# Comprehensive health check for Huawei Ascend NPU devices

set -euo pipefail

echo "========================================"
echo "NPU Health Check - $(date)"
echo "========================================"
echo ""

# Check if npu-smi is available
if ! command -v npu-smi &> /dev/null; then
    echo "ERROR: npu-smi command not found"
    echo "Please ensure CANN is installed and npu-smi is in PATH"
    exit 1
fi

# Get list of NPUs
NPUS=$(npu-smi info -l 2>/dev/null | grep -oP 'NPU\s*:\s*\K[0-9]+' || echo "")

if [ -z "$NPUS" ]; then
    echo "ERROR: No NPU devices found"
    exit 1
fi

echo "Found NPU devices: $(echo $NPUS | tr '\n' ' ')"
echo ""

# Overall status
ISSUES=0

for npu in $NPUS; do
    echo "----------------------------------------"
    echo "NPU $npu"
    echo "----------------------------------------"
    
    # Health check
    HEALTH=$(npu-smi info -t health -i $npu 2>/dev/null | grep -oP 'Healthy\s*:\s*\K\w+' || echo "Unknown")
    echo "Health Status: $HEALTH"
    
    if [ "$HEALTH" != "OK" ] && [ "$HEALTH" != "Unknown" ]; then
        echo "  WARNING: Device health issue detected!"
        ((ISSUES++))
    fi
    
    # Get chips for this NPU
    CHIPS=$(npu-smi info -m 2>/dev/null | grep "NPU $npu" | grep -oP 'Chip\s*:\s*\K[0-9]+' || echo "0")
    
    for chip in $CHIPS; do
        echo ""
        echo "  Chip $chip:"
        
        # Temperature
        TEMP=$(npu-smi info -t temp -i $npu -c $chip 2>/dev/null | grep -oP 'NPU Temperature\s*:\s*\K[0-9]+' || echo "N/A")
        echo "    Temperature: ${TEMP}°C"
        
        if [ "$TEMP" != "N/A" ] && [ "$TEMP" -gt 80 ]; then
            echo "    WARNING: High temperature!"
            ((ISSUES++))
        fi
        
        # Power
        POWER=$(npu-smi info -t power -i $npu -c $chip 2>/dev/null | grep -oP 'Power Usage\s*:\s*\K[0-9.]+' || echo "N/A")
        POWER_LIMIT=$(npu-smi info -t power -i $npu -c $chip 2>/dev/null | grep -oP 'Power Limit\s*:\s*\K[0-9.]+' || echo "N/A")
        echo "    Power: ${POWER}W / ${POWER_LIMIT}W"
        
        # Memory
        MEM_USAGE=$(npu-smi info -t memory -i $npu -c $chip 2>/dev/null | grep -oP 'Memory Usage Rate\s*:\s*\K[0-9]+' || echo "N/A")
        echo "    Memory Usage: ${MEM_USAGE}%"
        
        # ECC Errors
        ECC=$(npu-smi info -t ecc -i $npu -c $chip 2>/dev/null | grep -oP 'ECC Error Count\s*:\s*\K[0-9]+' || echo "0")
        if [ "$ECC" != "0" ] && [ "$ECC" != "N/A" ]; then
            echo "    WARNING: ECC errors detected: $ECC"
            ((ISSUES++))
        else
            echo "    ECC Errors: 0"
        fi
    done
    
    echo ""
done

echo "========================================"
echo "Summary"
echo "========================================"

if [ $ISSUES -eq 0 ]; then
    echo "Status: All devices healthy"
    exit 0
else
    echo "Status: $ISSUES issue(s) detected"
    exit 1
fi
