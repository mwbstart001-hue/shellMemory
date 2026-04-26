# macOS 平台测试结果报告

## 测试信息

- **测试时间**: 2026-04-26 14:12:13
- **操作系统**: macOS
- **系统版本**: ProductName:		macOS
ProductVersion:		26.2
BuildVersion:		25C56
- **内核版本**: Darwin V_AWBMA-MB0 25.2.0 Darwin Kernel Version 25.2.0: Tue Nov 18 21:09:55 PST 2025; root:xnu-12377.61.12~1/RELEASE_ARM64_T8103 arm64

## 测试汇总

| 项目 | 数值 |
|------|------|
| 总测试数 | 48 |
| 通过 | 48 |
| 失败 | 0 |

**状态**: ✅ 所有测试通过

## 详细测试结果

```
macOS 平台专用测试套件 - 详细日志
========================================


========================================
  测试 1: macOS 环境验证
========================================
[PASS] 当前操作系统为 macOS (Darwin)
       详情: uname -s = Darwin
[PASS] top 命令可用
[PASS] sysctl 命令可用
[PASS] vm_stat 命令可用
[PASS] awk 命令可用
[PASS] grep 命令可用
[PASS] sed 命令可用

========================================
  测试 2: macOS CPU - top 命令输出解析
========================================
[PASS] top -l 2 返回至少 2 个 CPU 使用行
       详情: 获取到        2 行
[PASS] CPU 使用行格式验证
       详情: 行内容: CPU usage: 35.44% user, 31.11% sys, 33.44% idle 
[PASS] CPU 行包含 user/sys/idle 关键字
[PASS] idle 百分比提取成功
       详情: idle = 33.44%
[PASS] CPU 使用率计算 (100 - idle)
       详情: idle=33.44%, CPU=66.56%

========================================
  测试 3: macOS CPU - 边界情况测试
========================================
[PASS] 边界测试: idle=0% → CPU=100.00%
[PASS] 边界测试: idle=50% → CPU=50.00%
[PASS] 边界测试: idle=100% → CPU=0.00%
[PASS] 边界测试: idle=30.5% → CPU=69.50%
[PASS] 边界测试: idle=99.99% → CPU=0.01%
[PASS] 边界保护: idle>100 (150) → CPU=0.00%
[PASS] 边界保护: idle<0 (-50) → CPU=100.00%

========================================
  测试 4: macOS 内存 - sysctl 命令测试
========================================
[PASS] sysctl -n hw.memsize 返回有效数值
       详情: 值: 17179869184 字节
[PASS] 总内存单位转换
       详情: =16777216 KB = 16384 MB = 16 GB
[PASS] sysctl -n vm.pagesize 返回有效页面大小
       详情: 页面大小: 16384 字节

========================================
  测试 5: macOS 内存 - vm_stat 命令测试
========================================
[PASS] vm_stat 命令执行成功
[PASS] vm_stat 输出包含页面大小信息
       详情: 行内容: Mach Virtual Memory Statistics: (page size of 16384 bytes)
[PASS] 页面大小解析成功
       详情: 页面大小: 16384 字节
[PASS] vm_stat 包含 Pages free:
       详情: 值: 4531 页
[PASS] vm_stat 包含 Pages active:
       详情: 值: 169489 页
[PASS] vm_stat 包含 Pages inactive:
       详情: 值: 162333 页
[PASS] vm_stat 包含 Pages speculative:
       详情: 值: 6530 页
[PASS] vm_stat 包含 Pages wired down:
       详情: 值: 157005 页
[PASS] vm_stat 包含 Pages occupied by compressor:
       详情: 值: 512828 页

========================================
  测试 6: macOS 内存 - 计算逻辑测试
========================================
[PASS] free_kb 计算: 1000 页 × 16384 字节 / 1024
       详情: 结果: 16000 KB
[PASS] 可用内存计算: free + inactive + speculative
       详情: 结果: 56000 KB
[PASS] 内存使用率计算
       详情: 总内存: 16777216 KB, 可用: 56000 KB, 使用率: 99.67%

========================================
  测试 7: macOS 错误处理和兜底机制
========================================
[PASS] 空值 idle 处理: 返回 0.00
[PASS] 非数字值 idle 处理: 返回 0.00
[PASS] 除零保护: total=0 时返回 0.00
[PASS] 空值和非数字值正则检查逻辑

========================================
  测试 8: macOS 脚本集成测试
========================================
[PASS] 脚本包含 get_cpu_usage_macos 函数
[PASS] 脚本包含 get_memory_info_macos 函数
[PASS] 脚本使用 top -l 2 进行 CPU 采样
[PASS] 脚本使用 sysctl -n hw.memsize 获取总内存
[PASS] 脚本使用 vm_stat 获取内存页面信息
[PASS] 主脚本在 macOS 上执行成功
       详情: 退出码: 0
[PASS] 脚本正确识别 macOS 系统
[PASS] 输出包含 CPU 使用率列
[PASS] 输出包含内存使用率列
[PASS] 输出包含汇总统计（均值、波动）

========================================
  macOS 专用测试汇总
========================================
总测试数: 48
通过: 48
失败: 0
所有 macOS 专用测试通过！

```

## 测试用例说明

### 测试 1: macOS 环境验证
- 验证当前操作系统是否为 macOS
- 验证所需命令是否可用 (top, sysctl, vm_stat, awk, grep, sed)

### 测试 2: macOS CPU - top 命令输出解析
- 验证 top -l 2 返回的 CPU 使用信息
- 验证 CPU 行格式 (包含 user/sys/idle)
- 测试 idle 百分比提取和 CPU 使用率计算

### 测试 3: macOS CPU - 边界情况测试
- 测试 idle = 0% → CPU = 100%
- 测试 idle = 50% → CPU = 50%
- 测试 idle = 100% → CPU = 0%
- 测试 idle > 100% 的边界保护
- 测试 idle < 0% 的边界保护

### 测试 4: macOS 内存 - sysctl 命令测试
- 验证 sysctl -n hw.memsize 获取总内存
- 验证内存单位转换 (字节 → KB → MB → GB)
- 验证 sysctl -n vm.pagesize 获取页面大小

### 测试 5: macOS 内存 - vm_stat 命令测试
- 验证 vm_stat 命令执行
- 验证页面大小信息解析
- 验证各种页面计数获取 (free, active, inactive, speculative, wired, compressed)

### 测试 6: macOS 内存 - 计算逻辑测试
- 测试页面数到 KB 的转换计算
- 测试可用内存计算 (free + inactive + speculative)
- 测试内存使用率百分比计算

### 测试 7: macOS 错误处理和兜底机制
- 测试空值处理
- 测试非数字值处理
- 测试除零保护
- 测试正则表达式检查逻辑

### 测试 8: macOS 脚本集成测试
- 验证主脚本包含 macOS 专用函数
- 验证主脚本在 macOS 上完整执行
- 验证输出格式正确性

---
*测试报告生成时间: 2026-04-26 14:12:13*
