# 多语言安全代码审查 (Security Code Review)

## 适用场景 (When to use this skill)

- **安全审查**: 对 Python、C++、Shell、Markdown 文件进行安全代码审查
- **Code Review**: 在代码评审中检查安全漏洞
- **新代码编写**: 编写安全的代码，避免常见漏洞
- **合规检查**: 满足安全合规要求 (CWE, CERT, OWASP)
- **CI/CD 集成**: 在流水线中集成安全扫描工具

---

## Python 安全审查

### 1. 代码注入

```python
# ❌ 不安全：eval/exec 执行用户输入
user_input = request.args.get("expr")
result = eval(user_input)  # 任意代码执行

# ✅ 安全：使用 ast.literal_eval 或白名单
import ast
result = ast.literal_eval(user_input)  # 仅解析字面量
```

```python
# ❌ 不安全：subprocess 使用 shell=True
import subprocess
subprocess.run(f"grep {user_input} /var/log/app.log", shell=True)  # 命令注入

# ✅ 安全：使用列表参数，避免 shell=True
subprocess.run(["grep", user_input, "/var/log/app.log"], shell=False)
```

### 2. SQL 注入

```python
# ❌ 不安全：字符串拼接 SQL
cursor.execute(f"SELECT * FROM users WHERE name = '{name}'")

# ✅ 安全：参数化查询
cursor.execute("SELECT * FROM users WHERE name = %s", (name,))
```

### 3. 反序列化漏洞

```python
# ❌ 不安全：pickle 加载不受信任的数据
import pickle
data = pickle.loads(untrusted_bytes)  # 任意代码执行

# ❌ 不安全：yaml.load 无 Loader
import yaml
config = yaml.load(untrusted_yaml)  # 任意代码执行

# ✅ 安全：使用 safe_load
config = yaml.safe_load(untrusted_yaml)

# ✅ 安全：使用 JSON 替代 pickle
import json
data = json.loads(untrusted_string)
```

### 4. 路径遍历

```python
# ❌ 不安全：直接拼接用户输入的路径
file_path = os.path.join("/data/uploads", user_filename)
with open(file_path) as f:  # ../../../etc/passwd
    content = f.read()

# ✅ 安全：验证解析后的路径在允许范围内
import os
base_dir = os.path.realpath("/data/uploads")
file_path = os.path.realpath(os.path.join(base_dir, user_filename))
if not file_path.startswith(base_dir):
    raise ValueError("Path traversal detected")
with open(file_path) as f:
    content = f.read()
```

### 5. 敏感信息泄露

```python
# ❌ 不安全：硬编码密钥
API_KEY = "sk-1234567890abcdef"
DB_PASSWORD = "admin123"

# ❌ 不安全：日志中记录敏感信息
logger.info(f"User login: password={password}")
logger.debug(f"API response: {response.json()}")  # 可能含敏感数据

# ✅ 安全：从环境变量读取
import os
API_KEY = os.environ["API_KEY"]
if not API_KEY:
    raise RuntimeError("API_KEY environment variable is required")

# ✅ 安全：日志脱敏
logger.info(f"User login: user={username}")
logger.debug(f"API response status: {response.status_code}")
```

### 6. assert 误用

```python
# ❌ 不安全：用 assert 做运行时检查（python -O 会跳过 assert）
assert user.is_admin, "Unauthorized"

# ✅ 安全：用显式条件判断
if not user.is_admin:
    raise PermissionError("Unauthorized")
```

### 7. 临时文件安全

```python
# ❌ 不安全：可预测的临时文件名
with open("/tmp/myapp_data.txt", "w") as f:  # 竞态条件 + 符号链接攻击
    f.write(data)

# ✅ 安全：使用 tempfile
import tempfile
with tempfile.NamedTemporaryFile(mode="w", delete=True) as f:
    f.write(data)
```

### 8. 正则表达式拒绝服务 (ReDoS)

```python
# ❌ 不安全：嵌套量词导致指数级回溯
import re
pattern = re.compile(r"(a+)+$")  # ReDoS
pattern.match("a" * 30 + "!")  # 极慢

# ✅ 安全：使用原子组或限制输入长度
pattern = re.compile(r"a+$")
if len(user_input) > 1000:
    raise ValueError("Input too long")
```

### 9. JSON 请求嵌套深度校验

```python
# ❌ 不安全：直接解析未限制深度的 JSON 请求
import json

def handle_request(raw_body: str):
    data = json.loads(raw_body)  # 无深度限制，恶意嵌套可导致栈溢出或 CPU/内存耗尽
    process(data)

# ❌ 不安全：递归遍历 JSON 无深度保护
def walk(obj):
    if isinstance(obj, dict):
        for v in obj.values():
            walk(v)  # 深层嵌套导致 RecursionError / 栈溢出
    elif isinstance(obj, list):
        for item in obj:
            walk(item)
```

```python
# ✅ 安全：解析前检查 JSON 嵌套深度
import json

MAX_JSON_DEPTH = 32  # 根据业务需求设置合理上限

def check_json_depth(raw_body: str, max_depth: int = MAX_JSON_DEPTH) -> int:
    """在解析前通过字符扫描快速检测嵌套深度（O(n) 时间，O(1) 空间）"""
    depth = 0
    max_seen = 0
    in_string = False
    escape = False
    for ch in raw_body:
        if escape:
            escape = False
            continue
        if ch == '\\':
            escape = True
            continue
        if ch == '"':
            in_string = not in_string
            continue
        if in_string:
            continue
        if ch in ('{', '['):
            depth += 1
            if depth > max_depth:
                raise ValueError(f"JSON nesting depth {depth} exceeds maximum allowed {max_depth}")
            max_seen = max(max_seen, depth)
        elif ch in ('}', ']'):
            depth -= 1
    return max_seen

def handle_request(raw_body: str):
    check_json_depth(raw_body)  # 先检查深度，再解析
    data = json.loads(raw_body)
    process(data)
```

```python
# ✅ 安全：使用 json.JSONDecoder 自定义解析深度限制（Python 3.x）
import json

class DepthLimitedDecoder(json.JSONDecoder):
    """限制 JSON 嵌套深度的解码器"""
    MAX_DEPTH = 32

    def __init__(self, *args, **kwargs):
        self._depth = 0
        super().__init__(*args, **kwargs)

    def decode(self, s, **kwargs):
        self._check_depth(s)
        return super().decode(s, **kwargs)

    def _check_depth(self, s: str):
        depth = 0
        in_string = False
        escape = False
        for ch in s:
            if escape:
                escape = False
                continue
            if ch == '\\':
                escape = True
                continue
            if ch == '"':
                in_string = not in_string
                continue
            if in_string:
                continue
            if ch in ('{', '['):
                depth += 1
                if depth > self.MAX_DEPTH:
                    raise json.JSONDecodeError(
                        f"JSON nesting depth exceeds {self.MAX_DEPTH}", s, 0
                    )
            elif ch in ('}', ']'):
                depth -= 1

# 使用示例
data = json.loads(raw_body, cls=DepthLimitedDecoder)
```

```python
# ✅ 安全：Web 框架中间件统一拦截（以 Flask 为例）
from flask import Flask, request, abort
import json

app = Flask(__name__)
MAX_JSON_DEPTH = 32

@app.before_request
def check_json_nesting_depth():
    if request.is_json:
        try:
            check_json_depth(request.get_data(as_text=True), MAX_JSON_DEPTH)
        except ValueError:
            abort(400, description="JSON nesting depth exceeds allowed limit")
```

**审查要点：**
- 搜索所有 `json.loads()`、`json.load()`、`request.get_json()`、`request.json` 调用
- 检查解析入口是否存在嵌套深度限制
- 检查递归遍历 JSON 数据结构的函数是否有递归深度保护
- 对于 HTTP/gRPC/WebSocket 等外部请求入口，嵌套深度限制应在**解析层/中间件**统一实施
- 建议最大深度：API 请求 ≤ 32 层，配置文件 ≤ 64 层（根据业务实际调整）
- 相关漏洞标准：CWE-674 (Uncontrolled Recursion)、CWE-400 (Uncontrolled Resource Consumption)

### 10. 特殊 Token 注入与多模态输入校验

```python
# ❌ 不安全：假设特殊 Token 必定成对出现，用硬索引取配对 Token 位置
import numpy as np

def process_multimodal_input(input_ids, config):
    # 查找 <|begin_of_image|> 和 <|end_of_image|> 的位置
    boi_positions = np.where(np.equal(input_ids, config.boi_token_id))[0]
    eoi_positions = np.where(np.equal(input_ids, config.eoi_token_id))[0]

    for i, boi_pos in enumerate(boi_positions):
        eoi_pos = eoi_positions[i]  # ← 致命：若 eoi 缺失/数量不匹配，数组越界 → DoS
        image_tokens = input_ids[boi_pos:eoi_pos]
        process_image(image_tokens)
```

```python
# ❌ 不安全：假设特定起始 Token 后的序列一定遵循内部私有协议格式
def process_vision_input(input_ids, config):
    vision_start_positions = np.where(np.equal(input_ids, config.vision_start_id))[0]

    for start_pos in vision_start_positions:
        # 假设 vision_start 后一定跟 image_pad 序列，直接按协议偏移取值
        image_count = input_ids[start_pos + 1]    # ← 可能越界
        width  = input_ids[start_pos + 2]          # ← 可能越界
        height = input_ids[start_pos + 3]          # ← 可能越界
        total_patches = width * height * image_count
        patches = input_ids[start_pos + 4 : start_pos + 4 + total_patches]  # ← 可能越界
        # 如果用户发送 <|vision_start|><|video_pad|><|vision_end|> 而非预期的 image_pad 序列
        # 上述偏移计算全部错误，导致数组越界 → 未捕获异常 → 进程崩溃
```

```python
# ✅ 安全：严格校验特殊 Token 的配对完整性和序列格式

def validate_special_token_pairs(input_ids: np.ndarray,
                                  begin_token_id: int,
                                  end_token_id: int,
                                  token_name: str = "special") -> list:
    """校验特殊 Token 严格成对出现且不交叉嵌套"""
    begin_positions = np.where(np.equal(input_ids, begin_token_id))[0].tolist()
    end_positions = np.where(np.equal(input_ids, end_token_id))[0].tolist()

    # 校验 1：数量必须相等
    if len(begin_positions) != len(end_positions):
        raise ValueError(
            f"Mismatched {token_name} tokens: "
            f"found {len(begin_positions)} begin vs {len(end_positions)} end"
        )

    # 校验 2：每对 begin 必须在对应 end 之前
    pairs = []
    for i, (begin_pos, end_pos) in enumerate(zip(begin_positions, end_positions)):
        if end_pos <= begin_pos:
            raise ValueError(
                f"{token_name} token pair {i}: end position {end_pos} "
                f"is not after begin position {begin_pos}"
            )
        pairs.append((begin_pos, end_pos))

    # 校验 3：相邻对不交叉
    for i in range(len(pairs) - 1):
        if pairs[i][1] > pairs[i + 1][0]:
            raise ValueError(
                f"{token_name} token pairs {i} and {i+1} overlap"
            )

    return pairs

def process_multimodal_input(input_ids, config):
    try:
        pairs = validate_special_token_pairs(
            input_ids, config.boi_token_id, config.eoi_token_id, "image"
        )
        for boi_pos, eoi_pos in pairs:
            image_tokens = input_ids[boi_pos:eoi_pos]
            process_image(image_tokens)
    except ValueError as e:
        logger.warning(f"Invalid multimodal input rejected: {e}")
        raise InvalidRequestError(str(e))  # 返回 4xx，不崩溃
```

```python
# ✅ 安全：校验私有协议格式序列，不信任 Token 序列的隐式假设

def parse_vision_sequence(input_ids: np.ndarray,
                           start_pos: int,
                           end_pos: int,
                           config) -> dict:
    """安全解析 vision_start..vision_end 之间的序列"""
    seq = input_ids[start_pos + 1 : end_pos]  # 取 start/end 之间的内容

    # 校验 1：序列非空
    if len(seq) == 0:
        raise ValueError(f"Empty vision sequence at position {start_pos}")

    # 校验 2：校验序列中的 Token 类型是否合法（白名单）
    allowed_tokens = {config.image_pad_id, config.video_pad_id, config.audio_pad_id}
    actual_tokens = set(seq.tolist())
    illegal_tokens = actual_tokens - allowed_tokens
    if illegal_tokens:
        raise ValueError(
            f"Illegal tokens in vision sequence: {illegal_tokens}, "
            f"allowed: {allowed_tokens}"
        )

    # 校验 3：按实际内容类型分派，不硬假设格式
    if config.image_pad_id in actual_tokens:
        return {"type": "image", "pad_count": int(np.sum(seq == config.image_pad_id))}
    elif config.video_pad_id in actual_tokens:
        return {"type": "video", "pad_count": int(np.sum(seq == config.video_pad_id))}
    else:
        raise ValueError(f"Unrecognized vision sequence content at position {start_pos}")

def process_vision_input_safe(input_ids, config):
    try:
        # 第一步：校验 vision_start / vision_end 成对
        pairs = validate_special_token_pairs(
            input_ids, config.vision_start_id, config.vision_end_id, "vision"
        )
        # 第二步：逐对解析，每对都做格式校验
        for start_pos, end_pos in pairs:
            info = parse_vision_sequence(input_ids, start_pos, end_pos, config)
            dispatch_vision_processing(info)
    except ValueError as e:
        logger.warning(f"Invalid vision input rejected: {e}")
        raise InvalidRequestError(str(e))
```

```python
# ✅ 安全：框架层统一异常捕获，防止未预期异常导致进程崩溃

def inference_request_handler(request):
    """推理请求入口 — 框架层兜底"""
    try:
        input_ids = tokenize(request.prompt)
        validate_multimodal_tokens(input_ids, model_config)
        result = model.forward(input_ids)
        return SuccessResponse(result)
    except InvalidRequestError as e:
        return ErrorResponse(400, f"Bad request: {e}")  # 客户端错误，优雅拒绝
    except (IndexError, KeyError, ValueError) as e:
        # 兜底：捕获所有可能由恶意输入触发的数组越界/键缺失/值错误
        logger.error(f"Input validation gap detected: {type(e).__name__}: {e}")
        return ErrorResponse(400, "Malformed input")
    except Exception as e:
        # 最终兜底：任何未预期异常都不应导致进程退出
        logger.error(f"Unexpected error in inference handler: {e}", exc_info=True)
        return ErrorResponse(500, "Internal server error")
```

**审查要点：**
- 搜索所有 `np.where`、`np.equal`、`torch.where`、`torch.eq` + 数组索引操作（`[0]`、`[i]`、`positions[n]`），检查是否假设结果非空或长度匹配
- 搜索所有特殊 Token ID 的查找和配对逻辑（`boi`/`eoi`、`vision_start`/`vision_end`、`audio_start`/`audio_end`、`begin_of_image`/`end_of_image` 等），检查是否验证了成对完整性
- 检查多模态处理代码是否对 Token 序列格式做了**隐式假设**（如"start 后面一定跟 image_pad"），评估用户发送非预期 Token 组合时是否会触发越界
- 检查推理请求处理路径上是否存在 `IndexError`/`ValueError`/`KeyError` 的**框架层兜底捕获**，确保单个请求的异常不会导致整个服务进程崩溃
- 校验逻辑应在 **tokenize 之后、model.forward 之前** 执行，作为输入预处理的一部分
- 相关漏洞标准：CWE-129 (Improper Validation of Array Index)、CWE-248 (Uncaught Exception)、CWE-20 (Improper Input Validation)

### Python 安全工具

| 工具 | 用途 | 命令 |
|------|------|------|
| **bandit** | 静态安全分析 | `bandit -r src/` |
| **safety / pip-audit** | 依赖漏洞扫描 | `pip-audit` |
| **pylint** | 代码质量 + 部分安全规则 | `pylint src/` |
| **mypy** | 类型检查，防止类型混淆 | `mypy src/` |
| **semgrep** | 自定义安全规则 | `semgrep --config=p/python` |

---

## C++ 安全审查

### 1. 缓冲区溢出

```cpp
// ❌ 不安全：未检查边界
char buf[64];
strcpy(buf, user_input);  // 缓冲区溢出
sprintf(buf, "Hello %s", user_input);  // 同样不安全

// ✅ 安全：使用安全函数或 std::string
std::string buf(user_input);  // 自动管理内存

// 如果必须用 C 字符串：
char buf[64];
strncpy(buf, user_input, sizeof(buf) - 1);
buf[sizeof(buf) - 1] = '\0';
snprintf(buf, sizeof(buf), "Hello %s", user_input);
```

### 2. 内存管理

```cpp
// ❌ 不安全：裸指针 + 手动内存管理
int* ptr = new int[100];
// ... 异常发生 → 内存泄漏
delete[] ptr;  // 可能不会执行

// ❌ 不安全：use-after-free
int* p = new int(42);
delete p;
*p = 10;  // 未定义行为

// ❌ 不安全：double-free
delete p;
delete p;  // 未定义行为

// ✅ 安全：使用智能指针
auto ptr = std::make_unique<int[]>(100);  // 自动释放
auto shared = std::make_shared<MyClass>();  // 共享所有权
```

### 3. 整数溢出

```cpp
// ❌ 不安全：未检查整数溢出
int size = get_user_size();  // 可能为负数或极大值
char* buf = new char[size];  // 整数溢出 → 分配小缓冲区

// ✅ 安全：检查范围
size_t size = get_user_size();
if (size == 0 || size > MAX_ALLOWED_SIZE) {
    throw std::invalid_argument("Invalid size");
}
auto buf = std::make_unique<char[]>(size);
```

### 4. 格式化字符串漏洞

```cpp
// ❌ 不安全：用户控制格式字符串
printf(user_input);  // 格式化字符串攻击，可读写内存
fprintf(stderr, user_input);

// ✅ 安全：始终使用固定格式字符串
printf("%s", user_input);
fprintf(stderr, "%s", user_input);

// ✅ 更好：使用 C++ 流
std::cout << user_input << std::endl;
// 或 C++20 std::format
std::string msg = std::format("User: {}", user_input);
```

### 5. 未初始化变量

```cpp
// ❌ 不安全：未初始化变量
int status;  // 未初始化
if (condition) {
    status = 0;
}
return status;  // 未初始化时为未定义行为

// ✅ 安全：始终初始化
int status = -1;
if (condition) {
    status = 0;
}
return status;
```

### 6. RAII 与资源泄漏

```cpp
// ❌ 不安全：手动资源管理
FILE* fp = fopen("data.txt", "r");
// ... 如果异常发生，fp 不会被关闭
fclose(fp);

std::mutex mtx;
mtx.lock();
// ... 如果异常发生，锁不会释放
mtx.unlock();

// ✅ 安全：RAII
{
    std::ifstream file("data.txt");  // 析构时自动关闭
    // ...
}

{
    std::lock_guard<std::mutex> lock(mtx);  // 析构时自动释放
    // ...
}
```

### 7. 线程安全

```cpp
// ❌ 不安全：数据竞争
int counter = 0;
void increment() { counter++; }  // 多线程下数据竞争

// ✅ 安全：使用原子操作或锁
std::atomic<int> counter{0};
void increment() { counter.fetch_add(1); }

// 或使用互斥锁
std::mutex mtx;
int counter = 0;
void increment() {
    std::lock_guard<std::mutex> lock(mtx);
    counter++;
}
```

### 8. 类型转换安全

```cpp
// ❌ 不安全：C 风格强制转换
Base* base = (Base*)derived;  // 不安全，无类型检查
void* ptr = (void*)obj;

// ✅ 安全：使用 C++ 类型转换
auto* derived = dynamic_cast<Derived*>(base);  // 运行时类型检查
if (derived == nullptr) {
    // 处理转换失败
}
auto value = static_cast<int>(float_value);  // 明确意图
```

### 9. JSON 请求嵌套深度校验

```cpp
// ❌ 不安全：直接解析未限制深度的 JSON（nlohmann::json 默认无深度限制）
#include <nlohmann/json.hpp>

void handleRequest(const std::string& rawBody) {
    auto data = nlohmann::json::parse(rawBody);  // 恶意深层嵌套可导致栈溢出崩溃
    process(data);
}

// ❌ 不安全：递归遍历 JSON 无深度保护
void walk(const nlohmann::json& j) {
    if (j.is_object()) {
        for (auto& [k, v] : j.items()) {
            walk(v);  // 深层嵌套导致栈溢出
        }
    } else if (j.is_array()) {
        for (auto& item : j) {
            walk(item);  // 同上
        }
    }
}
```

```cpp
// ✅ 安全：解析前扫描嵌套深度（O(n) 时间，O(1) 空间）
#include <stdexcept>
#include <string>

constexpr int MAX_JSON_DEPTH = 32;

void checkJsonDepth(const std::string& raw, int maxDepth = MAX_JSON_DEPTH) {
    int depth = 0;
    bool inString = false;
    bool escape = false;
    for (char ch : raw) {
        if (escape) { escape = false; continue; }
        if (ch == '\\') { escape = true; continue; }
        if (ch == '"') { inString = !inString; continue; }
        if (inString) continue;
        if (ch == '{' || ch == '[') {
            if (++depth > maxDepth) {
                throw std::invalid_argument(
                    "JSON nesting depth " + std::to_string(depth) +
                    " exceeds maximum allowed " + std::to_string(maxDepth));
            }
        } else if (ch == '}' || ch == ']') {
            --depth;
        }
    }
}

void handleRequest(const std::string& rawBody) {
    checkJsonDepth(rawBody);  // 先检查深度
    auto data = nlohmann::json::parse(rawBody);  // 再解析
    process(data);
}
```

```cpp
// ✅ 安全：递归遍历时传递深度计数器
void walk(const nlohmann::json& j, int depth = 0) {
    constexpr int MAX_DEPTH = 32;
    if (depth > MAX_DEPTH) {
        throw std::runtime_error("JSON traversal depth exceeds limit");
    }
    if (j.is_object()) {
        for (auto& [k, v] : j.items()) {
            walk(v, depth + 1);
        }
    } else if (j.is_array()) {
        for (auto& item : j) {
            walk(item, depth + 1);
        }
    }
}
```

```cpp
// ✅ 安全：使用 RapidJSON 内置深度限制
#include <rapidjson/document.h>
#include <rapidjson/reader.h>

// RapidJSON 默认最大深度为 kDefaultParseDepth (通常为 256)，可自定义：
template <unsigned MaxDepth = 32>
struct DepthLimitedHandler : public rapidjson::BaseReaderHandler<rapidjson::UTF8<>> {
    unsigned depth = 0;
    bool StartObject() { return ++depth <= MaxDepth; }
    bool EndObject(rapidjson::SizeType) { --depth; return true; }
    bool StartArray() { return ++depth <= MaxDepth; }
    bool EndArray(rapidjson::SizeType) { --depth; return true; }
    // ... 其他 handler 方法
};

void handleRequest(const std::string& rawBody) {
    DepthLimitedHandler<32> handler;
    rapidjson::Reader reader;
    rapidjson::StringStream ss(rawBody.c_str());
    auto result = reader.Parse(ss, handler);
    if (result.IsError()) {
        throw std::invalid_argument("JSON parse failed: depth exceeded or malformed");
    }
}
```

**审查要点：**
- 搜索所有 `nlohmann::json::parse()`、`rapidjson::Document::Parse()`、`Json::Reader::parse()` 调用
- 检查 HTTP/gRPC 请求解析入口是否在解析前校验嵌套深度
- 检查递归遍历 JSON 的函数是否传递了深度参数并设定上限
- 注意栈大小限制：Linux 默认线程栈 8MB，深嵌套 JSON 解析每层约消耗数百字节栈空间，超过 ~10000 层即可能崩溃
- 相关漏洞标准：CWE-674 (Uncontrolled Recursion)、CWE-400 (Uncontrolled Resource Consumption)、CWE-120 (Stack-based Buffer Overflow via recursion)

### 10. 服务化请求资源上限校验（配置参数组合内存炸弹）

```cpp
// ❌ 不安全：各配置参数独立设置，未校验组合后的总资源消耗
// 典型推理服务配置：
constexpr int MAX_REQS = 10000;              // 最大并发请求数
constexpr size_t BODY_LIMIT = 10 * 1024 * 1024;  // 单请求体上限 10MB
constexpr size_t HEADER_LIMIT = 8 * 1024;    // 请求头上限 8KB

// 问题：nlohmann::json 将字符串解析为 JSON 结构体时，内存放大约 33 倍
// 最坏情况峰值内存 = MAX_REQS × BODY_LIMIT × JSON放大系数
// = 10000 × 10MB × 33 ≈ 3.3TB >> Pod 可用内存（通常 64~512GB）
// 攻击者构造大量合法但体积接近上限的请求，即可耗尽内存导致 OOM 服务崩溃

void startServer() {
    server.setMaxRequests(MAX_REQS);          // 单独看合理
    server.setBodyLimit(BODY_LIMIT);          // 单独看合理
    server.setHeaderLimit(HEADER_LIMIT);      // 单独看合理
    // 但三者组合后的峰值内存远超物理内存 → 服务挂掉
}
```

```cpp
// ✅ 安全：基于可用内存反推配置参数的安全上限
#include <sys/sysinfo.h>  // Linux
#include <algorithm>

// 方法 1：启动时校验配置参数组合是否超出内存预算
struct ServerResourceConfig {
    size_t maxReqs;
    size_t bodyLimit;
    size_t headerLimit;
    double jsonAmplificationFactor;  // JSON 解析内存放大系数

    size_t estimatePeakMemory() const {
        // 峰值内存 = 并发请求数 × (请求体 × JSON放大 + 请求头 + 每请求固定开销)
        const size_t perRequestOverhead = 4096;  // 连接管理、上下文等固定开销
        return maxReqs * (
            static_cast<size_t>(bodyLimit * jsonAmplificationFactor)
            + headerLimit
            + perRequestOverhead
        );
    }

    bool validate(size_t availableMemoryBytes, double maxUsageRatio = 0.6) const {
        size_t peakMem = estimatePeakMemory();
        size_t memBudget = static_cast<size_t>(availableMemoryBytes * maxUsageRatio);
        if (peakMem > memBudget) {
            LOG_ERROR("Resource config UNSAFE: estimated peak memory %.2f GB "
                      "exceeds budget %.2f GB (%.0f%% of %.2f GB available). "
                      "maxReqs=%zu, bodyLimit=%zu, jsonAmplification=%.1fx",
                      peakMem / 1e9, memBudget / 1e9,
                      maxUsageRatio * 100,
                      availableMemoryBytes / 1e9,
                      maxReqs, bodyLimit, jsonAmplificationFactor);
            return false;
        }
        LOG_INFO("Resource config OK: peak memory %.2f GB within budget %.2f GB",
                 peakMem / 1e9, memBudget / 1e9);
        return true;
    }
};

void startServer(const ServerResourceConfig& config) {
    // 获取可用内存
    struct sysinfo si;
    sysinfo(&si);
    size_t availableMem = si.totalram * si.mem_unit;

    // 启动前校验：峰值内存不得超过可用内存的 60%
    if (!config.validate(availableMem, 0.6)) {
        throw std::runtime_error("Server config exceeds safe memory limits, "
                                 "reduce maxReqs or bodyLimit");
    }
    // ... 启动服务
}
```

```cpp
// ✅ 安全：方法 2 — 基于内存预算反推 maxReqs 安全值
size_t computeSafeMaxReqs(size_t availableMemory,
                          size_t bodyLimit,
                          double jsonAmplification,
                          double maxUsageRatio = 0.6) {
    size_t memBudget = static_cast<size_t>(availableMemory * maxUsageRatio);
    size_t perReqMem = static_cast<size_t>(bodyLimit * jsonAmplification) + 8192;
    size_t safeMax = memBudget / perReqMem;
    LOG_INFO("Safe maxReqs = %zu (memBudget=%.2fGB, perReq=%.2fMB)",
             safeMax, memBudget / 1e9, perReqMem / 1e6);
    return safeMax;
}

// 使用：让系统自动计算安全上限
size_t maxReqs = std::min(userConfigMaxReqs,
                          computeSafeMaxReqs(availableMem, bodyLimit, 33.0));
```

```cpp
// ✅ 安全：方法 3 — 运行时动态内存水位监控 + 请求准入控制
#include <atomic>
#include <fstream>
#include <string>

class MemoryGuard {
public:
    static constexpr double HIGH_WATERMARK = 0.80;  // 内存使用超 80% 开始拒绝新请求
    static constexpr double LOW_WATERMARK  = 0.60;  // 降到 60% 恢复接收

    // 检查当前系统内存使用率（Linux /proc/meminfo）
    static double getMemoryUsageRatio() {
        std::ifstream meminfo("/proc/meminfo");
        size_t totalMem = 0, availMem = 0;
        std::string line;
        while (std::getline(meminfo, line)) {
            if (line.find("MemTotal:") == 0)
                totalMem = std::stoull(line.substr(10)) * 1024;
            else if (line.find("MemAvailable:") == 0)
                availMem = std::stoull(line.substr(14)) * 1024;
        }
        return (totalMem > 0) ? 1.0 - static_cast<double>(availMem) / totalMem : 1.0;
    }

    // 请求准入决策
    bool admitRequest() {
        double usage = getMemoryUsageRatio();
        if (usage > HIGH_WATERMARK) {
            rejectMode_.store(true, std::memory_order_release);
            LOG_WARN("Memory usage %.1f%% > %.1f%%, rejecting new requests",
                     usage * 100, HIGH_WATERMARK * 100);
            return false;  // 返回 HTTP 503 Service Unavailable
        }
        if (usage < LOW_WATERMARK) {
            rejectMode_.store(false, std::memory_order_release);
        }
        return !rejectMode_.load(std::memory_order_acquire);
    }

private:
    std::atomic<bool> rejectMode_{false};
};

// 在 HTTP handler 入口处调用
Status handleInferenceRequest(const Request& req) {
    if (!memoryGuard.admitRequest()) {
        return Status(503, "Server memory pressure, try again later");
    }
    auto body = nlohmann::json::parse(req.body());  // 准入通过后才解析
    // ... 推理处理
}
```

**问题根因分析（历史教训）：**

> 推理服务配置了 `maxReqs=10000`、`bodyLimit=10MB`、`HEADER_LIMIT=8KB`，每个参数独立看都合理。
> 但 nlohmann::json 将字符串解析为 JSON 结构体时内存放大约 **33 倍**（每个 JSON 节点需要分配
> `json_value` union + type tag + padding，短字符串也需 `std::string` 的 32 字节 SSO 缓冲区）。
> 最坏情况：`10000 × 10MB × 33 ≈ 3.3TB`，远超 Pod 内存（通常 64~512GB），导致 OOM Killed。

**审查要点：**
- **核心公式**：`峰值内存 = maxReqs × bodyLimit × JSON放大系数 + 基础内存开销`
- 搜索所有 HTTP/gRPC 服务的配置参数：`maxReqs`/`maxConnections`、`bodyLimit`/`maxBodySize`、`headerLimit` 等
- 计算各参数组合后的**最坏情况峰值内存**，与部署目标机器/Pod 的内存做对比
- 检查是否存在**启动时校验**：配置加载后是否验证组合参数不超出内存预算
- 检查是否存在**运行时保护**：内存水位监控、请求准入控制、背压机制
- JSON 解析库的内存放大系数参考：nlohmann::json ≈ 20~40x，RapidJSON (DOM) ≈ 4~8x，simdjson (on-demand) ≈ 0x（流式解析无放大）
- 不仅是 JSON，也适用于 XML/Protobuf/MessagePack 等所有需要将网络字节流反序列化为内存结构体的场景
- 相关漏洞标准：CWE-400 (Uncontrolled Resource Consumption)、CWE-770 (Allocation of Resources Without Limits)、CWE-789 (Memory Allocation with Excessive Size Value)

### 11. 特殊 Token 注入与多模态输入校验

```cpp
// ❌ 不安全：假设特殊 Token 成对出现，直接用索引取配对位置
void processMultimodalInput(const std::vector<int>& inputIds,
                            const ModelConfig& config) {
    auto boiPositions = findTokenPositions(inputIds, config.boiTokenId);
    auto eoiPositions = findTokenPositions(inputIds, config.eoiTokenId);

    for (size_t i = 0; i < boiPositions.size(); ++i) {
        // 致命：若 eoi 缺失或数量不匹配，eoiPositions[i] 越界 → 崩溃
        size_t eoiPos = eoiPositions[i];
        processImage(inputIds, boiPositions[i], eoiPos);
    }
}

// ❌ 不安全：假设 vision_start 后的序列一定遵循内部协议格式
void processVisionSequence(const std::vector<int>& inputIds,
                           size_t startPos,
                           const ModelConfig& config) {
    // 假设 startPos+1 是 image_count, startPos+2 是 width, ...
    int imageCount = inputIds[startPos + 1];   // ← 可能越界
    int width      = inputIds[startPos + 2];   // ← 可能越界
    int height     = inputIds[startPos + 3];   // ← 可能越界
    // 用户发送 <|vision_start|><|video_pad|><|vision_end|> 代替预期的 image_pad 序列
    // 偏移计算全部错误 → 越界访问 → 段错误 → 服务崩溃
}
```

```cpp
// ✅ 安全：严格校验特殊 Token 配对完整性

#include <vector>
#include <stdexcept>
#include <utility>

struct TokenPair {
    size_t beginPos;
    size_t endPos;
};

std::vector<TokenPair> validateSpecialTokenPairs(
    const std::vector<int>& inputIds,
    int beginTokenId,
    int endTokenId,
    const std::string& tokenName)
{
    std::vector<size_t> beginPositions, endPositions;
    for (size_t i = 0; i < inputIds.size(); ++i) {
        if (inputIds[i] == beginTokenId) beginPositions.push_back(i);
        else if (inputIds[i] == endTokenId) endPositions.push_back(i);
    }

    // 校验 1：数量必须相等
    if (beginPositions.size() != endPositions.size()) {
        throw std::invalid_argument(
            tokenName + " token count mismatch: " +
            std::to_string(beginPositions.size()) + " begin vs " +
            std::to_string(endPositions.size()) + " end");
    }

    std::vector<TokenPair> pairs;
    for (size_t i = 0; i < beginPositions.size(); ++i) {
        // 校验 2：end 必须在 begin 之后
        if (endPositions[i] <= beginPositions[i]) {
            throw std::invalid_argument(
                tokenName + " pair " + std::to_string(i) +
                ": end not after begin");
        }
        pairs.push_back({beginPositions[i], endPositions[i]});
    }

    // 校验 3：相邻对不交叉
    for (size_t i = 0; i + 1 < pairs.size(); ++i) {
        if (pairs[i].endPos > pairs[i + 1].beginPos) {
            throw std::invalid_argument(
                tokenName + " pairs " + std::to_string(i) +
                " and " + std::to_string(i + 1) + " overlap");
        }
    }
    return pairs;
}
```

```cpp
// ✅ 安全：校验序列内容类型，不信任隐式格式假设

void parseVisionSequenceSafe(const std::vector<int>& inputIds,
                             size_t startPos,
                             size_t endPos,
                             const ModelConfig& config) {
    if (endPos <= startPos + 1) {
        throw std::invalid_argument("Empty vision sequence");
    }

    // 校验序列中每个 Token 是否在合法集合内（白名单）
    for (size_t i = startPos + 1; i < endPos; ++i) {
        int tokenId = inputIds[i];
        if (tokenId != config.imagePadId &&
            tokenId != config.videoPadId &&
            tokenId != config.audioPadId) {
            throw std::invalid_argument(
                "Illegal token " + std::to_string(tokenId) +
                " in vision sequence at position " + std::to_string(i));
        }
    }
    // 按实际内容分派，不硬假设格式
    // ...
}
```

```cpp
// ✅ 安全：框架层兜底异常捕获

Status handleInferenceRequest(const Request& req) {
    try {
        auto inputIds = tokenize(req.prompt());
        // 多模态 Token 校验 — 在 model forward 之前
        validateMultimodalTokens(inputIds, modelConfig);
        auto result = model.forward(inputIds);
        return SuccessResponse(result);
    } catch (const std::invalid_argument& e) {
        LOG_WARN("Malformed multimodal input rejected: %s", e.what());
        return ErrorResponse(400, std::string("Bad request: ") + e.what());
    } catch (const std::out_of_range& e) {
        LOG_ERROR("Input validation gap (out_of_range): %s", e.what());
        return ErrorResponse(400, "Malformed input");
    } catch (const std::exception& e) {
        // 最终兜底：任何未预期异常不导致进程退出
        LOG_ERROR("Unexpected error: %s", e.what());
        return ErrorResponse(500, "Internal server error");
    }
}
```

**审查要点：**
- 搜索所有通过 Token ID 查找位置的代码（`std::find`、`findTokenPositions`、循环比较等），检查结果为空或数量不匹配时是否安全处理
- 检查多模态 Token 处理是否对序列格式做了**隐式假设**（如"start 后一定跟 N 个 pad Token"），这些假设能否被用户构造的非预期 Token 组合打破
- 检查 model forward / pre-processing 路径上是否有 `std::out_of_range`、`std::invalid_argument` 等异常的**框架层 catch 兜底**
- 相关漏洞标准：CWE-129 (Improper Validation of Array Index)、CWE-248 (Uncaught Exception)、CWE-20 (Improper Input Validation)

### C++ 安全工具

| 工具 | 用途 | 命令/用法 |
|------|------|----------|
| **AddressSanitizer** | 内存错误检测 | `-fsanitize=address` |
| **ThreadSanitizer** | 数据竞争检测 | `-fsanitize=thread` |
| **UBSanitizer** | 未定义行为检测 | `-fsanitize=undefined` |
| **Valgrind** | 内存泄漏检测 | `valgrind --leak-check=full ./app` |
| **cppcheck** | 静态分析 | `cppcheck --enable=all src/` |
| **clang-tidy** | Linter + 安全规则 | `clang-tidy -checks='*' src/*.cpp` |
| **Coverity** | 企业级静态分析 | CI 集成 |

---

## Shell 安全审查

### 1. 脚本头部安全设置

```bash
# ✅ 每个脚本必须以此开头
#!/bin/bash
set -euo pipefail
# -e: 命令失败时立即退出
# -u: 引用未定义变量时报错
# -o pipefail: 管道中任一命令失败则整体失败
```

### 2. 变量引用（最常见的 Shell 安全问题）

```bash
# ❌ 不安全：未引用变量
rm -rf $dir/$file           # 如果 $dir 为空 → rm -rf /
cp $file /backup/           # 文件名含空格时出错
if [ $var = "yes" ]; then   # $var 为空时语法错误

# ✅ 安全：始终用双引号包裹变量
rm -rf "${dir:?}/${file:?}"   # :? 确保变量非空
cp "$file" /backup/
if [ "$var" = "yes" ]; then
```

### 3. 命令注入

```bash
# ❌ 不安全：eval 执行用户输入
eval "$user_input"
eval "echo $user_data"

# ❌ 不安全：反引号中的未过滤输入
result=$(echo $user_input | grep pattern)

# ✅ 安全：避免 eval，使用参数化
result=$(grep -F -- "$user_input" "$file")
# -- 防止参数被解释为选项
# -F 固定字符串匹配（避免正则注入）
```

### 4. 临时文件安全

```bash
# ❌ 不安全：可预测的临时文件
echo "$data" > /tmp/myapp.tmp  # 竞态条件 + 符号链接攻击

# ✅ 安全：使用 mktemp
tmpfile=$(mktemp /tmp/myapp.XXXXXX)
trap 'rm -f "$tmpfile"' EXIT  # 确保退出时清理
echo "$data" > "$tmpfile"

# ✅ 安全：临时目录
tmpdir=$(mktemp -d /tmp/myapp.XXXXXX)
trap 'rm -rf "$tmpdir"' EXIT
```

### 5. 权限与文件操作

```bash
# ❌ 不安全：过于宽松的权限
chmod 777 "$file"        # 任何人都可读写执行
chmod 666 "$config"      # 任何人都可读写

# ✅ 安全：最小权限原则
chmod 750 "$script"      # 所有者可执行，组可读
chmod 640 "$config"      # 所有者可读写，组可读
chmod 600 "$secret_key"  # 仅所有者可读写

# ❌ 不安全：不检查文件是否为符号链接
if [ -f "$file" ]; then
    cat "$file"  # 可能是符号链接指向敏感文件
fi

# ✅ 安全：检查符号链接
if [ -f "$file" ] && [ ! -L "$file" ]; then
    cat "$file"
fi
```

### 6. PATH 安全

```bash
# ❌ 不安全：依赖相对路径
curl http://example.com  # 如果 PATH 被劫持，可能执行恶意 curl

# ✅ 安全：使用绝对路径（关键命令）
/usr/bin/curl http://example.com

# ✅ 安全：脚本开头设置安全 PATH
export PATH="/usr/local/bin:/usr/bin:/bin"
```

### 7. 信号处理与清理

```bash
# ✅ 安全：使用 trap 确保清理
cleanup() {
    rm -f "$tmpfile"
    # 其他清理操作
}
trap cleanup EXIT INT TERM
```

### 8. 输入验证

```bash
# ❌ 不安全：未验证输入直接使用
read -r filename
cat "$filename"  # 路径遍历

# ✅ 安全：验证输入
read -r filename
# 只允许字母数字和下划线
if [[ ! "$filename" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    echo "Invalid filename" >&2
    exit 1
fi
# 确保在预期目录内
filepath="/data/uploads/$filename"
realpath=$(realpath "$filepath")
if [[ "$realpath" != /data/uploads/* ]]; then
    echo "Path traversal detected" >&2
    exit 1
fi
```

### Shell 安全工具

| 工具 | 用途 | 命令 |
|------|------|------|
| **ShellCheck** | Shell 脚本静态分析 | `shellcheck script.sh` |
| **shfmt** | Shell 格式化 | `shfmt -d script.sh` |

---

## Markdown 安全审查

### 1. XSS 注入（内嵌 HTML）

```markdown
<!-- ❌ 不安全：内嵌恶意 HTML/JavaScript -->
<script>alert('XSS')</script>
<img src=x onerror="alert('XSS')">
<a href="javascript:alert('XSS')">Click me</a>
<div onmouseover="steal(document.cookie)">Hover me</div>

<!-- ✅ 安全：审查时应标记所有内嵌 HTML -->
<!-- 使用安全的 Markdown 渲染器，禁用原始 HTML -->
<!-- 配置: sanitize: true 或使用 DOMPurify -->
```

### 2. 链接安全

```markdown
<!-- ❌ 不安全：javascript: 协议 -->
[Click here](javascript:alert('XSS'))

<!-- ❌ 可疑：外部链接未标注 -->
[下载工具](http://malicious-site.com/tool.exe)

<!-- ✅ 安全：仅允许 https 链接 -->
[文档](https://docs.example.com)

<!-- ✅ 审查要点：检查所有外部链接的合法性 -->
```

### 3. 敏感信息泄露

```markdown
<!-- ❌ 不安全：文档中包含真实密钥 -->
API Key: `sk-1234567890abcdef`
数据库连接: `postgresql://admin:password123@prod-db:5432/mydb`
内部服务地址: `http://10.0.1.50:8080/admin`

<!-- ✅ 安全：使用占位符 -->
API Key: `<YOUR_API_KEY>`
数据库连接: `postgresql://<user>:<password>@<host>:5432/<db>`
内部服务地址: `http://<internal-host>:<port>/admin`
```

### 4. 图片安全

```markdown
<!-- ❌ 可疑：外部图片可能追踪用户 -->
![avatar](http://tracker.evil.com/pixel.gif?user=123)

<!-- ❌ 不安全：超大图片可能导致 DoS -->
![](http://example.com/huge-100mb-image.png)

<!-- ✅ 安全：使用本地或受信任的图片源 -->
![架构图](./docs/images/architecture.png)
![Logo](https://cdn.trusted-domain.com/logo.png)
```

### Markdown 审查要点

- 搜索所有 `<script>`, `<iframe>`, `<object>`, `<embed>` 标签
- 搜索所有 `javascript:`, `data:`, `vbscript:` 协议链接
- 搜索所有硬编码的密钥、密码、Token 模式（如 `sk-`, `ghp_`, `AKIA`）
- 检查所有外部 URL 的合法性

---

## 通用安全约束 (Constraints)

### 必须遵守 (MUST)

1. **输入验证**: 验证所有外部输入，永远不信任用户数据
2. **参数化查询**: 使用参数化查询防止注入攻击
3. **最小权限**: 进程、文件、用户使用最小必要权限
4. **安全默认值**: 变量初始化、错误处理使用安全的默认值
5. **依赖审计**: 定期扫描依赖中的已知漏洞
6. **敏感信息保护**: 密钥、密码、Token 通过环境变量管理
7. **日志脱敏**: 日志中不记录密码、密钥等敏感信息
8. **错误处理**: 错误消息不泄露内部实现细节
9. **JSON 嵌套深度校验**: 对所有外部 JSON 请求在解析前/解析时校验嵌套深度，防止栈溢出和资源耗尽攻击 (CWE-674, CWE-400)
10. **服务化请求资源上限校验**: 服务配置参数（最大并发数、请求体上限、请求头上限等）组合后的峰值内存必须小于部署环境可用内存；需考虑 JSON/XML 等反序列化库的内存放大系数 (CWE-400, CWE-770)
11. **特殊 Token 输入校验**: 多模态/多轮对话等场景中的特殊 Token（如 begin/end_of_image、vision_start/end 等）必须校验配对完整性和序列格式合法性；禁止对 Token 序列做隐式格式假设；框架层必须兜底捕获 IndexError/out_of_range 防止进程崩溃 (CWE-129, CWE-248, CWE-20)

### 禁止事项 (MUST NOT)

1. **禁止 eval 类函数**: Python `eval()`/`exec()`、Shell `eval`、C++ 无等价物但禁止动态代码生成
2. **禁止硬编码密钥**: 不在代码中硬编码密码、API Key、Token
3. **禁止提交敏感文件**: `.env`、私钥、证书不得提交到版本控制
4. **禁止忽略错误**: 不得静默吞掉异常或忽略返回值
5. **禁止过宽权限**: 不使用 `chmod 777`、`0.0.0.0` 无限制监听
6. **禁止使用已弃用的不安全函数**: `gets()`, `sprintf()`, `strcpy()` 等

---

## 安全审查检查清单 (Checklist)

### Python
```
- [ ] 无 eval()/exec() 使用不受信任的输入
- [ ] 无 pickle.loads() 加载不受信任的数据
- [ ] 使用 yaml.safe_load() 替代 yaml.load()
- [ ] subprocess 调用不使用 shell=True
- [ ] SQL 查询使用参数化方式
- [ ] 文件路径操作有路径遍历防护
- [ ] 无硬编码的密钥/密码
- [ ] 日志不记录敏感信息
- [ ] 使用 assert 不做安全检查
- [ ] 依赖已通过 pip-audit/bandit 扫描
- [ ] 正则表达式无 ReDoS 风险
- [ ] 临时文件使用 tempfile 模块
- [ ] JSON 请求解析入口有嵌套深度限制（建议 ≤ 32 层）
- [ ] 递归遍历 JSON 数据结构有深度保护
- [ ] 多模态特殊 Token（begin/end_of_image、vision_start/end 等）校验了配对完整性，不假设成对出现
- [ ] 推理请求处理路径有框架层 IndexError/ValueError/KeyError 兜底捕获，防止单请求异常导致进程崩溃
```

### C++
```
- [ ] 无缓冲区溢出风险 (strcpy → strncpy/std::string)
- [ ] 使用智能指针管理内存
- [ ] 无 use-after-free / double-free
- [ ] 整数运算有溢出检查
- [ ] printf 系列函数使用固定格式字符串
- [ ] 所有变量在使用前初始化
- [ ] 资源管理遵循 RAII 原则
- [ ] 多线程代码无数据竞争
- [ ] 使用 C++ 风格类型转换 (static_cast/dynamic_cast)
- [ ] 编译启用安全选项 (-Wall -Werror -fsanitize=address)
- [ ] JSON 请求解析入口有嵌套深度限制（建议 ≤ 32 层）
- [ ] 递归遍历 JSON 数据结构有深度参数并设上限
- [ ] 服务配置参数组合后峰值内存不超过部署环境可用内存（考虑 JSON 放大系数）
- [ ] 存在运行时内存水位监控或请求准入控制机制
- [ ] 多模态特殊 Token（boi/eoi、vision_start/end 等）校验了配对完整性和序列格式，不做隐式格式假设
- [ ] model forward / pre-processing 路径有框架层 std::out_of_range/std::invalid_argument 兜底 catch，防止进程崩溃
```

### Shell
```
- [ ] 脚本使用 set -euo pipefail
- [ ] 所有变量使用双引号包裹 ("$var")
- [ ] 无 eval 使用用户输入
- [ ] 临时文件使用 mktemp
- [ ] 文件权限不超过 755（脚本）/ 644（配置）
- [ ] 关键命令使用绝对路径
- [ ] 有 trap 清理机制
- [ ] 输入经过验证和过滤
- [ ] 通过 ShellCheck 无警告
- [ ] 不使用 . 或空目录在 PATH 中
```

### Markdown
```
- [ ] 无内嵌 <script>/<iframe> 标签
- [ ] 无 javascript:/data: 协议链接
- [ ] 无硬编码密钥/密码/Token
- [ ] 无内部 IP 地址或内部 URL 泄露
- [ ] 外部图片来源可信
- [ ] 无追踪像素
```

---

## 推荐工具汇总

| 语言 | 工具 | 类型 | 说明 |
|------|------|------|------|
| Python | **bandit** | 静态分析 | Python 安全漏洞检测 |
| Python | **pip-audit** | 依赖扫描 | Python 依赖漏洞检查 |
| Python | **semgrep** | 规则引擎 | 自定义安全规则匹配 |
| Python | **mypy** | 类型检查 | 类型安全，防止类型混淆 |
| C++ | **AddressSanitizer** | 运行时检测 | 内存错误检测 |
| C++ | **ThreadSanitizer** | 运行时检测 | 数据竞争检测 |
| C++ | **cppcheck** | 静态分析 | C/C++ 静态分析 |
| C++ | **clang-tidy** | Linter | 代码质量 + 安全规则 |
| C++ | **Valgrind** | 运行时检测 | 内存泄漏检测 |
| Shell | **ShellCheck** | 静态分析 | Shell 脚本安全分析 |
| 通用 | **git-secrets** | 预提交钩子 | 防止提交密钥 |
| 通用 | **trufflehog** | 密钥扫描 | 扫描代码中的密钥 |
| 通用 | **gitleaks** | 密钥扫描 | Git 仓库密钥泄露检测 |
| Markdown | **markdownlint** | Linter | Markdown 格式检查 |

---

## 历史安全问题经验库 (Lessons Learned)

> 本节记录推理服务引擎中实际发生过的安全问题及修复经验，用于指导审查时排查同类问题。

### 经验 1：服务化配置参数组合导致 OOM — 内存放大系数被忽视

**问题编号：** SEC-EXP-001  
**严重级别：** CRITICAL  
**影响范围：** 推理服务引擎 HTTP 服务端  
**问题类型：** CWE-400 / CWE-770（资源耗尽）

**问题描述：**

推理服务的 HTTP 服务端配置了以下参数：

| 配置项 | 值 | 含义 |
|--------|-----|------|
| `maxReqs` | 10,000 | 最大并发请求数 |
| `bodyLimit` | 10 MB | 单个请求体大小上限 |
| `HEADER_LIMIT` | 8 KB | 单个请求头大小上限 |

每个参数单独看都在合理范围内。但被忽视的关键因素是：三方组件 **nlohmann::json** 将字符串请求解析为 JSON 结构体时，内存占用放大约 **33 倍**。

**放大原因分析：**
- nlohmann::json 的每个 JSON 节点是一个 `basic_json` 对象，包含：`json_value` union（8 字节）+ type tag（1 字节）+ padding（对齐到 8/16 字节）
- 每个 JSON 字符串值内部使用 `std::string`，即使短字符串也需 32 字节 SSO 缓冲区
- JSON 对象使用 `std::map<std::string, basic_json>`，每个键值对需要红黑树节点开销（3 个指针 + color bit ≈ 32 字节）
- JSON 数组使用 `std::vector<basic_json>`，有 capacity 预留和指针开销
- 综合来看：一个紧凑的 JSON 字符串（如 `{"a":"b"}`，7 字节）在内存中占用约 200+ 字节

**最坏情况计算：**
```
峰值内存 = maxReqs × bodyLimit × JSON放大系数
         = 10,000 × 10 MB × 33
         = 3,300,000 MB
         ≈ 3.3 TB
```
而部署 Pod 的可用内存通常为 64~512 GB，**差距达 6~50 倍**。

**攻击场景：**
攻击者无需发送恶意请求，只需构造大量**合法但体积接近 bodyLimit 上限**的推理请求（如包含超长 prompt 或大量 few-shot 示例的请求），即可触发 OOM Killed。这是一种**合法流量的 DoS 攻击**，传统 WAF 无法识别。

**根本原因：**
1. **配置参数各自为政**：maxReqs、bodyLimit、headerLimit 由不同模块/不同开发者设置，没有统一的资源预算视角
2. **忽视反序列化放大系数**：将 `bodyLimit` 等同于内存占用，未考虑 JSON 解析后的实际内存膨胀
3. **缺少启动时校验**：服务启动时未验证配置参数组合后的峰值内存是否在安全范围内
4. **缺少运行时保护**：无内存水位监控，无请求准入控制，直到 OOM Killed 才发现问题

**修复方案：**

1. **启动时校验**：服务启动时计算 `maxReqs × bodyLimit × JSON放大系数`，若超过可用内存的 60% 则拒绝启动并打印告警
2. **参数联动约束**：根据部署环境内存反推 maxReqs 的安全上限：`safeMaxReqs = availableMem × 0.6 / (bodyLimit × jsonAmplification)`
3. **运行时准入控制**：监控 `/proc/meminfo` 中的 `MemAvailable`，内存使用率超过 80% 时返回 HTTP 503 拒绝新请求
4. **考虑低放大系数的替代方案**：RapidJSON DOM 模式放大约 4~8x，simdjson on-demand 模式几乎无放大（流式解析）

**排查同类问题的审查清单：**

```
- [ ] 检查服务所有资源上限配置参数（并发数、请求体/头大小、超时时间、队列深度等）
- [ ] 计算各参数组合后的最坏情况峰值资源消耗（内存、CPU、文件描述符、网络带宽等）
- [ ] 确认反序列化库（JSON/XML/Protobuf/YAML 等）的内存放大系数已纳入计算
- [ ] 确认峰值资源消耗 < 部署目标的物理资源上限 × 安全比例（建议 60%）
- [ ] 检查是否存在启动时配置参数合理性校验
- [ ] 检查是否存在运行时资源使用率监控和过载保护（背压/熔断/限流）
- [ ] 检查 OOM / 资源耗尽场景的降级策略（优雅拒绝 vs 进程崩溃）
```

**各 JSON 库内存放大系数参考表：**

| JSON 库 | 语言 | 解析模式 | 放大系数 | 说明 |
|---------|------|---------|---------|------|
| **nlohmann::json** | C++ | DOM (全量) | **20~40x** | std::map + std::string + type tag 开销大 |
| **RapidJSON** | C++ | DOM (全量) | **4~8x** | 自有分配器，紧凑内存布局 |
| **RapidJSON** | C++ | SAX (流式) | **~0x** | 事件驱动，不构建完整树 |
| **simdjson** | C++ | On-demand | **~0x** | 流式按需解析，几乎无额外内存 |
| **cJSON** | C | DOM (全量) | **8~15x** | 链表结构，每节点固定开销 |
| **json (stdlib)** | Python | DOM (全量) | **4~10x** | Python 对象头开销 |
| **orjson** | Python | DOM (全量) | **2~5x** | Rust 实现，内存更紧凑 |
| **Jackson** | Java | DOM (全量) | **5~15x** | Java 对象头 + 引用开销 |
| **Gson** | Java | DOM (全量) | **8~20x** | 反射 + 装箱开销更大 |

### 经验 2：多模态 Token 未配对导致数组越界 DoS — `<|begin_of_image|>` 无 `<|end_of_image|>`

**问题编号：** SEC-EXP-002  
**严重级别：** CRITICAL  
**影响范围：** 推理服务引擎多模态推理路径  
**问题类型：** CWE-129 (Improper Validation of Array Index) / CWE-248 (Uncaught Exception) / CWE-20 (Improper Input Validation)

**问题描述：**

多模态模型处理图片输入时，代码通过特殊 Token `<|begin_of_image|>` 和 `<|end_of_image|>` 标识图片数据的起止位置。处理逻辑使用 NumPy 查找这两个 Token 的位置：

```python
# 问题代码
boi_positions = np.where(np.equal(input_ids, self.config.boi_token_id))[0]
eoi_positions = np.where(np.equal(input_ids, self.config.eoi_token_id))[0]
# ... 后续直接用硬索引取 eoi 位置
eoi_pos = eoi_positions[0]  # ← 若 eoi 不存在，IndexError
```

**攻击方式：**

攻击者发送多模态推理请求时，只发送 `<|begin_of_image|>` 而**不发送** `<|end_of_image|>`：

```json
{
  "prompt": "<|begin_of_image|>fake_image_data_without_end_token",
  "model": "vision-model-v1"
}
```

**崩溃链路：**

1. Tokenizer 将 prompt 转为 `input_ids`，其中包含 `boi_token_id` 但**不包含** `eoi_token_id`
2. `np.where(np.equal(input_ids, self.config.eoi_token_id))[0]` 返回**空数组** `[]`
3. 后续代码执行 `eoi_positions[0]` 或 `eoi_positions[i]` 触发 `IndexError: index 0 is out of bounds for axis 0 with size 0`
4. 该异常未被任何 try/except 捕获，**沿调用栈一路传播到进程顶层**
5. 推理进程崩溃退出 → 服务不可用 → **DoS 达成**

**根本原因：**

1. **隐式假设**：代码假设 `<|begin_of_image|>` 和 `<|end_of_image|>` 一定成对出现、数量相等，但用户输入不受此约束
2. **无输入校验**：未在使用前验证 `eoi_positions` 数组非空且长度与 `boi_positions` 匹配
3. **无异常兜底**：推理请求处理链路上无 `try/except IndexError` 的框架层保护

**修复方案：**

1. **Token 配对校验**：在索引访问前，验证 begin/end Token 数量相等、位置有效（参见本 Skill Python §10 `validate_special_token_pairs()`）
2. **框架层兜底**：在推理请求 handler 中添加 `except (IndexError, ValueError, KeyError)` 捕获，返回 HTTP 400 而非进程崩溃
3. **防御性编程**：所有 `np.where()` / `np.equal()` 结果在索引访问前检查 `.size > 0`

**排查同类问题的关键模式：**

```
# 搜索以下代码模式：
np.where(...)[0][N]       # 硬索引取位置，N 可能越界
np.equal(input_ids, token_id)  # 特殊 Token 查找
positions[i]              # 循环中按索引取配对 Token 位置
# 任何假设"某 Token 一定存在于 input_ids 中"的代码
```

---

### 经验 3：多模态 Token 序列格式假设被打破导致 DoS — `<|vision_start|><|video_pad|><|vision_end|>`

**问题编号：** SEC-EXP-003  
**严重级别：** CRITICAL  
**影响范围：** 推理服务引擎多模态推理路径  
**问题类型：** CWE-129 (Improper Validation of Array Index) / CWE-248 (Uncaught Exception) / CWE-20 (Improper Input Validation)

**问题描述：**

多模态模型处理视觉输入时，代码假设所有以 `<|vision_start|>` 开头的 Token 序列都遵循**内部私有协议格式**（例如：`<|vision_start|>` 后紧跟 image_count、width、height 等元数据字段，然后是 image_pad Token 序列，最后以 `<|vision_end|>` 结束）。

**攻击方式：**

攻击者构造非预期的合法 Token 组合：

```json
{
  "prompt": "<|vision_start|><|video_pad|><|vision_end|>Please describe this image.",
  "model": "vision-model-v1"
}
```

发送 `<|vision_start|>` + `<|video_pad|>` + `<|vision_end|>` 序列，而非代码预期的 `<|vision_start|>` + image 元数据 + `<|image_pad|>` 序列。

**崩溃链路：**

1. 代码检测到 `<|vision_start|>` Token，进入视觉序列处理分支
2. 按照内部协议格式，代码直接按**固定偏移**读取后续 Token：
   - `input_ids[start_pos + 1]` → 预期为 image_count，实际为 `video_pad_id`（语义错误）
   - `input_ids[start_pos + 2]` → 预期为 width，实际可能为 `vision_end_id` 或已越界
   - `input_ids[start_pos + 3]` → 预期为 height，**数组越界**
3. 偏移计算全部基于错误的值，导致后续切片操作 `input_ids[start+4 : start+4+total_patches]` 的 `total_patches` 值为随机大数或负数
4. 触发 `IndexError` 或内存访问异常
5. **框架侧没有对应的异常捕获机制**，异常直接导致推理 worker 进程崩溃 → 服务不可用

**根本原因：**

1. **隐式协议假设**：代码将 `<|vision_start|>` 视为"私有协议"的起始标记，假设后续 Token 必定遵循特定格式（image 元数据 + image_pad），但用户可以注入任意 Token 组合
2. **混合 Token 类型未处理**：`<|video_pad|>` 出现在预期 `<|image_pad|>` 的位置，代码无分派逻辑区分不同子类型
3. **硬编码偏移**：使用 `start_pos + 1/2/3` 等固定偏移取值，而非基于实际序列内容动态解析
4. **框架层无兜底**：推理 handler 没有 `try/except` 保护，单个请求的异常可以杀死整个进程

**修复方案：**

1. **序列内容白名单校验**：在解析前验证 `vision_start..vision_end` 之间的所有 Token 是否属于合法集合（参见本 Skill Python §10 `parse_vision_sequence()`、C++ §11 `parseVisionSequenceSafe()`）
2. **按内容分派，不硬假设格式**：检查实际 Token 类型（image_pad / video_pad / audio_pad），根据类型走不同解析分支，而非按固定偏移读取
3. **框架层兜底捕获**：在推理 handler 中添加 `IndexError`/`out_of_range` 的 catch，返回 HTTP 400
4. **边界检查**：所有基于偏移的数组访问前，先验证 `start_pos + offset < input_ids.size()`

**经验 2 和经验 3 的共性总结：**

| 维度 | 共性模式 | 防御策略 |
|------|---------|---------|
| **输入信任** | 假设用户输入的 Token 序列遵循内部预期格式 | **零信任原则**：对所有用户可控的 Token 序列做显式校验 |
| **配对假设** | 假设 begin/end Token 一定成对且数量匹配 | 先验证配对完整性，再按对处理 |
| **格式假设** | 假设特定 Token 后的内容遵循私有协议 | 白名单校验序列内容，按实际类型分派 |
| **异常处理** | 框架层无兜底，单请求异常杀死进程 | 推理 handler 必须有 IndexError/out_of_range catch |
| **攻击面** | 特殊 Token 对外暴露，可被用户直接注入 | 入口处（tokenize 之后、forward 之前）做统一校验 |

**排查同类问题的关键模式：**

```
# 搜索以下代码模式：
input_ids[start_pos + N]   # 基于固定偏移的 Token 访问，N 可能越界
positions[i]               # 假设配对 Token 数量一致的索引访问
if token_id == vision_start_id:  # 进入特定处理分支后是否做了格式校验
# 检查所有 except/catch 块：推理路径上是否有 IndexError/out_of_range 的兜底
```

---

## 参考标准

- [CWE Top 25](https://cwe.mitre.org/top25/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CERT C++ Secure Coding](https://wiki.sei.cmu.edu/confluence/display/cplusplus)
- [CERT C Secure Coding](https://wiki.sei.cmu.edu/confluence/display/c)
- [Bandit Documentation](https://bandit.readthedocs.io/)
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)

## 审查结果输出 (Output)

### 审查流程要求

当使用此 Skill 对代码仓库执行安全审查（即参数包含 `review` 关键字）时，**必须**在完成所有审查后自动将结果保存为 CSV 文件。这是审查流程的最终必要步骤。

### CSV 输出规范

**文件名：** `security_code_review_report.csv`
**保存位置：** 被审查的代码仓库根目录下（即 `review <path>` 中的 `<path>` 下）
**编码：** UTF-8

**CSV 必须包含以下 9 列（表头固定）：**

```csv
编号,严重级别,漏洞类别,语言,文件路径,行号,问题描述,风险说明,建议修复方案
```

| 列名 | 说明 | 示例值 |
|------|------|--------|
| **编号** | 唯一编号，格式为 `严重级别首字母-序号` | `C-01`, `H-05`, `M-12`, `L-03` |
| **严重级别** | 四级：`CRITICAL` / `HIGH` / `MEDIUM` / `LOW` | `CRITICAL` |
| **漏洞类别** | 安全漏洞分类名称 | `命令注入`, `不安全反序列化`, `线程安全`, `路径遍历` |
| **语言** | 代码语言/文件类型 | `Python`, `C++`, `Shell`, `Markdown`, `Docker`, `Config` |
| **文件路径** | 相对于仓库根目录的文件路径 | `src/utils/file_utils.py` |
| **行号** | 问题代码所在行号，多行用逗号分隔 | `79`, `40-44, 220-232` |
| **问题描述** | 简明扼要描述发现的问题 | `pickle.loads() 反序列化来自共享内存的数据` |
| **风险说明** | 说明该问题可能导致的安全风险 | `攻击者可注入恶意 pickle payload 实现 RCE` |
| **建议修复方案** | 具体的修复建议和代码示例 | `用 json.loads() 替代 pickle.loads()` |

### CSV 格式要求

1. **逗号分隔**，含逗号的字段值用双引号包裹
2. 字段值内部的双引号用两个双引号转义（`""`）
3. 第一行为表头行，之后每行一条发现
4. 按严重级别排序：CRITICAL → HIGH → MEDIUM → LOW
5. 同级别内按编号顺序排列
6. 文件路径使用相对路径（相对于仓库根目录）

### 输出流程

审查完成后执行以下步骤：

1. **汇总所有发现**：收集所有审查代理/扫描的结果
2. **去重合并**：合并重复发现，确保每条记录唯一
3. **生成 CSV**：按上述规范生成 CSV 文件并写入目标路径
4. **验证 CSV**：用 Python csv 模块验证文件格式正确、行数与发现数一致
5. **输出摘要**：向用户报告文件位置和各严重级别的统计数量

### 示例输出

```csv
编号,严重级别,漏洞类别,语言,文件路径,行号,问题描述,风险说明,建议修复方案
C-01,CRITICAL,不安全反序列化,Python,src/utils/share_memory.py,79,"pickle.loads() 反序列化来自共享内存的数据","攻击者可注入恶意 pickle payload 实现 RCE","用 json.loads() 替代 pickle.loads()"
H-01,HIGH,命令注入,Shell,scripts/run.sh,52,"eval 执行含用户输入的命令字符串","模型路径含 shell 元字符时可注入任意命令","改用 bash 数组构建命令, 消除 eval"
M-01,MEDIUM,线程安全,C++,src/thread_pool.h,45,"m_shutdown 为非原子 bool 跨线程读写","数据竞争导致工作线程可能无法退出","改为 std::atomic<bool>"
L-01,LOW,临时文件安全,Python,tests/test_utils.py,30,"硬编码 /tmp 路径","共享 CI 环境中符号链接攻击风险","使用 tempfile.mkdtemp()"
```

### 注意事项

- 即使审查未发现任何问题，也应生成 CSV 文件（仅含表头行），并向用户说明"未发现安全问题"
- CSV 文件用于人工审核，**描述必须清晰具体，避免模糊表述**
- 如果审查仅针对特定文件而非整个仓库，CSV 保存到该文件所在目录
- 生成 CSV 后**必须**用 Python 脚本验证格式，确保可被 Excel/WPS 正确打开

---

## Metadata

- **Version**: 1.4.0
- **Last updated**: 2026-04-16
- **Languages**: Python, C++, Shell/Bash, Markdown
- **Tags**: `#security` `#code-review` `#python` `#cpp` `#shell` `#markdown` `#OWASP` `#CWE`
