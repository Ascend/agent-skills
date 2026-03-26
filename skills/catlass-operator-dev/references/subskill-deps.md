# Catlass 算子开发子 Skill 依赖

```
确认 OPS_PROJECT_ROOT、USER_OP_PROJECT（见 project-directory-terms.md）
              │
              ▼
catlass-module-import（在 OPS_PROJECT_ROOT 下克隆 catlass，得到 <OPS_PROJECT_ROOT>/catlass/）
              │
              ▼
catlass-operator-design
              │
              ▼
catlass-operator-code-gen（输出写入 USER_OP_PROJECT；含 examples/test_aclnn_<op>.cpp）
              │
              ▼
ascendc-operator-compile-debug（在用户工程 build 下编译、部署、运行）
              │
              ▼
ascendc-operator-precision-eval（精度验证；无法继续则说明具体原因并停止）
              │
              ▼
ascendc-operator-doc-gen（可选）
```

**说明**：

- **工程目录**：见 [project-directory-terms.md](project-directory-terms.md)（OPS_PROJECT_ROOT / USER_OP_PROJECT）。  
- **交付物**：可独立编译的算子工程，见 [standalone-catlass-op-project.md](standalone-catlass-op-project.md)。  
- **代码生成**：统一使用 **catlass-operator-code-gen**（已废弃 catlass-example-to-kernel）。  
- **编译调试**：统一使用 **ascendc-operator-compile-debug**（已废弃 catlass-operator-compile-debug）。  
- **精度验证**：使用 **ascendc-operator-precision-eval**；若实在无法继续则向用户说明具体原因并停止。  
- **性能调优**：**catlass-operator-performance-optim**，按需。
