# 系统状态监控脚本

## 项目背景

在服务器运维和应用监控场景中，经常需要实时了解服务器的 CPU 和内存使用情况。本项目提供一个轻量级的跨平台 Shell 脚本，用于快速获取并统计服务器的 CPU 和内存状态信息。

## 技术栈

| 技术 | 说明 |
|------|------|
| Bash Shell | 主要脚本语言 |
| AWK | 浮点运算和数据处理 |
| /proc/stat (Linux) | CPU 状态信息源 |
| /proc/meminfo (Linux) | 内存状态信息源 |
| sysctl/vm_stat (macOS) | macOS 系统信息获取 |
| wmic (Windows) | Windows 系统信息获取 |

## 功能特性

### 1. 跨平台支持

- ✅ **Linux/CentOS**：通过 `/proc` 文件系统获取系统信息
- ✅ **macOS**：通过 `sysctl`、`vm_stat`、`top` 命令获取系统信息
- ✅ **Windows**：通过 `wmic` 命令获取系统信息（适用于 Cygwin/Mingw 环境）

### 2. CPU 使用率计算

- **Linux/CentOS**：通过 `/proc/stat` 两次采样差值计算 CPU 使用率
  - 不依赖 `top` 命令作为最终结果
  - 计算方式：`CPU使用率 = 100 - (空闲时间变化 / 总时间变化) * 100`

- **macOS**：解析 `top` 命令输出，计算 `100 - idle%`

- **Windows**：通过 `wmic cpu get LoadPercentage` 获取

### 3. 内存信息获取

- **Linux/CentOS**：从 `/proc/meminfo` 读取
  - `MemTotal`：总内存
  - `MemAvailable`：可用内存
  - 已用内存 = `MemTotal - MemAvailable`

- **macOS**：
  - 总内存：`sysctl -n hw.memsize`
  - 可用内存：`vm_stat` 计算（free + inactive + speculative）

- **Windows**：
  - 总内存：`wmic OS get TotalVisibleMemorySize`
  - 可用内存：`wmic OS get FreePhysicalMemory`

### 4. 统计输出

- 连续采样 **5 次**，每次间隔 **1 秒**
- 每次采样输出一行明细，列宽对齐
- 5 次采样后输出汇总统计：
  - **均值**：5 次采样的平均值
  - **最大**：5 次采样中的最大值
  - **最小**：5 次采样中的最小值
  - **波动**：最大值 - 最小值

### 5. 健壮性设计

- 浮点运算全部使用 **AWK**，不依赖 `bc`
- 除零保护：在计算百分比时检查分母是否为 0
- 文件不存在兜底：`/proc/stat` 或 `/proc/meminfo` 不存在时返回默认值
- 命令解析失败兜底：命令输出解析失败时返回默认值
- 空值和非数字值检查和处理

## 使用方法

### 运行脚本

```bash
# 赋予执行权限
chmod +x system_status.sh

# 运行脚本
./system_status.sh
```

### 输出示例

```
========================================
系统状态监控脚本
操作系统: macos
采样次数: 5 次
采样间隔: 1 秒
========================================

次数   CPU(%)  内存(%) 总内存(KB) 可用内存(KB)
---------------------------------------------------------------
1         50.30      83.22     16777216         2814912
2         60.80      83.12     16777216         2832064
3         54.19      82.66     16777216         2908496
4         36.20      82.51     16777216         2934416
5         50.18      82.64     16777216         2912064
---------------------------------------------------------------

========================================
汇总统计
========================================
指标   均值   最大   最小   波动
------------------------------------------------
CPU       50.33    60.80    36.20    24.60
内存    82.83    83.22    82.51     0.71
------------------------------------------------

监控完成！
```

## 项目结构

```
10-shellMoney/
├── system_status.sh    # 主监控脚本
├── test_system_status.sh  # 测试脚本
└── README.md           # 本文档
```

## 核心函数说明

| 函数名 | 功能 |
|--------|------|
| `get_os_type()` | 检测当前操作系统类型 |
| `get_cpu_usage_linux()` | Linux 平台 CPU 使用率计算 |
| `get_cpu_usage_macos()` | macOS 平台 CPU 使用率计算 |
| `get_cpu_usage_windows()` | Windows 平台 CPU 使用率计算 |
| `get_memory_info_linux()` | Linux 平台内存信息获取 |
| `get_memory_info_macos()` | macOS 平台内存信息获取 |
| `get_memory_info_windows()` | Windows 平台内存信息获取 |
| `calculate_stats()` | 统计计算（均值、最大、最小、波动） |
| `main()` | 主函数，控制采样流程和输出 |

## 配置参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `SAMPLE_COUNT` | 5 | 采样次数 |
| `SAMPLE_INTERVAL` | 1 | 采样间隔（秒） |

如需修改采样次数或间隔，可编辑脚本顶部的常量定义：

```bash
SAMPLE_COUNT=5      # 采样次数
SAMPLE_INTERVAL=1   # 采样间隔（秒）
```

## 测试

项目包含测试脚本 `test_system_status.sh`，用于验证脚本的各项功能：

```bash
# 运行测试
chmod +x test_system_status.sh
./test_system_status.sh
```

测试用例包括：
1. 操作系统类型检测测试
2. CPU 使用率获取测试
3. 内存信息获取测试
4. 统计计算功能测试
5. 错误处理和兜底机制测试

## 注意事项

1. **Linux/CentOS 平台**：CPU 使用率通过两次采样差值计算，每次采样本身会等待 1 秒
2. **macOS 平台**：`top` 命令需要运行两次采样才能获取准确的 CPU 使用率
3. **Windows 平台**：需要在 Cygwin 或 Mingw 环境下运行
4. 脚本中所有浮点运算都使用 AWK，确保跨平台兼容性

## License

MIT License
