# Voice Fn Tap Mode Is Disabled After Remote Reconnect

- 时间：2026-08-22
- 状态：候选修复完成，等待本机 RC003 断连重连真机验收
- 影响范围：本机开发版、macOS 26、Apple Silicon、小米蓝牙遥控器 2 Pro（RC003）、macOS 系统听写
- 功能点：蓝牙重连、语音键点按触发、HID 映射、设置持久化
- 简单描述：遥控器长时间闲置并重新连接后，“语音键使用点按式触发”会被自动关闭，用户必须手动重新开启才能继续使用系统听写。

## Observation

1. 选择 macOS 系统听写并开启“语音键使用点按式触发”。
2. 使用 RC003 语音键，Fn-D 能正常启动和停止系统听写，文字可以上屏。
3. 让遥控器长时间闲置直至与 Mac 断开，然后重新连接。
4. Expected：开关仍保持开启，重连后的第一次语音可直接启动系统听写。
5. Actual：开关变为关闭；语音会话仍能传输音频，但不再发送 Fn-D，必须手动重新开启。

## Log Evidence

- 2026-08-22 00:32:25 UTC 的重连现场连续记录 `VOICE FN MAPPING applied=false neutralized=false ... matched=0`。
- 后续重连继续记录 `neutralized=false`，说明持久化设置已经被改成关闭，而不只是一次运行时映射失败。
- 2026-08-22 07:13 UTC 的语音会话使用 `route=virtual_audio`，没有 Fn-D 注入。
- 07:14 UTC 手动重新开启后，日志变为 `applied=true neutralized=true`；下一次会话使用 `route=fn_tap`，Fn-D 按下和松开都成功。

## Hypothesis and Experiment

假设：CoreBluetooth 已报告设备 Ready 时，macOS HID 服务可能仍处于重新枚举窗口。`applyHIDSettings()` 在这个瞬间找不到 RC003 映射目标，并把暂时的 `matched=0` 当成永久失败，将 `voiceFnTapModeEnabled` 写成 `false`。

代码检查确认该路径同时存在于重连设置应用和用户手动开启流程。最小策略测试把“用户请求开启”和“当前映射是否已经就绪”拆成两个状态：请求开启但映射暂缺应为 `waitingForMapping`，不得等同于 `disabled`。

## Root Cause

持久化的用户意图与易变的 HID 运行时状态混在同一个布尔值中。重连时一次暂时的 HID 枚举空档覆盖了用户已保存的开启选择，因此后续连接都按关闭状态运行。

## Fix

- 保留用户明确选择的点按触发设置；临时找不到语音键或辅助功能权限尚未就绪时，只暂停运行时会话，不再写回关闭。
- HID 映射暂缺时按 250 ms、500 ms、1 s、2 s、4 s 自动重试；成功后恢复点按触发会话。
- 断连时取消当前等待项，下一次 Ready 从头恢复；用户明确关闭时立即取消重试并保存关闭。
- 保留真实 Fn-D 注入失败的原有安全回退，避免故障状态下反复发送快捷键。

## Verification Results

- 项目自检：46/46 通过，包含“RC003 瞬时映射空档保留点按触发请求”的新回归用例。
- 新策略单元测试覆盖映射暂缺、映射恢复、辅助功能权限暂缺和用户明确关闭。
- Swift 语法解析和 `git diff --check`：通过。
- 完整 Swift Testing 在本机受 Command Line Tools 编译器与 macOS 26 SDK 补丁版本不一致阻塞；使用旧 SDK 又缺少项目采用的 macOS 26 SwiftUI API。这是本机工具链限制，不是测试断言失败。
- 原始故障已由真实 RC003 日志复现并确认；修复后的本地 App 仍需执行“闲置断连 → 自动重连 → 不手动碰开关 → 第一次语音文字上屏”的真机验收。

## Verification Boundary

策略测试只能证明暂时状态不会覆盖持久化选择，不能证明真实 CoreBluetooth/HID 重新枚举时间、Fn-D 系统事件和最终文字输入。候选修复必须安装到隔离 Bundle ID 的本机开发版，并由 RC003 与 macOS 系统听写完成上述断连重连旅程后才能标记通过。
