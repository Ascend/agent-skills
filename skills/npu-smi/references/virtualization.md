# Virtualization (vNPU) Reference

Detailed reference for npu-smi virtualization commands.

## Table of Contents

1. [Overview](#overview)
2. [AVI Mode](#avi-mode)
3. [Templates](#templates)
4. [vNPU Management](#vnpu-management)
5. [Examples](#examples)

---

## Overview

vNPU (Virtual NPU) allows physical NPU resources to be partitioned into multiple virtual NPU instances for:
- Multi-tenant environments
- Resource isolation
- Development/testing isolation

### Supported Platforms

- Atlas 200I A2 Acceleration Module
- Atlas 300I Duo Inference Card

---

## AVI Mode

AVI (Ascend Virtualization Infrastructure) mode determines the virtualization type.

### Query AVI Mode

```bash
npu-smi info -t vnpu-mode
```

### Set AVI Mode

```bash
npu-smi set -t vnpu-mode -d <value>
```

| Value | Mode | Description |
|-------|------|-------------|
| 0 | Container | Docker/container-based virtualization |
| 1 | VM | Virtual machine-based virtualization |

**Note**: Changing AVI mode may require device restart.

---

## Templates

Templates define the resource allocation for vNPU instances.

### List All Templates

```bash
npu-smi info -t template-info
```

### List Templates for Specific Device

```bash
npu-smi info -t template-info -i <id>
```

### Template Information

Each template specifies:
- AI Core count
- Memory size
- Supported vNPU count

### Common Templates

| Template | AI Cores | Memory | Use Case |
|----------|----------|--------|----------|
| vir02 | 2 | 2GB | Light workloads |
| vir04 | 4 | 4GB | Medium workloads |
| vir08 | 8 | 8GB | Heavy workloads |

**Note**: Available templates vary by hardware platform.

---

## vNPU Management

### Query vNPU Information

```bash
npu-smi info -t info-vnpu -i <id> -c <chip_id>
```

**Output Fields**:
| Field | Description |
|-------|-------------|
| vNPU ID | Virtual NPU identifier |
| vNPU Group ID | Group identifier |
| AI Core Num | Number of AI cores allocated |
| Memory Size | Allocated memory |
| Status | Current status |

### Create vNPU

```bash
npu-smi set -t create-vnpu -i <id> -c <chip_id> -f <template> [-v <vnpu_id>] [-g <vgroup_id>]
```

**Parameters**:
| Parameter | Required | Description |
|-----------|----------|-------------|
| id | Yes | Physical NPU ID |
| chip_id | Yes | Chip ID |
| template | Yes | Template name (e.g., vir02, vir04) |
| vnpu_id | No | Custom vNPU ID: `[phy_id*16+100, phy_id*16+115]` |
| vgroup_id | No | Group ID: 0, 1, 2, or 3 |

### Destroy vNPU

```bash
npu-smi set -t destroy-vnpu -i <id> -c <chip_id> -v <vnpu_id>
```

**Parameters**:
| Parameter | Required | Description |
|-----------|----------|-------------|
| id | Yes | Physical NPU ID |
| chip_id | Yes | Chip ID |
| vnpu_id | Yes | vNPU ID to destroy |

---

## Examples

### List Current vNPU Status

```bash
#!/bin/bash

NPU=0
CHIP=0

echo "=== vNPU Status ==="
echo ""
echo "AVI Mode:"
npu-smi info -t vnpu-mode
echo ""
echo "Available Templates:"
npu-smi info -t template-info -i $NPU
echo ""
echo "Current vNPU Info:"
npu-smi info -t info-vnpu -i $NPU -c $CHIP
```

### Create vNPU Instance

```bash
#!/bin/bash

NPU=0
CHIP=0
TEMPLATE="vir04"
VNPU_ID=103

echo "Creating vNPU..."
npu-smi set -t create-vnpu -i $NPU -c $CHIP -f $TEMPLATE -v $VNPU_ID

echo ""
echo "Verifying..."
npu-smi info -t info-vnpu -i $NPU -c $CHIP
```

### Create Multiple vNPU Instances

```bash
#!/bin/bash

NPU=0
CHIP=0

echo "Creating multiple vNPU instances..."

# Create first vNPU (auto ID)
npu-smi set -t create-vnpu -i $NPU -c $CHIP -f vir02

# Create second vNPU with specific ID
npu-smi set -t create-vnpu -i $NPU -c $CHIP -f vir02 -v 101

# Create third vNPU in different group
npu-smi set -t create-vnpu -i $NPU -c $CHIP -f vir02 -v 102 -g 1

echo ""
echo "Verifying all vNPU instances..."
npu-smi info -t info-vnpu -i $NPU -c $CHIP
```

### Destroy vNPU Instance

```bash
#!/bin/bash

NPU=0
CHIP=0
VNPU_ID=103

echo "Destroying vNPU $VNPU_ID..."
npu-smi set -t destroy-vnpu -i $NPU -c $CHIP -v $VNPU_ID

echo ""
echo "Verifying..."
npu-smi info -t info-vnpu -i $NPU -c $CHIP
```

### Clean Up All vNPU Instances

```bash
#!/bin/bash

NPU=0
CHIP=0

echo "Current vNPU instances:"
npu-smi info -t info-vnpu -i $NPU -c $CHIP

echo ""
echo "To destroy specific vNPU, run:"
echo "npu-smi set -t destroy-vnpu -i $NPU -c $CHIP -v <vnpu_id>"
```

### Full vNPU Lifecycle

```bash
#!/bin/bash

NPU=0
CHIP=0

echo "=== vNPU Lifecycle Demo ==="

# Step 1: Check current state
echo "1. Checking current state..."
npu-smi info -t info-vnpu -i $NPU -c $CHIP

# Step 2: Create vNPU
echo ""
echo "2. Creating vNPU..."
npu-smi set -t create-vnpu -i $NPU -c $CHIP -f vir04 -v 100

# Step 3: Verify creation
echo ""
echo "3. Verifying creation..."
npu-smi info -t info-vnpu -i $NPU -c $CHIP

# Step 4: Use vNPU (placeholder - actual usage depends on workload)
echo ""
echo "4. vNPU ready for use..."

# Step 5: Destroy when done
echo ""
echo "5. Destroying vNPU..."
npu-smi set -t destroy-vnpu -i $NPU -c $CHIP -v 100

# Step 6: Verify destruction
echo ""
echo "6. Verifying destruction..."
npu-smi info -t info-vnpu -i $NPU -c $CHIP

echo ""
echo "Done!"
```

## Best Practices

1. **Resource Planning**: Choose appropriate template based on workload requirements
2. **ID Management**: Use consistent vNPU ID scheme for easier management
3. **Cleanup**: Always destroy vNPU instances when no longer needed
4. **Monitoring**: Regularly check vNPU status during operation
5. **Isolation**: Use vgroups for workload isolation when needed
