# Firmware Upgrade Reference

Detailed reference for npu-smi firmware upgrade commands.

## Table of Contents

1. [Upgrade Workflow](#upgrade-workflow)
2. [Firmware Components](#firmware-components)
3. [MCU Upgrade](#mcu-upgrade)
4. [Bootloader Upgrade](#bootloader-upgrade)
5. [VRD Upgrade](#vrd-upgrade)
6. [Troubleshooting](#troubleshooting)

---

## Upgrade Workflow

### Standard Workflow

```
1. Query current version    → npu-smi upgrade -b <item> -i <id>
2. Upload firmware          → npu-smi upgrade -t <item> -i <id> -f <file>
3. Check upgrade status     → npu-smi upgrade -q <item> -i <id>
4. Activate firmware        → npu-smi upgrade -a <item> -i <id>
5. Restart/Power cycle      → As required by component
```

### Commands Reference

| Command | Description |
|---------|-------------|
| `npu-smi upgrade -b <item> -i <id>` | Query current version |
| `npu-smi upgrade -t <item> -i <id> -f <file>` | Upload firmware file |
| `npu-smi upgrade -q <item> -i <id>` | Check upgrade status |
| `npu-smi upgrade -a <item> -i <id>` | Activate new firmware |

---

## Firmware Components

### Component Overview

| Component | Item Name | Firmware File | Restart Required |
|-----------|-----------|---------------|------------------|
| MCU | `mcu` | `.hpm` file | Yes (restart) |
| Bootloader | `bootloader` | `.hpm` file | Yes (restart) |
| VRD | `vrd` | Built-in | Yes (power cycle 30s) |

### Important Notes

- **MCU**: Management Control Unit - handles device management
- **Bootloader**: Initial boot firmware
- **VRD**: Voltage Regulator Device - power management

**Warning**: Do not interrupt firmware upgrade process. Power loss during upgrade may brick the device.

---

## MCU Upgrade

### Complete Procedure

```bash
#!/bin/bash

NPU=0
FIRMWARE="mcu_v2.1.0.hpm"

echo "=== MCU Upgrade Procedure ==="

# Step 1: Query current version
echo "1. Current version:"
npu-smi upgrade -b mcu -i $NPU

# Step 2: Upload firmware
echo ""
echo "2. Uploading firmware..."
npu-smi upgrade -t mcu -i $NPU -f $FIRMWARE

# Step 3: Check status
echo ""
echo "3. Checking status..."
npu-smi upgrade -q mcu -i $NPU

# Step 4: Activate
echo ""
echo "4. Activating..."
npu-smi upgrade -a mcu -i $NPU

echo ""
echo "5. Restart required to complete upgrade!"
echo "Run: reboot"
```

### Expected Output

```
MCU Version: 1.0.0
Upgrade Status: Success
Activation: Pending restart
```

---

## Bootloader Upgrade

### Complete Procedure

```bash
#!/bin/bash

NPU=0
FIRMWARE="bootloader_v1.5.0.hpm"

echo "=== Bootloader Upgrade Procedure ==="

# Step 1: Query current version
echo "1. Current version:"
npu-smi upgrade -b bootloader -i $NPU

# Step 2: Upload firmware
echo ""
echo "2. Uploading firmware..."
npu-smi upgrade -t bootloader -i $NPU -f $FIRMWARE

# Step 3: Check status
echo ""
echo "3. Checking status..."
npu-smi upgrade -q bootloader -i $NPU

# Step 4: Activate
echo ""
echo "4. Activating..."
npu-smi upgrade -a bootloader -i $NPU

echo ""
echo "5. Restart required to complete upgrade!"
echo "Run: reboot"
```

---

## VRD Upgrade

### Complete Procedure

```bash
#!/bin/bash

NPU=0

echo "=== VRD Upgrade Procedure ==="

# Step 1: Query current version
echo "1. Current version:"
npu-smi upgrade -b vrd -i $NPU

# Step 2: Start upgrade (no firmware file needed)
echo ""
echo "2. Starting VRD upgrade..."
npu-smi upgrade -t vrd -i $NPU

# Step 3: Check status
echo ""
echo "3. Checking status..."
npu-smi upgrade -q vrd -i $NPU

# Step 4: Activate
echo ""
echo "4. Activating..."
npu-smi upgrade -a vrd -i $NPU

echo ""
echo "5. Power cycle required to complete upgrade!"
echo "Power off for at least 30 seconds, then power on."
```

### Important Notes for VRD

- **Power cycle required**: Must power off for at least 30 seconds
- **No firmware file**: VRD upgrade uses built-in firmware
- **Critical**: Do not skip power cycle step

---

## Troubleshooting

### Common Issues

#### Upgrade Fails to Start

**Symptoms**: `Upgrade failed` or `Invalid firmware`

**Solutions**:
1. Verify firmware file is correct for your device
2. Check file permissions
3. Ensure sufficient disk space
4. Verify device is healthy: `npu-smi info -t health -i <id>`

#### Upgrade Stuck

**Symptoms**: Status shows `In progress` indefinitely

**Solutions**:
1. Wait longer (large files may take time)
2. Check system logs
3. If truly stuck, may need device reset

#### Activation Fails

**Symptoms**: `Activation failed` after upgrade

**Solutions**:
1. Verify upgrade completed successfully before activation
2. Check device health
3. Retry activation
4. If persistent, contact support

#### Post-Restart Issues

**Symptoms**: Device not responding after restart

**Solutions**:
1. Wait for full boot (may take several minutes)
2. Check `npu-smi info -l` for device status
3. Check system logs
4. For VRD: ensure power cycle was 30+ seconds

### Rollback

If upgrade causes issues:

1. Some firmware versions support automatic rollback on failure
2. Manual rollback may require previous firmware file
3. Contact Huawei support for critical failures

### Upgrade Verification Script

```bash
#!/bin/bash

NPU=0

echo "=== Firmware Versions ==="
echo ""
echo "MCU:"
npu-smi upgrade -b mcu -i $NPU
echo ""
echo "Bootloader:"
npu-smi upgrade -b bootloader -i $NPU
echo ""
echo "VRD:"
npu-smi upgrade -b vrd -i $NPU
```
