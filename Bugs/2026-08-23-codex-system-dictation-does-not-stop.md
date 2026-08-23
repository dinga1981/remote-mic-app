# Codex Keeps macOS Dictation Active After Voice-Key Release

- 时间：2026-08-23
- 状态：候选修复完成，等待本机 Codex + RC003 真机验收
- 影响范围：本机开发版、macOS 26、Codex `com.openai.codex`、RC003、macOS 系统听写
- 功能点：语音键松开、音频 drain、系统听写停止动作
- 简单描述：大多数应用在遥控器语音键松开后正常退出系统听写；Codex 输入框仍保持听写状态。

## Observation

1. 在 Codex 输入框内按住 RC003 语音键并讲话。
2. 松开语音键，文字正常出现。
3. Expected：音频排空后系统听写自动退出。
4. Actual：系统听写继续保持开启。
5. Control：此时手动按 Fn-D 仍无法退出；按 Esc 可以立即退出。用户暂未在其他应用发现同样问题。

## Log Evidence

- 2026-08-23 09:51:33-09:51:45 UTC：会话 86 收到 177,600 个样本、零入队失败，松键后完成 drain，并记录第二组 `VOICE SYSTEM DICTATION key=fn-d state=down/up success=true`。
- 2026-08-23 09:57:14-09:57:39 UTC：会话 87 收到 376,320 个样本、零入队失败，同样完成 drain 和第二组 Fn-D 注入。
- 因此遥控器松键、音频停止和合成快捷键注入均已完成；`success=true` 只证明 CGEvent 已发布，不能证明 Codex 中的系统听写实际关闭。

## Hypothesis and Experiment

初始假设是 Codex 的动态编辑器在听写文字更新时改变了焦点，导致切换式 Fn-D 停止动作不再被系统听写接受。真实对照进一步证明，问题不是合成事件与物理事件的差异：听写残留时，物理 Fn-D 也无法退出，而物理 Esc 可以退出。

## Root Cause

Codex 与 macOS 系统听写的停止交互不同于当前已验证的普通输入框：启动仍接受 Fn-D，但活动中的听写不能通过第二次 Fn-D 关闭，只接受 Esc。应用此前对所有前台应用固定使用成对 Fn-D，因此 Codex 路径没有产生有效的停止动作。

## Fix

- 保留所有应用的 Fn-D 启动动作和音频 drain 时序。
- 仅当语音工具是 macOS 系统听写且松键时前台 Bundle ID 为 `com.openai.codex`，使用无修饰键的 Esc 作为停止动作，并记录 `target=codex` 日志。
- Typeless、其他语音工具以及非 Codex 应用继续使用原有停止动作。
- 停止覆盖失败时沿用现有 fail-closed 路径，不再补发可能重新打开听写的 Fn-D。

## Verification Results

- 项目自检：47/47 通过，新增“Codex 系统听写停止使用 Esc 覆盖”的回归用例。
- 生产目标在本机旧 SDK 兼容分支下完整编译并链接成功。
- Swift 语法解析和 `git diff --check`：通过。
- Swift Testing 测试源已增加覆盖，但本机旧 SDK 缺少 `Testing` 模块，无法执行；生产目标在测试构建过程中已成功编译。该工具链边界与 2026-08-22 本机开发版记录一致。
- 真实 Codex + RC003 候选 App 的“按住说话 → 松开 → Esc 自动结束 → 连续第二次仍可用”仍待验收。

## Verification Boundary

自动化可以证明 Codex 覆盖替代关闭 Fn-D、仅执行一次并在失败时关闭会话，不能证明 macOS 听写浮层实际接收 Esc，也不能证明 Esc 不会在听写已经异常退出时影响 Codex 页面。必须在本机开发版中对 Codex 连续执行至少三次真实语音，并对任意一个普通应用执行稳定基线。
