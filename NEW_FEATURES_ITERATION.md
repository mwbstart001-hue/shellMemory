# 系统状态监控脚本 - 新功能迭代文档

## 迭代概述

本次迭代为 `system_status.sh` 脚本添加了以下新功能：

1. **动态配置化采样参数**：支持通过命令行参数自定义采样次数和采样间隔时间
2. **多种输出格式**：支持文本格式（默认）和JSON格式输出
3. **完善的命令行参数解析**：支持 `-n`、`-i`、`-f`、`-h`、`--help` 等选项

## 新增功能详情

### 1. 命令行参数

| 参数 | 说明 | 默认值 | 示例 |
|------|------|--------|------|
| `-n` | 设置采样次数 | 5 | `-n 10` （采样10次） |
| `-i` | 设置采样间隔时间（秒） | 1 | `-i 2` （间隔2秒） |
| `-f` | 设置输出格式 | text | `-f json` （JSON格式输出） |
| `-h` | 显示帮助信息 | - | `-h` |
| `--help` | 显示帮助信息 | - | `--help` |

### 2. 输出格式

#### 文本格式（默认）
- 友好的人类可读格式
- 包含系统信息、采样数据和汇总统计
- 适合手动查看和调试

#### JSON格式
- 结构化数据格式
- 包含完整的配置信息、系统信息、采样数据和统计数据
- 适合程序解析和自动化处理

### 3. JSON输出结构

```json
{
    "config": {
        "sample_count": 5,
        "sample_interval": 1,
        "cpu_threshold": 80.0,
        "memory_threshold": 80.0,
        "alarm_enabled": "true"
    },
    "system_info": {
        "os": "macos",
        "server_id": "server01",
        "alarm_log_file": "/Library/Logs/SystemMonitor/alarm_2026_17.log"
    },
    "samples": [
        {
            "sample_num": 1,
            "cpu_usage": 45.23,
            "memory_used_percent": 75.50,
            "memory_total_kb": 16777216,
            "memory_available_kb": 4108544
        },
        {
            "sample_num": 2,
            "cpu_usage": 52.18,
            "memory_used_percent": 76.20,
            "memory_total_kb": 16777216,
            "memory_available_kb": 3992320
        }
    ],
    "statistics": [
        {
            "label": "CPU",
            "mean": 48.71,
            "max": 52.18,
            "min": 45.23,
            "fluctuation": 6.95
        },
        {
            "label": "内存",
            "mean": 75.85,
            "max": 76.20,
            "min": 75.50,
            "fluctuation": 0.70
        }
    ]
}
```

## 使用示例

### 基本用法

#### 使用默认配置
```bash
./system_status.sh
```
- 采样次数：5次
- 采样间隔：1秒
- 输出格式：文本格式

#### 自定义采样参数
```bash
./system_status.sh -n 10 -i 2
```
- 采样次数：10次
- 采样间隔：2秒
- 输出格式：文本格式

#### JSON格式输出
```bash
./system_status.sh -n 5 -i 1 -f json
```
- 采样次数：5次
- 采样间隔：1秒
- 输出格式：JSON格式

#### 查看帮助信息
```bash
./system_status.sh -h
```
或
```bash
./system_status.sh --help
```

### 高级用法

#### 结合其他命令处理JSON输出
```bash
# 使用jq解析JSON输出（需要安装jq）
./system_status.sh -n 3 -f json | jq '.statistics'

# 使用Python解析JSON输出
./system_status.sh -n 3 -f json | python3 -m json.tool

# 提取特定字段
./system_status.sh -n 3 -f json | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'CPU均值: {d[\"statistics\"][0][\"mean\"]}%')"
```

## 测试结果

### 测试环境
- 操作系统：macOS
- 脚本文件：`system_status.sh`
- 测试日期：2026-04-26

### 测试用例

#### 测试1：帮助选项
**命令：**
```bash
./system_status.sh -h
```

**预期结果：**
- 显示完整的帮助信息
- 包含用法说明、选项列表和示例
- 退出码为0

**实际结果：** ✅ 通过
- 正确显示帮助信息
- 包含所有必要的使用说明

#### 测试2：无效选项处理
**命令：**
```bash
./system_status.sh -z
./system_status.sh -f xml
./system_status.sh -n abc
```

**预期结果：**
- 显示相应的错误信息
- 提示正确的使用方法

**实际结果：** ✅ 通过
- `-z` 选项：显示"错误: 无效选项 -z"
- `-f xml` 选项：显示"错误: 输出格式只能是 'text' 或 'json'"
- `-n abc` 选项：显示"错误: 采样次数必须是有效的数字"

#### 测试3：自定义采样次数
**命令：**
```bash
./system_status.sh -n 2
```

**预期结果：**
- 只进行2次采样
- 输出包含2行采样数据

**实际结果：** ✅ 通过
- 正确执行2次采样
- 输出格式正确

#### 测试4：文本格式输出
**命令：**
```bash
./system_status.sh -n 2 -f text
```

**预期结果：**
- 显示友好的文本格式输出
- 包含系统信息、采样数据和汇总统计

**实际结果：** ✅ 通过
- 输出格式为文本格式
- 包含所有必要的信息

#### 测试5：JSON格式输出
**命令：**
```bash
./system_status.sh -n 2 -f json
```

**预期结果：**
- 输出有效的JSON格式
- 包含config、system_info、samples、statistics四个主要部分

**实际结果：** ✅ 通过
- 输出为有效的JSON格式
- 包含所有必要的字段
- 结构完整且正确

**示例输出：**
```json
{
    "config": {
        "sample_count": 2,
        "sample_interval": 1,
        "cpu_threshold": 80.0,
        "memory_threshold": 80.0,
        "alarm_enabled": "true"
    },
    "system_info": {
        "os": "macos",
        "server_id": "V_AWBMA-MB0",
        "alarm_log_file": "/Library/Logs/SystemMonitor/alarm_2026_17.log"
    },
    "samples": [
        {"sample_num":1,"cpu_usage":42.48,"memory_used_percent":81.73,"memory_total_kb":16777216,"memory_available_kb":3064544},
        {"sample_num":2,"cpu_usage":60.74,"memory_used_percent":81.95,"memory_total_kb":16777216,"memory_available_kb":3028352}
    ],
    "statistics": [
        {"label":"CPU","mean":51.61,"max":60.74,"min":42.48,"fluctuation":18.26},
        {"label":"内存","mean":81.84,"max":81.95,"min":81.73,"fluctuation":0.22}
    ]
}
```

#### 测试6：组合选项
**命令：**
```bash
./system_status.sh -n 3 -f json
```

**预期结果：**
- 执行3次采样
- 输出JSON格式
- 包含3个采样数据点

**实际结果：** ✅ 通过
- 正确执行3次采样
- 输出格式为JSON
- 包含3个采样数据点

#### 测试7：缺少参数处理
**命令：**
```bash
./system_status.sh -n
./system_status.sh -i
./system_status.sh -f
```

**预期结果：**
- 显示相应的错误信息
- 提示选项需要参数

**实际结果：** ✅ 通过
- 正确识别缺少参数的情况
- 显示相应的错误信息

### 测试汇总

| 测试项 | 状态 | 说明 |
|--------|------|------|
| 帮助选项 (-h, --help) | ✅ 通过 | 正确显示帮助信息 |
| 无效选项处理 | ✅ 通过 | 正确识别并报告无效选项 |
| 自定义采样次数 (-n) | ✅ 通过 | 正确设置采样次数 |
| 文本格式输出 (-f text) | ✅ 通过 | 正确输出文本格式 |
| JSON格式输出 (-f json) | ✅ 通过 | 正确输出JSON格式 |
| 组合选项 | ✅ 通过 | 多个选项组合正常工作 |
| 缺少参数处理 | ✅ 通过 | 正确识别缺少参数的情况 |

**总体测试结果：** ✅ 所有核心功能测试通过

## 代码变更说明

### 新增函数

1. **`show_help()`**
   - 显示帮助信息
   - 包含用法说明、选项列表和示例

2. **`parse_args()`**
   - 解析命令行参数
   - 支持 `-n`、`-i`、`-f`、`-h`、`--help` 选项
   - 验证参数有效性
   - 处理无效选项和缺少参数的情况

3. **`calculate_stats_json()`**
   - 计算统计数据并返回JSON格式
   - 包含均值、最大值、最小值、波动值

4. **`escape_json_string()`**
   - 转义JSON字符串中的特殊字符
   - 处理反斜杠、双引号、换行符等

### 修改函数

1. **`main()`**
   - 调用 `parse_args()` 解析命令行参数
   - 根据 `OUTPUT_FORMAT` 变量选择输出格式
   - 支持文本格式和JSON格式两种输出模式
   - 收集采样数据用于JSON输出

### 新增变量

| 变量名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `OUTPUT_FORMAT` | 字符串 | "text" | 输出格式 (text/json) |

## 兼容性说明

### 向后兼容
- 所有原有功能保持不变
- 不使用任何新参数时，行为与之前完全一致
- 默认值与原有配置相同

### 平台兼容性
- 支持 Linux、macOS、Windows (Cygwin/MINGW)
- 与原有代码保持相同的平台兼容性

## 注意事项

1. **采样间隔时间**
   - 在Linux平台上，CPU使用率计算本身需要两次采样（间隔1秒）
   - `-i` 参数设置的是多次采样之间的间隔时间
   - 实际总时间 = 采样次数 × (CPU采样时间 + 配置的间隔时间)

2. **JSON输出中的告警信息**
   - 当CPU或内存使用率超过阈值时，告警信息会输出到stderr
   - JSON格式的主数据输出到stdout
   - 可以使用 `2>/dev/null` 屏蔽告警信息

3. **参数验证**
   - 采样次数必须是有效的数字
   - 采样间隔必须是有效的数字
   - 输出格式只能是 `text` 或 `json`

## 后续优化建议

1. **增加更多输出格式**
   - CSV格式：适合导入Excel进行分析
   - YAML格式：适合配置文件和自动化工具

2. **增强参数验证**
   - 限制采样次数的最小值和最大值
   - 限制采样间隔的最小值（避免过于频繁采样）

3. **增加配置文件支持**
   - 支持从配置文件读取默认参数
   - 可以与命令行参数结合使用

4. **增强JSON输出**
   - 支持美化和压缩两种JSON格式
   - 增加时间戳字段
   - 支持输出到文件而不是stdout

## 总结

本次迭代成功为 `system_status.sh` 脚本添加了动态配置化采样参数和JSON输出格式功能。所有核心功能测试通过，脚本保持了良好的向后兼容性。

**主要成果：**
- ✅ 支持通过 `-n` 参数自定义采样次数
- ✅ 支持通过 `-i` 参数自定义采样间隔时间
- ✅ 支持通过 `-f` 参数选择输出格式（text/json）
- ✅ 支持 `-h` 和 `--help` 显示帮助信息
- ✅ JSON输出格式结构完整，适合程序解析
- ✅ 所有测试用例通过，功能稳定可靠

---

**文档版本：** v1.0  
**最后更新：** 2026-04-26  
**作者：** AI Assistant
