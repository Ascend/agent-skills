#!/bin/bash
# Create Ascend NPU Docker container with proper device mappings
# Usage: run-ascend-container.sh <image> <container_name> [--mode privileged|basic|full] [--device-list "0,1,2,3"]

set -e

detect_devices() {
  ls /dev/davinci* 2>/dev/null | grep -oE 'davinci[0-9]+$' | grep -oE '[0-9]+' | sort -n | tr '\n' ' ' | sed 's/ $//'
}

parse_device_list() {
  local list="$1"
  local devices=""
  
  if [ -z "$list" ]; then
    devices=$(detect_devices)
  else
    IFS=',' read -ra parts <<< "$list"
    for part in "${parts[@]}"; do
      if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        for ((i=${BASH_REMATCH[1]}; i<=${BASH_REMATCH[2]}; i++)); do
          devices="$devices $i"
        done
      else
        devices="$devices $part"
      fi
    done
  fi
  echo "$devices"
}

generate_device_args() {
  local devices="$1"
  local args=""
  for dev in $devices; do
    args="$args --device=/dev/davinci$dev"
  done
  echo "$args"
}

usage() {
  local available=$(detect_devices)
  local count=$(echo "$available" | wc -w)
  echo "Usage: $0 <image> <container_name> [options]"
  echo ""
  echo "Options:"
  echo "  --mode <mode>        Container mode: privileged (default), basic, full"
  echo "  --device-list <list> Devices to mount (default: all detected)"
  echo "                       Formats: \"0,1,2,3\" or \"0-3\" or \"0,2-4,7\""
  echo ""
  echo "Detected NPU devices: $available (total: $count)"
  echo ""
  echo "Modes:"
  echo "  privileged  Maximum permissions (--privileged), suitable when no specific requirements"
  echo "  basic       Specific devices with --net=host, for inference workloads"
  echo "  full        With profiling, logging, dump support"
  echo ""
  echo "Examples:"
  echo "  $0 ascendhub.huawei.com/public-ascendhub/ascend-pytorch:24.0.RC1 my-ascend"
  echo "  $0 ascendhub.huawei.com/public-ascendhub/ascend-pytorch:24.0.RC1 my-ascend --mode basic"
  echo "  $0 ascendhub.huawei.com/public-ascendhub/ascend-pytorch:24.0.RC1 my-ascend --device-list \"0,1,2,3\""
  echo "  $0 ascendhub.huawei.com/public-ascendhub/ascend-pytorch:24.0.RC1 my-ascend --mode full --device-list \"0-7\""
  exit 1
}

if [ $# -lt 2 ]; then
  usage
fi

IMAGE=$1
CONTAINER_NAME=$2
shift 2

MODE="privileged"
DEVICE_LIST=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --device-list)
      DEVICE_LIST="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

DEVICES=$(parse_device_list "$DEVICE_LIST")
DEVICE_ARGS=$(generate_device_args "$DEVICES")

run_privileged() {
  docker run -itd --privileged --name=$CONTAINER_NAME --ipc=host --net=host \
    --device=/dev/davinci_manager \
    --device=/dev/devmm_svm \
    --device=/dev/hisi_hdc \
    -v /usr/local/sbin:/usr/local/sbin:ro \
    -v /usr/local/Ascend/driver:/usr/local/Ascend/driver:ro \
    -v /home:/home \
    -w /home \
    $IMAGE \
    /bin/bash
}

run_basic() {
  docker run -itd --net=host \
    --name=$CONTAINER_NAME \
    --device=/dev/davinci_manager \
    --device=/dev/hisi_hdc \
    --device=/dev/devmm_svm \
    $DEVICE_ARGS \
    -v /usr/local/Ascend/driver:/usr/local/Ascend/driver:ro \
    -v /usr/local/sbin:/usr/local/sbin:ro \
    -v /etc/localtime:/etc/localtime \
    -v /home:/home \
    $IMAGE \
    /bin/bash
}

run_full() {
  docker run -itd --ipc=host \
    --name=$CONTAINER_NAME \
    --device=/dev/davinci_manager \
    --device=/dev/devmm_svm \
    --device=/dev/hisi_hdc \
    $DEVICE_ARGS \
    -v /usr/local/Ascend/driver:/usr/local/Ascend/driver \
    -v /usr/local/Ascend/add-ons/:/usr/local/Ascend/add-ons/ \
    -v /usr/local/sbin/npu-smi:/usr/local/sbin/npu-smi \
    -v /usr/local/sbin/:/usr/local/sbin/ \
    -v /var/log/npu/conf/slog/slog.conf:/var/log/npu/conf/slog/slog.conf \
    -v /var/log/npu/slog/:/var/log/npu/slog \
    -v /var/log/npu/profiling/:/var/log/npu/profiling \
    -v /var/log/npu/dump/:/var/log/npu/dump \
    -v /var/log/npu/:/usr/slog \
    -v /etc/localtime:/etc/localtime \
    -v /home:/home \
    $IMAGE \
    /bin/bash
}

case $MODE in
  privileged)
    run_privileged
    ;;
  basic)
    run_basic
    ;;
  full)
    run_full
    ;;
  *)
    echo "Unknown mode: $MODE"
    usage
    ;;
esac
