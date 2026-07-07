# Foundation Models Framework: WWDC25 vs WWDC26

這份筆記整理 Foundation Models Framework 從 WWDC25 到 WWDC26 的主要差異，並補上對目前 Demo 專案的實作建議。

參考影片：

- [WWDC26 - What's new in the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2026/241/)
- [WWDC26 - Build with the new Apple Foundation Model on Private Cloud Compute](https://developer.apple.com/videos/play/wwdc2026/319/)
- [WWDC26 - Meet the Evaluations framework](https://developer.apple.com/videos/play/wwdc2026/298/)

## WWDC25: 第一版 Foundation Models Framework

WWDC25 的 Foundation Models Framework 主要目標是讓 app 可以直接使用 Apple Intelligence 的 on-device language model。

核心能力：

- 使用 `SystemLanguageModel`
- 使用 `LanguageModelSession` 對模型發 prompt
- 支援 structured output：`@Generable`
- 支援 `@Guide` 約束輸出格式與內容
- 支援自訂 `Tool`，讓模型呼叫 app 提供的功能
- 支援 streaming / snapshot streaming
- 私密、離線、無 server token 成本
- 需要檢查 `SystemLanguageModel.default.isAvailable`

典型使用方式：

```swift
import FoundationModels

let session = LanguageModelSession()
let response = try await session.respond(to: "請幫我規劃東京三日遊")
print(response.content)
```

一句話總結：WWDC25 是把 Apple 的本機 LLM 開放給 app 使用。

## WWDC26: 從本機 LLM API 變成模型整合層

WWDC26 把 Foundation Models 從「本機 LLM API」擴展成「統一的 model / tool / agent / evaluation layer」。

主要方向：

- 模型更多：新的 on-device model、PCC server model、第三方模型、open source local model
- 能力更強：vision、tool calling、reasoning、context / token 管理
- 更適合 agentic app：Dynamic Profiles、system tools、Evaluations、CLI / Python SDK

## 1. On-device Model 升級

今年的 `SystemLanguageModel` 重新訓練，Apple 提到整體能力更好：

- 更好的邏輯能力
- 更好的 instruction following
- 更好的 tool calling
- guardrails 誤判更少
- 支援 image input
- 可查 context size
- 可計算 token count

```swift
let model = SystemLanguageModel()
print(model.contextSize)

let count = try await model.tokenCount(for: "What is origami?")
```

這讓 app 可以根據不同裝置的 context size / token 數，調整 prompt 長度、資料切分與 fallback 策略。

## 2. 支援圖片輸入

WWDC26 開始可以把圖片直接放進 prompt：

```swift
let response = try await session.respond {
    "這張圖片裡有什麼？"
    Attachment(UIImage(...))
}
```

支援來源：

- `UIImage`
- `NSImage`
- `CGImage`
- Core Image types
- CoreVideo pixel buffer
- file URL

圖片不用裁切成固定比例，但越大的圖片會消耗更多 tokens，也會增加 latency。

## 3. 新增 PrivateCloudComputeLanguageModel

今年新增跑在 Apple Private Cloud Compute 上的 server model：

```swift
let session = LanguageModelSession(
    model: PrivateCloudComputeLanguageModel()
)
```

特色：

- 32K context window
- 支援 reasoning
- 可設定 `.light`、`.moderate`、`.deep`
- 不需要 API key
- 不需要開發者自己處理 server auth
- 開發者沒有 token billing
- 使用者有每日 quota
- iCloud+ 使用者有較高 quota
- 需要 entitlement / 申請
- 支援 watchOS 27

reasoning 範例：

```swift
let response = try await session.respond(
    to: prompt,
    contextOptions: ContextOptions(reasoningLevel: .deep)
)
```

注意事項：

- PCC 需要 Apple Intelligence 可用裝置
- PCC 需要網路
- PCC 需要 entitlement
- PCC 有 daily per-user quota
- 若沒有申請權限，`PrivateCloudComputeLanguageModel().isAvailable` 可能會是 `false`

## 4. 新增 LanguageModel Protocol

WWDC26 架構上新增 `LanguageModel` protocol。`SystemLanguageModel` 和 `PrivateCloudComputeLanguageModel` 都符合這個 protocol。

意義是：`LanguageModelSession` 不再只綁 Apple 本機模型，也可以接：

- PCC model
- 第三方 server model
- open source local model
- 自己實作的 model provider

概念上變成：

```swift
let model: some LanguageModel = SystemLanguageModel.default
let session = LanguageModelSession(model: model)
```

## 5. 第三方模型與 Open Source Local Model

Apple 提到 Anthropic、Google 會提供 Swift packages，讓第三方 frontier models 也可以接進 Foundation Models 的同一套 session API。

Apple 也會 open source：

- `CoreAILanguageModel`
- `MLXLanguageModel`

這代表 Foundation Models 會變成一個統一 Swift API，背後可以換不同模型。

使用第三方 server model 時要注意：

- 通常需要 authentication
- 通常會有 token billing
- 不應該把 private key 放進 app binary
- 建議用 OAuth 或安全 token flow
- token 要存進 Keychain

## 6. 新增 Usage API

WWDC26 可以檢查 token 使用量：

```swift
print(response.usage.input.totalTokenCount)
print(response.usage.input.cachedTokenCount)

print(response.usage.output.totalTokenCount)
print(response.usage.output.reasoningTokenCount)
```

這對以下情境很重要：

- 第三方模型成本估算
- PCC reasoning token 觀察
- prompt 優化
- context cache 效益分析
- 評估不同 model / reasoning level 的成本差異

## 7. 新增內建 System Tools

WWDC26 新增 Apple 提供的 tools：

- `BarcodeReaderTool`
- `OCRTool`
- Spotlight-powered search tool

其中 Spotlight search tool 可用來做 local RAG，讓模型查詢本機 Spotlight index，取得 app 或使用者本地資料。

這代表 Foundation Models 不只是「產文字」，也逐漸能透過系統工具理解圖片、讀文字、查本地知識。

## 8. Dynamic Profiles

Dynamic Profiles 是 WWDC26 針對 agentic app 的重要 API。

以前如果要根據不同任務切換 model、instructions、tools，通常需要手動：

- 重建 `LanguageModelSession`
- 搬移 transcript
- 替換 instructions
- 替換 tools
- 管理模式狀態

Dynamic Profiles 讓這件事變成宣告式描述。

範例概念：

```swift
struct CraftProfile: LanguageModelSession.DynamicProfile {
    let states: CraftProjectStates

    var body: some DynamicProfile {
        switch states.mode {
        case .craftAnalysis:
            Profile {
                Instructions { "Analyze the craft image." }
                RecordImageAnalysisTool()
                SwitchModeTool(states: states)
            }

        case .brainstorm:
            Profile {
                Instructions { "Brainstorm project ideas." }
                BrainstormRecordTool()
            }
            .model(PrivateCloudComputeLanguageModel())
            .reasoningLevel(.deep)
        }
    }
}
```

用途：

- 同一個 session 依 app 狀態切換 active profile
- 不同任務可使用不同 model
- 不同任務可使用不同 tools
- 不同任務可使用不同 reasoning level
- 保留 conversation history

## 9. Evaluations Framework

WWDC26 新增 `Evaluations` framework，用來量測 AI feature 品質。

用途：

- 比較 prompt 改動是否真的變好
- 比較 `SystemLanguageModel` vs PCC
- 用 dataset 跑大量 sample
- 定義 quantitative metrics
- 用 `ModelJudgeEvaluator` 做 qualitative evaluation
- 產生 Xcode evaluation report

基本流程：

1. 定義要評估的 subject
2. 建立 dataset，例如 `ModelSample`
3. 定義 `Metric` 和 `Evaluator`
4. 定義 aggregate metrics
5. 用 Swift Testing 跑 evaluation

範例概念：

```swift
@Test("Book Tag Evaluations", .evaluates(evaluation, info: evaluationInfo))
func evaluateBookTagging() async throws {
    let result = EvaluationContext.current.result
    #expect(result.aggregateValue(.mean(of: rangeMetric)) >= 0.8)
}
```

### Quantitative Metrics

可以用程式判斷的指標：

- output 數量是否在範圍內
- response 長度
- tag 是否包含空白
- JSON / `@Generable` output 是否符合 schema
- tool call 次數是否合理

### Qualitative Metrics

只能用語意描述的指標：

- 是否相關
- 是否有幫助
- 是否忠於原文
- 是否適合使用者情境
- 是否安全、禮貌、可執行

這類指標可以用 `ModelJudgeEvaluator`。

影片中特別提到：judge model 應該至少跟被評估的模型一樣強，所以可以用 PCC 當 judge 來評估 on-device model 的輸出。

## 10. fm CLI 與 Python SDK

macOS 27 新增 `fm` CLI，可以在 terminal 使用 on-device model 和 PCC。

用途：

- `fm chat` 快速測 prompt
- shell script 摘要文件
- 抽取資訊
- 根據圖片內容產生檔名
- 快速測 app feature prompt

另外也新增 Foundation Models Python SDK，方便資料科學、研究、automation workflow 使用。

Python 範例：

```python
import apple_fm_sdk as fm

model = fm.SystemLanguageModel()
is_available, reason = model.is_available()

if is_available:
    session = fm.LanguageModelSession(model=model)
    response = await session.respond(prompt="Hello!")
    print(response)
```

## 11. Open Source 與 Utilities Package

WWDC26 提到 Foundation Models framework core 會 open source，也會有 Foundation Models framework utilities package。

Utilities package 包含：

- transcript management profile modifiers
- skill API
- Chat Completions standard server interface
- 可在 OS release 之間更新的 experimental building blocks

整體方向是讓 Foundation Models 成為 Swift ecosystem 裡的統一 LLM integration layer。

## 差異總表

| 面向 | WWDC25 | WWDC26 |
| --- | --- | --- |
| 模型 | 主要是 `SystemLanguageModel` | System + PCC + 第三方 + local open source |
| 執行位置 | On-device | On-device、PCC、第三方 server、local custom model |
| 輸入 | Text 為主 | Text + image |
| Structured output | `@Generable`, `@Guide` | 延續並強化 |
| Tool calling | 自訂 `Tool` | 更強 tool calling + 內建 system tools |
| Context / token | 較少 diagnostics | `contextSize`, `tokenCount`, `usage` |
| Agentic app | 手動管理 session/context | Dynamic Profiles |
| 評估 | 靠人工測試 / unit test 不足 | Evaluations Framework |
| 隱私 | 本機、離線 | 本機 + PCC privacy model |
| 成本 | 無 server cost | System 無 cost，PCC 無開發者 token cost，第三方模型另計 |
| watchOS | 不支援本機模型 | PCC 可支援 watchOS 27 |

## 對目前 Demo 專案的建議

目前這個專案是 WWDC25 Foundation Models Demo。若要升級到 WWDC26，可以依序補上：

1. Availability diagnostics
   - 顯示 `SystemLanguageModel` availability
   - 顯示 `PrivateCloudComputeLanguageModel` availability
   - 若 PCC unavailable，顯示 fallback 狀態

2. Token / context diagnostics
   - 顯示 `contextSize`
   - 對 prompt 做 `tokenCount`
   - 顯示 response `usage`

3. Image input demo
   - 使用 `Attachment(UIImage(...))`
   - 展示本機模型 image understanding

4. PCC fallback path
   - 先寫好 PCC path
   - 實際不可用時 fallback 到 `SystemLanguageModel`
   - 等之後有 entitlement 再啟用

5. Dynamic Profiles demo
   - 例如圖片分析用 System model
   - 生成創意建議用 PCC deep reasoning
   - 若 PCC unavailable，改用 System fallback

6. Evaluations target
   - 建一批固定 prompts
   - 評估不同 prompt / `@Guide` / tools 設計
   - 未來有 PCC 後再比較 System vs PCC

## 現階段 PCC 限制

目前如果開發者帳號底下沒有任何 app，會無法申請 PCC model entitlement。這代表：

- 可以寫 PCC API code
- 可以做 availability check
- 可以做 fallback UI
- 但不能保證 `PrivateCloudComputeLanguageModel().isAvailable == true`
- 也不能真正送 PCC request

因此短期最實際做法是：

- 先完成 WWDC26-compatible on-device demo
- PCC 只做 diagnostics + fallback
- 等未來有正式 app / entitlement 後，再補 PCC reasoning 和 quota UX

## 一句話總結

WWDC25 是 Foundation Models 的第一版 on-device LLM API；WWDC26 則把它擴展成完整的模型抽象、PCC、圖片、多工具、agentic workflow、evaluation 與開發工具生態系。
