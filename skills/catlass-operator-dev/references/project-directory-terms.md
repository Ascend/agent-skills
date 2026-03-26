# Catlass 系列 Skill 工程目录术语（统一）

以下术语在 **catlass-operator-dev**、**catlass-operator-design**、**catlass-operator-code-gen**、**catlass-module-import**、**catlass-operator-performance-optim** 等 Catlass 相关 skill 中统一使用。

| 术语 | 含义 |
|------|------|
| **OPS_PROJECT_ROOT** | 算子工程根目录：包含 `build.sh`、`CMakeLists.txt`、`ops/` 的目录（例如 `ops-project`）。clone catlass 时必须在此目录下执行，得到 `<OPS_PROJECT_ROOT>/catlass/`。 |
| **USER_OP_PROJECT** | 单个算子所在目录：`<OPS_PROJECT_ROOT>/ops/<算子名>/`，即 `op_host`、`op_kernel`、`examples/` 等所在位置。设计文档与代码生成的交付路径均指此处。 |
| **catlass 目录** | `<OPS_PROJECT_ROOT>/catlass/`，含 `include/`、`examples/`。禁止放在 `ops/<算子名>/` 下。 |

**约定**：步骤 2（catlass-module-import）的工作目录为 **OPS_PROJECT_ROOT**；设计、代码生成、编译与精度验证针对的算子目录为 **USER_OP_PROJECT**。
