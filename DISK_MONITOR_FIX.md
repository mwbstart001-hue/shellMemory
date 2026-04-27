# 磁盘监控功能命令行参数支持修复说明

## 一、问题背景

系统监控脚本 `system_status.sh` 已实现磁盘使用率监控功能，但存在以下问题：

1. **命令行参数缺少磁盘阈值支持**：CPU 有 `-c`、内存有 `-m`，但磁盘没有对应的命令行参数
2. **帮助文档不完整**：未包含磁盘阈值相关的参数说明、配置字段和环境变量

## 二、问题分析

### 2.1 现有参数对比

| 指标 | 配置字段 | 环境变量 | 命令行参数 |
|------|----------|----------|------------|
| CPU | `CPU_THRESHOLD` | `ENV_CPU_THRESHOLD` | `-c` |
| 内存 | `MEM_THRESHOLD` | `ENV_MEM_THRESHOLD` | `-m` |
| 磁盘 | `DISK_THRESHOLD` | `ENV_DISK_THRESHOLD` | ❌ **缺失** |

### 2.2 帮助文档缺失内容

- 缺少 `-k` 参数说明
- 缺少 `DISK_THRESHOLD` 配置字段说明
- 缺少 `ENV_DISK_THRESHOLD` 环境变量说明
- 缺少使用磁盘阈值的示例

## 三、修复方案

### 3.1 新增命令行参数 `-k`

在 `parse_args()` 函数中新增 `-k` 参数支持，用于设置磁盘告警阈值。

**修改位置**：`system_status.sh:371, 412-418`

**修改内容**：

```bash
# getopts 字符串中添加 k:
while getopts ":n:i:f:c:m:k:a:h-" opt; do

# 新增 -k 参数处理逻辑
k)
    if ! is_number "$OPTARG"; then
        echo "错误: 磁盘阈值必须是有效的数字"
        exit 1
    fi
    DISK_THRESHOLD=$OPTARG
    ;;
```

### 3.2 更新帮助文档

在 `show_help()` 函数中更新以下内容：

**修改位置**：`system_status.sh:301-355`

#### 3.2.1 监控选项部分

**新增**：
```
    -k 阈值      设置磁盘告警阈值，百分比 (默认: 80.0)
```

#### 3.2.2 配置文件说明部分

**新增**：
```
        DISK_THRESHOLD    磁盘告警阈值，百分比 (默认: 80.0)
```

#### 3.2.3 环境变量说明部分

**新增**：
```
        ENV_DISK_THRESHOLD
```

#### 3.2.4 示例部分

**新增**：
```
    $0 -k 90.0              设置磁盘阈值90%
    $0 -c 70 -m 70 -k 70 -a true  自定义所有阈值并启用告警
```

## 四、修改前后对比

### 4.1 帮助文档对比

**修改前**：
```
监控选项:
    -n 次数      设置采样次数 (默认: 5)
    -i 秒数      设置采样间隔时间 (默认: 1秒)
    -f 格式      设置输出格式 (text/json, 默认: text)
    -c 阈值      设置CPU告警阈值，百分比 (默认: 80.0)
    -m 阈值      设置内存告警阈值，百分比 (默认: 80.0)
    -a true/false 设置是否启用告警 (默认: true)
    -h, --help   显示此帮助信息
```

**修改后**：
```
监控选项:
    -n 次数      设置采样次数 (默认: 5)
    -i 秒数      设置采样间隔时间 (默认: 1秒)
    -f 格式      设置输出格式 (text/json, 默认: text)
    -c 阈值      设置CPU告警阈值，百分比 (默认: 80.0)
    -m 阈值      设置内存告警阈值，百分比 (默认: 80.0)
    -k 阈值      设置磁盘告警阈值，百分比 (默认: 80.0)  # 新增
    -a true/false 设置是否启用告警 (默认: true)
    -h, --help   显示此帮助信息
```

### 4.2 配置字段对比

**修改前**：
```
    支持的配置字段:
        SAMPLE_COUNT      采样次数 (默认: 5)
        SAMPLE_INTERVAL   采样间隔，单位秒 (默认: 1)
        OUTPUT_FORMAT     输出格式: text/json (默认: text)
        CPU_THRESHOLD     CPU告警阈值，百分比 (默认: 80.0)
        MEM_THRESHOLD     内存告警阈值，百分比 (默认: 80.0)
        ALARM_ENABLED     是否启用告警: true/false (默认: true)
```

**修改后**：
```
    支持的配置字段:
        SAMPLE_COUNT      采样次数 (默认: 5)
        SAMPLE_INTERVAL   采样间隔，单位秒 (默认: 1)
        OUTPUT_FORMAT     输出格式: text/json (默认: text)
        CPU_THRESHOLD     CPU告警阈值，百分比 (默认: 80.0)
        MEM_THRESHOLD     内存告警阈值，百分比 (默认: 80.0)
        DISK_THRESHOLD    磁盘告警阈值，百分比 (默认: 80.0)  # 新增
        ALARM_ENABLED     是否启用告警: true/false (默认: true)
```

### 4.3 环境变量对比

**修改前**：
```
    支持的环境变量 (可选，优先级高于配置文件):
        ENV_SAMPLE_COUNT, ENV_SAMPLE_INTERVAL, ENV_OUTPUT_FORMAT
        ENV_CPU_THRESHOLD, ENV_MEM_THRESHOLD, ENV_ALARM_ENABLED
```

**修改后**：
```
    支持的环境变量 (可选，优先级高于配置文件):
        ENV_SAMPLE_COUNT, ENV_SAMPLE_INTERVAL, ENV_OUTPUT_FORMAT
        ENV_CPU_THRESHOLD, ENV_MEM_THRESHOLD, ENV_DISK_THRESHOLD, ENV_ALARM_ENABLED
        # 新增 ENV_DISK_THRESHOLD
```

## 五、测试用例

### 5.1 测试文件

创建专用测试文件 `test_disk_monitor.sh`，包含 10 个测试场景，共 21 个测试点。

### 5.2 测试场景列表

| 测试编号 | 场景 | 描述 |
|----------|------|------|
| 1 | 帮助文档验证 | 验证 `-h` 输出包含 `-k`、`DISK_THRESHOLD`、`ENV_DISK_THRESHOLD` |
| 2 | 有效参数测试 | `-k 95.0` 和 `-k 50`（整数）设置磁盘阈值 |
| 3 | 无效参数测试 | `-k abc` 应输出错误信息 |
| 4 | 组合参数测试 | `-c 60 -m 70 -k 80` 同时设置三个阈值 |
| 5 | 文本输出验证 | 表头包含磁盘(%)、总磁盘(KB)、可用磁盘(KB)列 |
| 6 | JSON 输出验证 | 包含 `disk_used_percent`、`disk_total_kb`、`disk_available_kb` 字段 |
| 7 | 数据有效性 | 磁盘使用率和总容量为有效数值 |
| 8 | 统计输出验证 | 汇总统计包含磁盘行 |
| 9 | 环境变量测试 | `ENV_DISK_THRESHOLD=85.0` 生效 |
| 10 | 优先级测试 | 命令行 `-k` 覆盖环境变量 |

### 5.3 测试结果

```
========================================
  测试汇总
========================================
总测试数: 21
通过: 21
失败: 0
所有测试通过！
```

## 六、使用示例

### 6.1 基本用法

```bash
# 设置磁盘阈值为 90%
./system_status.sh -k 90.0

# 同时设置 CPU、内存、磁盘阈值
./system_status.sh -c 70 -m 75 -k 80

# 使用整数参数
./system_status.sh -k 95

# 组合其他参数
./system_status.sh -n 10 -i 0.5 -k 85.0 -f json
```

### 6.2 使用环境变量

```bash
# 通过环境变量设置磁盘阈值
ENV_DISK_THRESHOLD=85.0 ./system_status.sh

# 环境变量与命令行参数组合（命令行优先级更高）
ENV_DISK_THRESHOLD=85.0 ./system_status.sh -k 90.0
# 结果：磁盘阈值为 90.0（命令行覆盖环境变量）
```

### 6.3 配置优先级

```
配置优先级（后者覆盖前者）：
    配置文件 -> 环境变量 -> 命令行参数
```

## 七、文件修改清单

| 文件 | 修改类型 | 修改内容 |
|------|----------|----------|
| `system_status.sh` | 修改 | 新增 `-k` 参数支持，更新帮助文档 |
| `test_disk_monitor.sh` | 新增 | 磁盘监控功能专用测试脚本 |

## 八、注意事项

1. **参数命名**：选择 `-k` 是因为 `-d` 已被 query/stats 子命令用于日期筛选
2. **数值验证**：使用 `is_number()` 函数验证参数有效性，与 CPU/内存保持一致
3. **优先级**：命令行参数优先级最高，其次是环境变量，最后是配置文件
4. **向后兼容**：不改变现有 `-c`、`-m` 参数的行为

## 九、相关提交

| 提交哈希 | 说明 |
|----------|------|
| `22f76be` | feat: 新增磁盘阈值命令行参数支持 |
| `bcc4b7a` | feat: 新增磁盘使用率监控功能（基础功能） |

---

**修复完成时间**：2026-04-27

**测试状态**：✅ 所有测试通过
