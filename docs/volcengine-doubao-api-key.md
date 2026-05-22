# Volcengine/Doubao Speech API Key

[中文](./volcengine-doubao-api-key.zh-CN.md)

LiveSub Cloud AST mode uses **Doubao Speech Simultaneous Interpretation 2.0 / AST** from Volcengine. It does not use Volcano Ark chat models, IAM access keys, ECS OpenAPI credentials, or generic cloud credentials.

Useful official pages:

- [Doubao Speech new console quick start](https://www.volcengine.com/docs/6561/2119699?lang=zh)
- [Simultaneous Interpretation 2.0 API](https://www.volcengine.com/docs/6561/1756902?lang=zh)
- [Doubao Speech billing overview](https://www.volcengine.com/docs/6561/1359369?lang=zh)

## What To Paste Into LiveSub

Use the **API Key** from the Doubao Speech console API Key management page.

In LiveSub:

1. Open **Engine & Account**.
2. Click **Configure Doubao AST**.
3. Paste the speech-console API Key into the first field.
4. Leave **Access Token** empty unless you are using an older speech console that explicitly gives you `X-Api-App-Key` plus `X-Api-Access-Key`.
5. Click **Test Connection** before starting subtitles.

LiveSub sends the new-console key as:

```text
X-Api-Key: your-api-key
X-Api-Resource-Id: volc.service_type.10053
```

The AST endpoint used by LiveSub is:

```text
wss://openspeech.bytedance.com/api/v4/ast/v2/translate
```

## How To Get The Key

1. Sign in to [Volcengine](https://www.volcengine.com/).
2. Open the Doubao Speech console. The official billing docs link the console as `https://console.volcengine.com/speech/app`.
3. In the top-left project selector, choose the project you want to use. The default project is commonly named **Default**.
4. In the resource or service list, activate the Doubao Speech service used for real-time translation. LiveSub targets the official **Simultaneous Interpretation 2.0 / AST** API. Depending on console rollout, the related card may appear around **speech translation**, **simultaneous interpretation**, or **real-time speech** resources.
5. Open **API Key management**.
6. Create a new API Key, or copy the default API Key if the console created one for you.
7. Paste it into LiveSub and run **Test Connection**.

## Do Not Use These

These look similar in Volcengine, but they are not the LiveSub Cloud AST key:

- Volcano Ark API Key for chat/completions models
- IAM **AccessKey ID**
- IAM **Secret Access Key**
- ECS/OpenAPI credentials
- Machine Translation-only credentials
- Recording-file ASR keys
- TTS or voice-clone keys

If the first page you opened is an API doc with `serviceCode=ecs`, you are in the wrong product. ECS is cloud-server infrastructure, not Doubao Speech.

## Which Service Should Be Enabled?

LiveSub currently uses the official **Simultaneous Interpretation 2.0** WebSocket API:

```text
resource id: volc.service_type.10053
mode: speech-to-text translation
default path: English audio -> Chinese subtitles
```

You usually do not need to enable Ark text models, standalone machine translation, TTS, voice cloning, or recording-file recognition for LiveSub's current cloud subtitle mode.

If you are unsure, paste the key into LiveSub and click **Test Connection**. A successful test means the key and service permission are enough for LiveSub.

## Cost And Quota

Volcengine pricing changes over time, so treat the console as the source of truth. As of the current public billing docs, Doubao Speech supports prepaid resource packs and pay-as-you-go billing, and trial quotas are shown in the speech console. The billing overview lists trial quotas for several speech-model services, including token-based real-time speech and simultaneous interpretation services.

LiveSub cloud mode streams audio while subtitles are running. Stop subtitles when you are done so the session does not keep consuming quota.

## Troubleshooting

- **Test Connection succeeds, but no subtitles:** make sure Chrome is playing audible audio and macOS **Screen & System Audio Recording** permission is enabled for LiveSub.
- **401 / authentication failed:** the value is probably not a Doubao Speech API Key, or it has spaces/newlines around it.
- **403 / no permission:** the API Key exists, but the speech translation / simultaneous interpretation service is not enabled in the same project.
- **Quota or billing error:** check the Doubao Speech console resource balance, trial state, and billing settings.
- **You see many different model IDs:** do not choose a model ID in LiveSub v0.2.0-alpha. The cloud subtitle path is fixed to Doubao Speech AST 2.0.
