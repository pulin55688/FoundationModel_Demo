# Foundation Models Framework: WWDC25 vs WWDC26

這份筆記整理 Foundation Models Framework 從 WWDC25 到 WWDC26 的主要差異，並補上對目前 Demo 專案的實作建議。

參考影片：

- [WWDC26 - What's new in the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2026/241/)
- [WWDC26 - Build with the new Apple Foundation Model on Private Cloud Compute](https://developer.apple.com/videos/play/wwdc2026/319/)
- [WWDC26 - Meet the Evaluations framework](https://developer.apple.com/videos/play/wwdc2026/298/)
- [WWDC26 - What's new in image understanding](https://developer.apple.com/videos/play/wwdc2026/237/)

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

### WWDC26 237: Image Understanding 重點

這支影片把 WWDC26 的 image understanding 分成兩條線：Vision framework 的傳統電腦視覺能力，以及 Foundation Models framework 的 LLM 圖片理解能力。

#### Foundation Models 圖片輸入

Foundation Models 今年可以直接把 image attachment 放進 prompt，適合做比較開放式、語意型的圖片任務：

- 產生圖片 caption
- 摘要圖片中的手寫或印刷資訊
- 根據照片生成 agenda / checklist
- 針對室內空間提出建議
- 根據冰箱照片產生食譜

概念範例：

```swift
let response = try await session.respond {
    "請描述這張圖片，並整理重點。"
    Attachment(image)
}
```

判斷使用 Foundation Models 或 Vision 的方式：

- Foundation Models：適合語意理解、開放式問題、整合圖片內容後產生自然語言。
- Vision：適合固定任務，例如 OCR、barcode、segmentation、pose、face、classification，通常速度更快，也更適合即時影像處理。
- 兩者可以一起用：Foundation Models 負責推理和組織回答，Vision tool 負責提供可靠的視覺辨識結果。

#### Image-based Tool Calling

WWDC26 的 tool calling 支援圖片參數。模型不會把整張圖片直接塞進 tool argument，而是傳遞 `ImageReference`，tool 再從 session transcript 解析出真正的 image attachment。

自訂圖片 tool 的核心流程：

1. Tool 的 arguments 使用 `ImageReference`
2. 在 tool 內透過 `@SessionProperty(\.history)` 取得 session history
3. 把 history 轉成 `Transcript`
4. 用 `imageReference.resolve(in: transcript)` 找回 image attachment
5. 把 attachment 轉成 `pixelBuffer` 或其他影像格式，再交給 Vision / Core ML / 自己的處理邏輯

概念範例：

```swift
struct PlantIdentifierTool: Tool {
    @SessionProperty(\.history) var history

    @Generable
    struct Arguments {
        var image: ImageReference
    }

    func call(arguments: Arguments) async throws -> String {
        let transcript = Transcript(history)

        guard let imageAttachment = arguments.image.resolve(in: transcript) else {
            throw AppError.imageNotFound
        }

        let pixelBuffer = try imageAttachment.pixelBuffer()
        return classifyPlant(pixelBuffer)
    }
}
```

這也解釋了目前 demo 裡 OCR / Barcode tool 為什麼一定要替圖片加上 label：

```swift
Attachment(image)
    .label("inputImage")
```

影片中特別提醒：要讓模型呼叫 image-based tool 時，attached image 應該加 label。這個 label 是模型辨識「要把哪張圖片交給 tool」的依據。如果沒有固定 label，模型可能會根據圖片內容自己猜一個 label，最後 tool 會在 transcript 裡找不到圖片。

#### Vision system tools

Vision 今年提供可直接接進 Foundation Models session 的 tools：

- `BarcodeReaderTool`
  - 適合 QR Code、barcode。
  - 範例場景是從活動海報擷取日期、地點，並用 barcode tool 讀出 QR Code 裡的報名網址。

- `OCRTool`
  - 適合細小、密集或模型本身不容易穩定讀出的文字。
  - 支援超過 30 種語言。

使用概念：

```swift
let session = LanguageModelSession(
    model: model,
    tools: [BarcodeReaderTool()]
)

let response = try await session.respond {
    "請讀取這張海報的日期、地點與報名網址。"
    Attachment(image)
        .label("flyer")
}
```

#### Vision tap-to-segment

Vision 新增 tap-to-segment API，可以用互動方式分割圖片中的任意物件，不再只限於人物 segmentation。

支援的選取方式：

- 點選物件中的一個點
- bounding box
- lasso
- scribble
- 用 included / excluded points 逐步修正 mask

實作重點：

- 使用 `ImageRequestHandler` 處理圖片。
- 使用 `GenerateIterativeSegmentationRequest` 產生 segmentation mask。
- Vision 座標系是 normalized coordinate，原點在左下角，x/y 介於 0 到 1。
- lasso 或 scribble 的 stroke width 不能太細，建議至少是圖片寬度的 1%。
- 第一次在裝置上執行前，可能需要先下載模型資源；可用 `downloadAssets` 觸發下載，並用 `assetStatus` 檢查是否 ready。

#### Vision on watchOS

Vision 今年也支援 watchOS。影片示範用 saliency analysis 找出圖片中最重要的主體，然後自動 crop，讓 watch 小螢幕可以顯示更清楚的主體畫面。

這跟 Foundation Models 沒有直接關係，但代表 Vision 的固定任務 API 可以在更多平台上使用。若 app 有 watchOS extension，可以用 Vision 做輕量圖片前處理，再把摘要或結果交給 Foundation Models / PCC 做語意層整理。

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

Image-based system tools 的實作注意事項：

- 要把 tool 放進 `LanguageModelSession(model:tools:instructions:)`。
- 若希望模型一定呼叫工具，可搭配 `GenerationOptions(toolCallingMode: .required)`。
- 圖片 attachment 建議固定 label，例如 `.label("inputImage")`。
- prompt / instructions 要明確告訴模型使用同一個 label，避免模型自己發明 label。
- `SystemLanguageModel.default` 可用，不代表 OCR / Barcode system tool 的底層模型資源一定 ready；system tool 仍可能因裝置、OS beta、模型資源尚未下載或不支援而失敗。
- 目前 simulator SDK 不一定包含 Vision + Foundation Models system tools，實測時應以 iOS 27 真機為主。

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

4. System tools demo
   - 使用 `OCRTool` 讀取產品圖片、票券、文件截圖中的文字
   - 使用 `BarcodeReaderTool` 讀取 QR Code / barcode
   - 圖片 attachment 固定 `.label("inputImage")`
   - UI 顯示 tool call transcript、token usage、錯誤診斷
   - 若 system tool 在裝置上不可用，顯示限制原因，而不是只顯示原始錯誤碼

5. Tap-to-segment / Vision demo
   - 可新增互動式圖片 segmentation 頁面
   - 展示 point、box、lasso、scribble 如何產生 mask
   - 補上 asset download / assetStatus 診斷
   - 這個 demo 屬於 Vision framework，但能跟 Foundation Models 圖片分析形成對照

6. PCC fallback path
   - 先寫好 PCC path
   - 實際不可用時 fallback 到 `SystemLanguageModel`
   - 等之後有 entitlement 再啟用

7. Dynamic Profiles demo
   - 例如圖片分析用 System model
   - 生成創意建議用 PCC deep reasoning
   - 若 PCC unavailable，改用 System fallback

8. Evaluations target
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
