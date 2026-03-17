# Device Queries Reference

Detailed reference for npu-smi device query commands.

## Table of Contents

1. [Platform Identification](#platform-identification)
2. [Basic Queries](#basic-queries)
3. [Real-time Metrics](#real-time-metrics)
4. [Advanced Queries](#advanced-queries)
5. [Output Formats](#output-formats)
6. [Monitoring Scripts](#monitoring-scripts)

---

## Platform Identification

> **Important**: Chip name alone does **NOT** determine the server platform (A2 vs A3).

### Common Misconception

When `npu-smi info -m` shows **Chip Name: Ascend 910B3**, this does **NOT** mean the machine is an **Atlas A3**. The same chip (910B3) can be used in both **A2** and **A3** servers.

**Example**: An Atlas A2 server with 8× 910B3 chips will still show "910B3" as the chip name.

### Correct Method: Check System Product Info

To identify whether you have an **Atlas A2** or **Atlas A3** server, use system-level commands:

```bash
# Method 1: Using dmidecode (recommended)
dmidecode -t system 2>/dev/null | head -20 | grep Product

# Method 2: Check product information via npu-smi
npu-smi info -t product -i 0 -c 0
```

### Platform Mapping Reference

| Chip Name | Server Platform |
|-----------|-----------------|
| Ascend 910B | Atlas A2 |
| Ascend 910C | Atlas A3 |
| Ascend 950 | Atlas A5 |

### Key Takeaway

- **Chip name** indicates the NPU processor model
- **Server platform** (A2/A3) is determined by the system product information
- Always verify via `dmidecode` or `npu-smi info -t product` rather than assuming from chip name

---

## Basic Queries

### List Devices

```bash
npu-smi info -l
```

**Output Fields**:
| Field | Description |
|-------|-------------|
| NPU ID | Device identifier |
| Name | Device name (e.g., 910B3) |

**Example Output**:
```
Total        : 8 NPU in system
NPU          : 0
Name         : 910B3
...
```

### Query Device Health

```bash
npu-smi info -t health -i <id>
```

**Output**:
| Field | Values |
|-------|--------|
| Healthy | OK, Warning, Error |

### Query Board Information

```bash
npu-smi info -t board -i <id>
```

**Output Fields**:
| Field | Description |
|-------|-------------|
| NPU ID | Device identifier |
| Name | Board name |
| Health | Health status |
| Power Usage | Current power draw |
| Temperature | Board temperature |
| Firmware Version | Current firmware |
| Software Version | Driver version |

### Query Chip Details

```bash
npu-smi info -t npu -i <id> -c <chip_id>
```

**Output Fields**:
| Field | Description |
|-------|-------------|
| Chip ID | Chip identifier |
| Name | Chip name |
| Health | Health status |
| Power Usage | Power consumption |
| Temperature | Chip temperature |
| Memory Usage | Memory utilization |
| AI Core Usage | AI Core utilization |

### List All Chips

```bash
npu-smi info -m
```

**Output Fields**:
| Field | Description |
|-------|-------------|
| NPU ID | Parent device |
| Chip ID | Chip identifier |
| Name | Chip name |
| Health | Health status |

---

## Real-time Metrics

### Temperature

```bash
npu-smi info -t temp -i <id> -c <chip_id>
```

**Output**:
- NPU Temperature (°C)
- AI Core Temperature (°C)

**Note**: Output format may vary by npu-smi version.

### Power

```bash
npu-smi info -t power -i <id> -c <chip_id>
```

**Output**:
- Power Usage (W)
- Power Limit (W)

### Memory

```bash
npu-smi info -t memory -i <id> -c <chip_id>
```

**Output**:
- Memory Usage (MB)
- Memory Total (MB)
- Memory Usage Rate (%)

---

## Advanced Queries

### Running Processes

```bash
npu-smi info proc -i <id> -c <chip_id>
```

**Note**: Not supported on all platforms (e.g., Ascend 910B).

**Output Fields**:
| Field | Description |
|-------|-------------|
| PID | Process ID |
| Process Name | Application name |
| Memory Usage | Memory used |
| AI Core Usage | AI Core utilization |

### ECC Errors

```bash
npu-smi info -t ecc -i <id> -c <chip_id>
```

**Output**:
- ECC Error Count
- ECC Mode (Enabled/Disabled)

### Utilization

```bash
npu-smi info -t usages -i <id> -c <chip_id>
```

**Output**:
- AI Core Usage (%)
- Memory Usage (%)
- Bandwidth Usage (%)

### PCIe Info

```bash
npu-smi info -t pcie-info -i <id> -c <chip_id>
```

**Output**:
- PCIe Speed (GT/s)
- PCIe Width (x16, x8, etc.)

### P2P Status

```bash
npu-smi info -t p2p -i <id> -c <chip_id>
```

**Output**:
- P2P Status
- P2P Mode

### Product Info

```bash
npu-smi info -t product -i <id> -c <chip_id>
```

**Output**:
- Product Name
- Product Serial Number

---

## Output Formats

Output format may vary by:
- npu-smi version
- Hardware platform
- Firmware version

Always verify output format on your specific system.

---

## Monitoring Scripts

### Quick Health Check

```bash
#!/bin/bash

# Check health of all devices
npu-smi info -l | grep -E '^\|\s+[0-9]+' | while read line; do
    npu=$(echo $line | awk '{print $2}')
    health=$(npu-smi info -t health -i $npu | grep Healthy | awk '{print $2}')
    echo "NPU $npu: $health"
done
```

### Device Summary

```bash
#!/bin/bash

NPU=0
CHIP=0

echo "=== Device $NPU Summary ==="
npu-smi info -t health -i $NPU
npu-smi info -t board -i $NPU
echo ""
echo "=== Metrics ==="
npu-smi info -t temp -i $NPU -c $CHIP
npu-smi info -t power -i $NPU -c $CHIP
npu-smi info -t memory -i $NPU -c $CHIP
```

### Resource Monitoring Script

```bash
#!/bin/bash

echo "=== NPU Resource Monitor $(date) ==="

for npu in $(npu-smi info -l 2>/dev/null | grep -oP 'NPU\s*:\s*\K[0-9]+'); do
    echo ""
    echo "--- NPU $npu ---"
    temp=$(npu-smi info -t temp -i $npu -c 0 2>/dev/null | grep -oP 'NPU Temperature\s*:\s*\K[0-9]+' || echo "N/A")
    power=$(npu-smi info -t power -i $npu -c 0 2>/dev/null | grep -oP 'Power Usage\s*:\s*\K[0-9.]+' || echo "N/A")
    mem=$(npu-smi info -t memory -i $npu -c 0 2>/dev/null | grep -oP 'Memory Usage Rate\s*:\s*\K[0-9]+' || echo "N/A")
    echo "  Temperature: ${temp}°C"
    echo "  Power: ${power}W"
    echo "  Memory Usage: ${mem}%"
done
```

### Error Check Script

```bash
#!/bin/bash

NPU=0
CHIP=0

echo "=== Error Check ==="
echo "ECC Errors:"
npu-smi info -t ecc -i $NPU -c $CHIP

echo ""
echo "Health Status:"
npu-smi info -t health -i $NPU
```

### Full System Report

```bash
#!/bin/bash

NPU=0
CHIP=0

echo "=== Advanced System Report ==="
echo ""
echo "Processes:"
npu-smi info proc -i $NPU -c $CHIP 2>/dev/null || echo "Process info not available"

echo ""
echo "ECC Status:"
npu-smi info -t ecc -i $NPU -c $CHIP

echo ""
echo "Utilization:"
npu-smi info -t usages -i $NPU -c $CHIP

echo ""
echo "PCIe Info:"
npu-smi info -t pcie-info -i $NPU -c $CHIP

echo ""
echo "Product Info:"
npu-smi info -t product -i $NPU -c $CHIP
```
