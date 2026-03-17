# Configuration Reference

Detailed reference for npu-smi configuration commands.

## Table of Contents

1. [Thresholds](#thresholds)
2. [Mode Configuration](#mode-configuration)
3. [Fan Control](#fan-control)
4. [System Settings](#system-settings)
5. [Clear Commands](#clear-commands)
6. [Examples](#examples)

---

## Thresholds

### Temperature Threshold

```bash
npu-smi set -t temperature -i <id> -c <chip_id> -d <value>
```

| Parameter | Type | Description |
|-----------|------|-------------|
| value | integer | Temperature threshold in °C |

### Power Limit

```bash
npu-smi set -t power-limit -i <id> -c <chip_id> -d <value>
```

| Parameter | Type | Description |
|-----------|------|-------------|
| value | integer | Power limit in Watts |

---

## Mode Configuration

### ECC Mode

```bash
npu-smi set -t ecc-mode -i <id> -c <chip_id> -d <value>
```

| Value | Mode |
|-------|------|
| 0 | Disable |
| 1 | Enable |

### Compute Mode

```bash
npu-smi set -t compute-mode -i <id> -c <chip_id> -d <value>
```

| Value | Mode | Description |
|-------|------|-------------|
| 0 | Default | Multiple processes can use the device |
| 1 | Exclusive | Only one process can use the device |
| 2 | Prohibited | No processes can use the device |

### Persistence Mode

```bash
npu-smi set -t persistence-mode -i <id> -d <value>
```

| Value | Mode |
|-------|------|
| 0 | Disable |
| 1 | Enable |

Persistence mode keeps driver loaded even when no processes are using the device, reducing latency for subsequent operations.

### P2P Configuration

```bash
npu-smi set -t p2p-mem-cfg -i <id> -c <chip_id> -d <value>
```

| Value | Mode |
|-------|------|
| 0 | Disable |
| 1 | Enable |

---

## Fan Control

### Set Fan Mode

```bash
npu-smi set -t pwm-mode -d <value>
```

| Value | Mode |
|-------|------|
| 0 | Manual |
| 1 | Automatic |

### Set Fan Speed (Manual Mode)

```bash
npu-smi set -t pwm-duty-ratio -d <value>
```

| Parameter | Range | Description |
|-----------|-------|-------------|
| value | 0-100 | Fan speed percentage |

**Note**: Only effective when fan mode is set to Manual (0).

---

## System Settings

### MAC Address

```bash
npu-smi set -t mac-addr -i <id> -c <chip_id> -d <mac_id> -s "XX:XX:XX:XX:XX:XX"
```

| Parameter | Description |
|-----------|-------------|
| mac_id | MAC interface: 0=eth0, 1=eth1, 2=eth2, 3=eth3 |
| mac_string | MAC address format "XX:XX:XX:XX:XX:XX" |

**Note**: Requires restart after change.

### Boot Medium

```bash
npu-smi set -t boot-select -i <id> -c <chip_id> -d <value>
```

| Value | Medium |
|-------|--------|
| 3 | M.2 SSD |
| 4 | eMMC |

**Note**: Requires restart after change.

### CPU Frequency

```bash
npu-smi set -t cpu-freq-up -i <id> -d <value>
```

| Value | CPU Frequency | AI Core Frequency |
|-------|--------------|-------------------|
| 0 | 1.9 GHz | 800 MHz |
| 1 | 1.0 GHz | 800 MHz |

### System Logging

```bash
npu-smi set -t sys-log-enable -d <value>
```

| Value | Mode |
|-------|------|
| 0 | Disable |
| 1 | Enable |

---

## Clear Commands

### Clear ECC Errors

```bash
npu-smi clear -t ecc-info -i <id> -c <chip_id>
```

Clears the ECC error counter for the specified device/chip.

### Restore Certificate Threshold

```bash
npu-smi clear -t tls-cert-period -i <id> -c <chip_id>
```

Restores the certificate expiration threshold to default (90 days).

---

## Examples

### Configure Safe Defaults

```bash
#!/bin/bash

NPU=0
CHIP=0

echo "Setting safe defaults..."
npu-smi set -t temperature -i $NPU -c $CHIP -d 80
npu-smi set -t power-limit -i $NPU -c $CHIP -d 310
npu-smi set -t ecc-mode -i $NPU -c $CHIP -d 1
echo "Done!"
```

### Temperature-Based Fan Control

```bash
#!/bin/bash

NPU=0
CHIP=0

# Get current temperature
TEMP=$(npu-smi info -t temp -i $NPU -c $CHIP 2>/dev/null | grep -oP 'NPU Temperature\s*:\s*\K[0-9]+' || echo "0")

# Switch to manual mode
npu-smi set -t pwm-mode -d 0

# Set fan speed based on temperature
if [ $TEMP -gt 70 ]; then
    npu-smi set -t pwm-duty-ratio -d 90
elif [ $TEMP -gt 60 ]; then
    npu-smi set -t pwm-duty-ratio -d 70
else
    npu-smi set -t pwm-duty-ratio -d 50
fi

echo "Temperature: ${TEMP}°C, Fan speed adjusted"
```

### Enable Persistence Mode on All Devices

```bash
#!/bin/bash

for npu in $(npu-smi info -l 2>/dev/null | grep -oP 'NPU\s*:\s*\K[0-9]+'); do
    echo "Enabling persistence mode on NPU $npu..."
    npu-smi set -t persistence-mode -i $npu -d 1
done

echo "Done!"
```

### Configure for Multi-Process Workload

```bash
#!/bin/bash

NPU=0
CHIP=0

echo "Configuring for multi-process workload..."
npu-smi set -t compute-mode -i $NPU -c $CHIP -d 0    # Default (shared)
npu-smi set -t ecc-mode -i $NPU -c $CHIP -d 1        # Enable ECC
npu-smi set -t p2p-mem-cfg -i $NPU -c $CHIP -d 1     # Enable P2P
echo "Done!"
```

### Configure for Exclusive Single-Process Workload

```bash
#!/bin/bash

NPU=0
CHIP=0

echo "Configuring for exclusive single-process workload..."
npu-smi set -t compute-mode -i $NPU -c $CHIP -d 1    # Exclusive mode
npu-smi set -t ecc-mode -i $NPU -c $CHIP -d 1        # Enable ECC
echo "Done!"
```

### Reset All Error Counters

```bash
#!/bin/bash

for npu in $(npu-smi info -l 2>/dev/null | grep -oP 'NPU\s*:\s*\K[0-9]+'); do
    for chip in $(npu-smi info -m 2>/dev/null | grep "NPU $npu" | grep -oP 'Chip\s*:\s*\K[0-9]+'); do
        echo "Clearing ECC errors on NPU $npu, Chip $chip..."
        npu-smi clear -t ecc-info -i $npu -c $chip
    done
done

echo "Done!"
```
