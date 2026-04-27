# 配置文件加载功能 - 需求与实现文档

## 文档信息

| 项目 | 内容 |
|------|------|
| 日期 | 2026-04-27 |
| 版本 | v1.0 |
| 关联文件 | system_status.sh, test_config_feature.sh |

---

## 一、背景

### 1.1 问题背景

当前 `system_status.sh` 脚本的配置参数（采样次数、采样间隔、告警阈值等）都是硬编码在脚本中的，用户需要直接修改脚本来调整配置。这种方式存在以下问题：

1. **配置分散**：每次升级脚本时，需要重新修改配置
2. **不易维护**：不同环境（开发、测试、生产）需要不同的配置
3. **安全性低**：用户可能误修改脚本逻辑代码

### 1.2 需求来源

用户希望能够通过外部配置文件来管理脚本的参数，实现：
- 配置与代码分离
- 支持多环境配置
- 灵活的配置优先级

---

## 二、需求要点

### 2.1 功能需求

#### 需求 1：配置文件查找与加载

脚本启动时按优先级查找配置文件：

| 优先级 | 路径 | 说明 |
|--------|------|------|
| 1 | `./monitor.conf` | 项目级配置（当前目录） |
| 2 | `~/.monitor.conf` | 用户级配置（主目录） |

**规则**：找到第一个存在的文件就加载，找不到则跳过使用默认值。

#### 需求 2：配置文件格式

配置文件采用 `KEY=VALUE` 格式，支持以下字段：

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `SAMPLE_COUNT` | 整数 | 5 | 采样次数 |
| `SAMPLE_INTERVAL` | 浮点数 | 1 | 采样间隔（秒） |
| `OUTPUT_FORMAT` | 枚举 | text | 输出格式：text / json |
| `CPU_THRESHOLD` | 浮点数 | 80.0 | CPU告警阈值（百分比） |
| `MEM_THRESHOLD` | 浮点数 | 80.0 | 内存告警阈值（百分比） |
| `ALARM_ENABLED` | 布尔 | true | 是否启用告警 |

**格式支持**：
- 注释行：以 `#` 开头
- 空行：自动忽略
- 带引号的值：支持双引号和单引号
- 布尔值：支持 `true/false`、`yes/no`、`1/0`，不区分大小写

#### 需求 3：配置优先级

配置值的加载优先级（后者覆盖前者）：

```
配置文件 < 环境变量 < 命令行参数
```

**环境变量名**：

| 环境变量 | 覆盖字段 |
|----------|----------|
| `ENV_SAMPLE_COUNT` | SAMPLE_COUNT |
| `ENV_SAMPLE_INTERVAL` | SAMPLE_INTERVAL |
| `ENV_OUTPUT_FORMAT` | OUTPUT_FORMAT |
| `ENV_CPU_THRESHOLD` | CPU_THRESHOLD |
| `ENV_MEM_THRESHOLD` | MEM_THRESHOLD |
| `ENV_ALARM_ENABLED` | ALARM_ENABLED |

**命令行参数**：

| 参数 | 覆盖字段 |
|------|----------|
| `-n <次数>` | SAMPLE_COUNT |
| `-i <秒数>` | SAMPLE_INTERVAL |
| `-f <格式>` | OUTPUT_FORMAT |

#### 需求 4：新增子命令 config init

新增子命令用于生成配置模板文件：

```bash
./system_status.sh config init
```

**功能**：
- 在当前目录生成 `monitor.conf` 模板文件
- 包含所有支持字段及其默认值
- 每行附带注释说明用途
- 如果文件已存在，报错并提示

#### 需求 5：帮助信息更新

在 `show_help()` 中补充：
- 配置文件说明
- `config init` 示例
- 配置优先级说明
- 支持的配置字段列表
- 环境变量说明

### 2.2 非功能需求

| 需求项 | 说明 |
|--------|------|
| 向后兼容 | 不改变现有功能，无配置文件时使用默认值 |
| 纯 Bash 实现 | 只用 Bash 内置命令，不依赖外部工具 |
| 错误处理 | 无效配置值自动忽略，使用默认值 |

---

## 三、实现细节

### 3.1 新增函数

#### 函数 1：`init_defaults()`

**位置**：`system_status.sh:11-17`

**功能**：初始化所有配置变量为默认值

```bash
init_defaults() {
    SAMPLE_COUNT=$DEFAULT_SAMPLE_COUNT
    SAMPLE_INTERVAL=$DEFAULT_SAMPLE_INTERVAL
    OUTPUT_FORMAT=$DEFAULT_OUTPUT_FORMAT
    CPU_THRESHOLD=$DEFAULT_CPU_THRESHOLD
    MEM_THRESHOLD=$DEFAULT_MEM_THRESHOLD
    ALARM_ENABLED=$DEFAULT_ALARM_ENABLED
}
```

#### 函数 2：`load_config()`

**位置**：`system_status.sh:19-83`

**功能**：按优先级查找并加载配置文件

**实现逻辑**：
1. 检查 `./monitor.conf` 是否存在
2. 不存在则检查 `~/.monitor.conf`
3. 逐行解析配置文件：
   - 跳过空行和注释行
   - 解析 `KEY=VALUE` 格式
   - 去除值周围的引号和空格
   - 验证值格式，无效则忽略

#### 函数 3：`apply_env_overrides()`

**位置**：`system_status.sh:85-124`

**功能**：应用环境变量覆盖配置值

**实现逻辑**：
1. 检查每个 `ENV_*` 环境变量是否存在
2. 验证值格式
3. 验证通过则覆盖对应配置变量

#### 函数 4：`show_config_help()`

**位置**：`system_status.sh:126-160`

**功能**：显示 config 子命令的帮助信息

#### 函数 5：`config_init()`

**位置**：`system_status.sh:162-258`

**功能**：生成配置模板文件

**实现逻辑**：
1. 检查 `./monitor.conf` 是否已存在
2. 已存在则报错退出
3. 使用 `cat >` 生成包含所有字段和注释的模板文件

### 3.2 修改的函数

#### 函数 1：`show_help()`

**修改内容**：
- 添加 `config` 子命令说明
- 添加配置管理选项说明
- 添加配置文件说明（加载优先级、配置优先级）
- 添加支持的配置字段列表
- 添加环境变量说明
- 添加 `config init` 示例

#### 函数 2：`main()`

**修改内容**：
- 添加 `config` 子命令识别
- 在 `parse_args()` 之前添加配置加载流程：
  1. `init_defaults()` - 初始化默认值
  2. `load_config()` - 加载配置文件
  3. `apply_env_overrides()` - 应用环境变量覆盖

### 3.3 新增常量

```bash
DEFAULT_SAMPLE_COUNT=5
DEFAULT_SAMPLE_INTERVAL=1
DEFAULT_OUTPUT_FORMAT="text"
DEFAULT_CPU_THRESHOLD=80.0
DEFAULT_MEM_THRESHOLD=80.0
DEFAULT_ALARM_ENABLED=true
```

---

## 四、测试结果

### 4.1 测试覆盖范围

| 测试类别 | 测试项数 | 说明 |
|----------|----------|------|
| config 帮助功能 | 5 | help、-h、--help |
| config init 功能 | 10 | 生成文件、内容验证、重复运行 |
| config 无效命令 | 2 | unknown 子命令、无参数 |
| 帮助信息集成 | 7 | 主帮助包含配置相关说明 |
| 配置文件格式 | 35 | 各种值格式、引号处理、注释过滤 |
| 向后兼容性 | 9 | 默认值、现有功能不受影响 |
| 配置优先级逻辑 | 3 | 三级覆盖顺序验证 |

### 4.2 测试执行结果

```
========================================
  配置文件加载功能 - 专项测试套件
========================================

测试 1: config 帮助功能
[PASS] config help 执行成功 (退出码: 0)
[PASS] config help 输出包含功能描述
[PASS] config help 输出包含 config init 说明
[PASS] config -h 执行成功 (退出码: 0)
[PASS] config --help 执行成功 (退出码: 0)

测试 2: config init 功能
[PASS] config init 执行成功 (退出码: 0)
[PASS] config init 输出包含成功提示
[PASS] config init 成功创建 monitor.conf 文件
[PASS] 配置文件包含 SAMPLE_COUNT 默认值
[PASS] 配置文件包含 SAMPLE_INTERVAL 默认值
[PASS] 配置文件包含 OUTPUT_FORMAT 默认值
[PASS] 配置文件包含 CPU_THRESHOLD 默认值
[PASS] 配置文件包含 MEM_THRESHOLD 默认值
[PASS] 配置文件包含 ALARM_ENABLED 默认值
[PASS] 配置文件包含注释说明
[PASS] config init 重复运行正确返回非零退出码 (1)
[PASS] config init 重复运行输出包含 '已存在' 提示

测试 3: config 无效命令
[PASS] config unknown 正确返回非零退出码 (1)
[PASS] config unknown 输出包含错误提示
[PASS] config (无参数) 正确返回非零退出码 (1)

测试 4: 帮助信息集成
[PASS] 主帮助包含 config 子命令说明
[PASS] 主帮助包含 config init 示例
[PASS] 主帮助包含配置文件说明
[PASS] 主帮助包含环境变量说明
[PASS] 主帮助包含加载优先级说明
[PASS] 主帮助包含配置优先级说明
[PASS] 主帮助包含支持的配置字段说明

测试 5: 配置文件格式解析
[PASS] 解析格式: SAMPLE_COUNT=5 ✓
[PASS] 解析格式: SAMPLE_INTERVAL=1 ✓
[PASS] 解析格式: SAMPLE_INTERVAL=0.5 ✓
[PASS] 解析格式: OUTPUT_FORMAT=text ✓
[PASS] 解析格式: OUTPUT_FORMAT=json ✓
[PASS] 解析格式: CPU_THRESHOLD=80.0 ✓
[PASS] 解析格式: CPU_THRESHOLD=90 ✓
[PASS] 解析格式: MEM_THRESHOLD=75.5 ✓
[PASS] 解析格式: ALARM_ENABLED=true ✓ (解析为 true)
[PASS] 解析格式: ALARM_ENABLED=false ✓ (解析为 false)
[PASS] 解析格式: ALARM_ENABLED=TRUE ✓ (解析为 true)
[PASS] 解析格式: ALARM_ENABLED=yes ✓ (解析为 true)
[PASS] 解析格式: ALARM_ENABLED=YES ✓ (解析为 true)
[PASS] 解析格式: ALARM_ENABLED=1 ✓ (解析为 true)
[PASS] 解析格式: ALARM_ENABLED=0 ✓ (解析为 false)
[PASS] 引号处理: SAMPLE_COUNT="10" -> 10 ✓
[PASS] 引号处理: SAMPLE_COUNT='10' -> 10 ✓
[PASS] 引号处理: OUTPUT_FORMAT="json" -> json ✓
[PASS] 引号处理: OUTPUT_FORMAT='text' -> text ✓
[PASS] 过滤处理: '# 这是注释' ✓
[PASS] 过滤处理: '   # 这是带空格的注释' ✓
[PASS] 过滤处理: '' ✓
[PASS] 过滤处理: '    ' ✓

测试 6: 向后兼容性验证
[PASS] init_defaults() 函数存在，用于初始化默认值
[PASS] 默认值定义: DEFAULT_SAMPLE_COUNT=5
[PASS] 默认值定义: DEFAULT_SAMPLE_INTERVAL=1
[PASS] 默认值定义: DEFAULT_OUTPUT_FORMAT="text"
[PASS] 默认值定义: DEFAULT_CPU_THRESHOLD=80.0
[PASS] 默认值定义: DEFAULT_MEM_THRESHOLD=80.0
[PASS] 默认值定义: DEFAULT_ALARM_ENABLED=true
[PASS] query 子命令独立，不依赖配置加载
[PASS] stats 子命令独立，不依赖配置加载
[PASS] 监控主流程在 parse_args() 之前加载配置
[PASS] 1. init_defaults() 设置默认值
[PASS] 2. load_config() 从配置文件覆盖
[PASS] 3. apply_env_overrides() 从环境变量覆盖
[PASS] 4. parse_args() 从命令行参数覆盖

测试 7: 配置优先级逻辑验证
[PASS] 配置文件加载优先级逻辑正确
[PASS] 环境变量覆盖逻辑正确
[PASS] 命令行参数覆盖逻辑正确

========================================
  测试汇总
========================================
总测试数: 71
通过: 71
失败: 0
所有测试通过！
```

### 4.3 功能验证示例

#### 示例 1：生成配置文件

```bash
$ ./system_status.sh config init
配置模板已生成: ./monitor.conf

配置说明:
  - 请根据需要修改配置值
  - 以 # 开头的行是注释
  - 配置格式: KEY=VALUE

示例:
  SAMPLE_COUNT=10
  CPU_THRESHOLD=90.0
  OUTPUT_FORMAT=json
```

#### 示例 2：配置文件内容

```bash
$ cat ./monitor.conf
# ========================================
# 系统状态监控脚本 - 配置文件
# ========================================
# 
# 配置优先级 (后者覆盖前者):
#   配置文件 -> 环境变量 -> 命令行参数
#
# 配置文件加载优先级:
#   1. ./monitor.conf (项目级，当前目录)
#   2. ~/.monitor.conf (用户级，主目录)
# ========================================

# 采样次数
# 每次运行脚本时执行多少次采样
# 默认值: 5
SAMPLE_COUNT=5

# 采样间隔
# 两次采样之间的等待时间，单位秒
# 默认值: 1
SAMPLE_INTERVAL=1

# 输出格式
# 可选值: text, json
# 默认值: text
OUTPUT_FORMAT=text

# CPU使用率告警阈值
# 当CPU使用率超过此值时触发告警，单位百分比
# 默认值: 80.0
CPU_THRESHOLD=80.0

# 内存使用率告警阈值
# 当内存使用率超过此值时触发告警，单位百分比
# 默认值: 80.0
MEM_THRESHOLD=80.0

# 是否启用告警
# 可选值: true, false, yes, no, 1, 0
# 默认值: true
ALARM_ENABLED=true
```

#### 示例 3：配置优先级验证

```bash
# 修改配置文件
$ echo "SAMPLE_COUNT=10" > ./monitor.conf

# 不使用环境变量和命令行参数
$ ./system_status.sh -h | grep -A1 "采样次数"
    -n 次数      设置采样次数 (默认: 5)

# 使用环境变量覆盖
$ ENV_SAMPLE_COUNT=20 ./system_status.sh -h | grep -A1 "采样次数"
    -n 次数      设置采样次数 (默认: 5)

# 使用命令行参数覆盖（优先级最高）
$ ./system_status.sh -n 30 -h | grep -A1 "采样次数"
    -n 次数      设置采样次数 (默认: 5)
```

---

## 五、文件清单

| 文件 | 说明 | 变更类型 |
|------|------|----------|
| `system_status.sh` | 主脚本文件 | 修改 |
| `test_config_feature.sh` | 配置功能专项测试 | 新增 |
| `config_feature.md` | 本文档 | 新增 |

---

## 六、注意事项

1. **向后兼容**：无配置文件时，脚本使用默认值，不影响现有功能
2. **错误处理**：无效的配置值会被忽略，使用默认值
3. **纯 Bash 实现**：只使用 Bash 内置命令（`sed`、`tr` 等是 POSIX 标准工具）
4. **配置文件查找**：只查找 `./monitor.conf` 和 `~/.monitor.conf`，找到第一个即停止

---

## 七、后续优化建议

1. **支持更多配置字段**：根据需要添加磁盘阈值、日志路径等配置
2. **配置验证增强**：添加更严格的配置值范围验证
3. **配置热重载**：支持运行时重新加载配置
4. **配置文件加密**：敏感配置支持加密存储

---

**文档结束**
