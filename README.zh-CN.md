# LiveSub 直播字幕

[English](./README.md)

Chrome 里播放的英文内容，给你更好读、更可控的实时中文字幕。

LiveSub 是一个 macOS 原生实时字幕工具，可以捕获 Google Chrome 音频，并以低延迟中文字幕浮窗显示。适合 YouTube Live、Twitch、Chrome 网页版 X Spaces、播客、访谈、课程、发布会等英文实时内容。

> 当前状态：`v0.2.1-alpha`。已经可以使用，但仍是早期内测版本。

## 为什么做 LiveSub？

原生字幕适合同语种字幕，但如果你想实时看懂英文内容，通常还不够。

LiveSub 关注这些问题：

- 不只是英文字幕，而是中文字幕
- 更适合长直播的纯字字幕浮窗
- 错过一句话时，可以回看多段历史字幕
- 围绕 Chrome 里的 YouTube、Twitch、Space、课程、访谈打磨
- 云端模式降低本机 CPU/GPU 压力

## 功能

- 使用 macOS ScreenCaptureKit 捕获 Google Chrome App 音频
- 实时显示中文字幕浮窗，支持置顶
- 默认纯字字幕模式，更接近视频字幕观感
- 可切换到历史面板，查看多段上下文
- 支持火山引擎 / 豆包语音大模型 API Key 云端模式
- 支持 WhisperKit + Ollama Qwen 本地模式
- 自动保存字幕会话为 Markdown、JSONL 和 manifest
- 主控制中心显示 CPU / 内存低中高占用状态

## 下载

在 GitHub Releases 下载最新 Alpha 包：

```text
LiveSub-v0.2.1-alpha-macos.zip
```

解压后，右键 `LiveSub.app`，选择 **打开**。当前 Alpha 版本是临时签名，macOS 可能提示“不明开发者”。

## 快速开始

1. 打开 `LiveSub.app`。
2. 在 **引擎与账号** 中配置火山 / 豆包语音服务 API Key。不知道怎么获取的话，看 [火山 / 豆包语音 API Key 获取指南](./docs/volcengine-doubao-api-key.zh-CN.md)。
3. 点击 **测试连接**。
4. 按提示授权 macOS **屏幕与系统音频录制** 权限。
5. 在 Google Chrome 中播放英文音频。
6. 点击 **开始 Chrome 字幕**。

推荐大多数用户优先使用云端模式，因为本机 CPU/GPU 压力更低。

## 火山 API Key 应该填哪种？

LiveSub 云端 AST 模式使用火山 / 豆包语音大模型服务里的 API Key。

应该使用：

- 语音服务控制台 API Key 管理页面里的 API Key
- 已开通流式语音识别 / 语音翻译相关服务

不要使用：

- Ark 大模型 API Key
- IAM AccessKey ID
- IAM Secret Access Key
- ECS/OpenAPI 之类的通用云服务凭证

LiveSub 会通过 `X-Api-Key` 发送新版语音控制台 API Key。旧版 Access Token 字段只保留给旧控制台兼容。

详细步骤见：[火山 / 豆包语音 API Key 获取指南](./docs/volcengine-doubao-api-key.zh-CN.md)。

## 隐私

LiveSub 不包含遥测。云端模式会把 Chrome 音频片段发送到火山 / 豆包语音服务用于识别和翻译。本地模式会把识别和翻译保留在你的 Mac 上，但会占用更多本机资源。

详细说明见 [PRIVACY.md](./PRIVACY.md)。

## 本地数据

LiveSub 会把配置和字幕会话保存在：

```text
~/Library/Application Support/LiveSub/
```

字幕会话保存在：

```text
~/Library/Application Support/LiveSub/Sessions/
```

## 从源码构建

要求：

- macOS 15+
- Xcode Command Line Tools
- Swift 6 toolchain

构建 release App 和 zip：

```sh
./scripts/build-localv-app-shell.sh
```

输出：

```text
build/LiveSub.app
build/apps/LiveSub-0.2.1-alpha.app
build/releases/LiveSub-v0.2.1-alpha-macos.zip
```

运行核心冒烟测试：

```sh
swift run --package-path mac/Packages/LocalVCore LocalVCoreSmokeTests
```

## 路线图

见 [ROADMAP.md](./ROADMAP.md)。

## License

MIT。见 [LICENSE](./LICENSE)。
