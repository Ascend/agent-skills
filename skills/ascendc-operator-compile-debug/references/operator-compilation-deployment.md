# 算子编译与部署

本文档是 ascendc-operator-compile-debug Skill 的参考文档，包含算子编译、部署和常见问题解决方案。

## 目录

1. [算子编译步骤](#算子编译步骤)
2. [常见编译错误与解决方案](#常见编译错误与解决方案)
3. [算子部署与安装](#算子部署与安装)
4. [安装后环境配置](#安装后环境配置)

## 算子编译步骤

### 1. 编译算子工程
编译算子工程使用build.sh脚本，支持以下参数配置：
```bash
# 进入算子工程目录（请替换为您的算子工程名称）
cd {YOUR_OPERATOR_PROJECT_NAME}

# 按下述命令执行编译脚本完成编译
bash build.sh --pkg --ops=${OPERATOR_NAME} --soc=${soc_version}
```

**参数说明：**
- `--pkg`：生成算子安装包
- `--ops`（可选）：${OPERATOR_NAME}表示待编译算子，不指定时默认编译所有算子。格式形如"apply_rotary_pos_emb,rope_quant_kvcache,..."，多算子之间用英文逗号","分隔
- `--soc`：${soc_version}表示NPU型号，可以通过`npu-smi info`命令自行获取
  - 包含"910B"等关键字"使用ascend910b"
  - 包含"Ascend910、910C"等关键字"使用"ascend910_93"
  - 包含"Ascend950"等关键字"使用"ascend950"

编译成功后，会在build_out目录下生成以下关键文件：
- `custom_opp_ubuntu_aarch64.run`：算子安装包，用于后续部署
- 其他中间文件和库文件（无需手动处理）

## 常见编译错误与解决方案

1. **问题**：ModuleNotFoundError: No module named 'msopgen'
   **解决方案**：设置正确的PYTHONPATH环境变量
   ```bash
   # 确保ASCEND_HOME_PATH环境变量已经设置
   if [ -z "$ASCEND_HOME_PATH" ]; then
       echo "错误：ASCEND_HOME_PATH环境变量未设置"
       echo "请先完成前置步骤：设置CANN环境"
       exit 1
   fi
   export PYTHONPATH=$ASCEND_HOME_PATH/python/site-packages:$PYTHONPATH
   ```

2. **问题**：Get cann install path failed
   **解决方案**：确保已正确source CANN环境变量脚本
   ```bash
   # 确保ASCEND_HOME_PATH环境变量已经设置
   if [ -z "$ASCEND_HOME_PATH" ]; then
       echo "错误：ASCEND_HOME_PATH环境变量未设置"
       echo "请先完成前置步骤：设置CANN环境"
       exit 1
   fi
   ```

3. **问题**：ld.lld: error: cannot open ... .o文件
   **解决方案**：检查头文件是否完整，创建缺失的头文件（如`add_custom_tiling_key.h`）

4. **问题**：RuntimeError: Bit width:1 in ASCENDC_TPL_UINT_DECL schMode is not enough to represent all values [0,1,2]
   **解决方案**：将tiling key的bit width从1修改为2
   ```cpp
   // 修改前
   ASCENDC_TPL_UINT_DECL(schMode, 1, ...)
   // 修改后
   ASCENDC_TPL_UINT_DECL(schMode, 2, ...)
   ```

5. **问题**：编译时找不到头文件或库
   **解决方案**：检查CMakeLists.txt中的路径配置，确保包含所有必要的头文件和库路径

## 算子部署与安装

编译成功后，使用生成的run包安装算子：

```bash
# 确保ASCEND_HOME_PATH环境变量已经设置
if [ -z "$ASCEND_HOME_PATH" ]; then
    echo "错误：ASCEND_HOME_PATH环境变量未设置"
    echo "请先完成前置步骤：设置CANN环境"
    exit 1
fi

# 参考下述命令直接安装算子包到CANN环境
bash cann-ops-*-custom-linux-*.run
```

安装后，算子会被部署到以下目录结构：
- `${ASCEND_HOME_PATH}/opp/vendors/customize/op_api/`：包含头文件和库文件
- `${ASCEND_HOME_PATH}/opp/vendors/customize/op_impl/`：包含算子实现文件
- `${ASCEND_HOME_PATH}/opp/vendors/customize/op_proto/`：包含算子原型定义

## 安装后环境配置

安装算子包后，需要设置以下环境变量以确保正确使用：

```bash
# 确保ASCEND_HOME_PATH环境变量已经设置
if [ -z "$ASCEND_HOME_PATH" ]; then
    echo "错误：ASCEND_HOME_PATH环境变量未设置"
    echo "请先完成前置步骤：设置CANN环境"
    exit 1
fi

# 设置LD_LIBRARY_PATH环境变量，指向算子库文件目录
export LD_LIBRARY_PATH=$ASCEND_HOME_PATH/opp/vendors/customize/op_api/lib/:${LD_LIBRARY_PATH}

# 如果有其他环境变量脚本，也需要source
if [ -f "$ASCEND_HOME_PATH/opp/vendors/customize/bin/set_env.bash" ]; then
    source $ASCEND_HOME_PATH/opp/vendors/customize/bin/set_env.bash
fi
```

这些环境变量确保应用程序能够找到算子的头文件和库文件，正常调用算子功能。
