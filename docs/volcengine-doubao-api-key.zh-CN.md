# 火山 / 豆包语音 API Key 获取指南

[English](./volcengine-doubao-api-key.md)

LiveSub 云端模式用的是火山引擎 **豆包语音同声传译 2.0 / AST**。它不是火山方舟文本大模型，不是 IAM AK/SK，不是 ECS OpenAPI，也不是通用云服务密钥。

官方参考：

- [豆包语音新版控制台快速入门](https://www.volcengine.com/docs/6561/2119699?lang=zh)
- [同声传译 2.0 API 接入文档](https://www.volcengine.com/docs/6561/1756902?lang=zh)
- [豆包语音计费概述](https://www.volcengine.com/docs/6561/1359369?lang=zh)

## LiveSub 里到底填什么？

填 **豆包语音控制台 API Key 管理** 页面里的 API Key。

在 LiveSub 里：

1. 打开 **引擎与账号**。
2. 点击 **配置豆包 AST**。
3. 把语音控制台里的 API Key 粘贴到第一栏。
4. **Access Token** 通常留空。只有旧版控制台明确给你 `X-Api-App-Key` + `X-Api-Access-Key` 时才填第二栏。
5. 点击 **测试连接**，通过后再开始字幕。

LiveSub 新版控制台鉴权发送的是：

```text
X-Api-Key: 你的 API Key
X-Api-Resource-Id: volc.service_type.10053
```

LiveSub 当前使用的 AST 接口是：

```text
wss://openspeech.bytedance.com/api/v4/ast/v2/translate
```

## 获取步骤

1. 登录 [火山引擎](https://www.volcengine.com/)。
2. 进入豆包语音控制台。官方计费文档里的控制台地址是 `https://console.volcengine.com/speech/app`。
3. 看左上角项目选择器，确认你正在使用的项目。新账号通常是 **Default（默认项目）**。
4. 在资源或服务列表里开通实时翻译相关的豆包语音服务。LiveSub 对接的是官方 **同声传译 2.0 / AST** API。不同批次控制台可能会把相关能力显示在 **语音同传**、**同声传译**、**端到端实时语音** 一类资源附近。
5. 打开 **API Key 管理**。
6. 如果已经有默认 API Key，可以复制它；也可以新建一个 API Key。
7. 回到 LiveSub 粘贴 API Key，然后点 **测试连接**。

## 不要填这些

这些名字看起来像密钥，但不是 LiveSub 云端 AST 要的 Key：

- 火山方舟 Ark API Key
- IAM **AccessKey ID**
- IAM **Secret Access Key**
- ECS/OpenAPI 云服务器凭证
- 只给机器翻译用的凭证
- 录音文件识别类 Key
- TTS / 声音复刻类 Key

如果你打开的是 `serviceCode=ecs` 那种 API 文档，那就是走错了。ECS 是云服务器，不是豆包语音。

## 应该开通哪个服务？

LiveSub 当前固定走官方 **同声传译 2.0** WebSocket API：

```text
resource id: volc.service_type.10053
模式：语音到文本翻译
默认路径：英文音频 -> 中文字幕
```

当前版本一般不需要你开通火山方舟文本模型、单独机器翻译、TTS、声音复刻、录音文件识别。

如果你不确定自己开对没有，最直接的判断方式是：把 Key 填到 LiveSub，点 **测试连接**。测试通过，就说明这个 Key 和服务权限对 LiveSub 够用。

## 价格和额度

价格会变，所以最终以火山控制台为准。按当前公开计费文档，豆包语音支持资源包预付费和按量后付费；试用额度会显示在语音控制台。计费概述里列出了多种语音大模型的试用额度，包括端到端实时语音、同声传译等 token 计费服务。

LiveSub 云端模式是在字幕运行时持续传音频。用完记得停止字幕，避免会话一直消耗额度。

## 常见错误

- **测试连接成功但没字幕**：确认 Chrome 真的在播放声音，并且 macOS 已给 LiveSub **屏幕与系统音频录制** 权限。
- **401 / 鉴权失败**：通常是填错 Key 类型，或者复制时多了空格/换行。
- **403 / 无权限**：Key 是真的，但同项目下没有开通语音同传 / 同声传译相关服务。
- **额度或计费错误**：去豆包语音控制台看资源包、试用额度、欠费和后付费状态。
- **看到很多模型 ID 不知道选哪个**：LiveSub v0.2.0-alpha 不需要选模型 ID。云端字幕固定用豆包语音 AST 2.0。
