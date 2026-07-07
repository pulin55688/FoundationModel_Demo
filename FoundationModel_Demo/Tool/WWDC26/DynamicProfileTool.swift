//
//  DynamicProfileTool.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2026/7/7.
//

import FoundationModels

// Demo 會用這個 enum 代表目前 AI session 的工作模式。
// DynamicProfileTool 會根據 mode 切換 instructions、tools、model 與生成參數。
@available(iOS 27.0, *)
enum AIMode: String, CaseIterable, Identifiable {
    case chat
    case travel
    case weather
    case pet
    case deepPlanning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: return "自由對話"
        case .travel: return "旅遊規劃"
        case .weather: return "天氣查詢"
        case .pet: return "寵物生成"
        case .deepPlanning: return "深度規劃"
        }
    }

    var promptPlaceholder: String {
        switch self {
        case .chat: return "請輸入問題"
        case .travel: return "請輸入國家或城市"
        case .weather: return "請輸入城市"
        case .pet: return "請輸入寵物類型"
        case .deepPlanning: return "請輸入需要規劃的任務"
        }
    }

    var samplePrompt: String {
        switch self {
        case .chat: return "用三句話說明 Foundation Models Framework"
        case .travel: return "日本"
        case .weather: return "台北"
        case .pet: return "貓咪"
        case .deepPlanning: return "規劃一個三天的 SwiftUI 學習計畫"
        }
    }

    var systemImage: String {
        switch self {
        case .chat: return "message.fill"
        case .travel: return "airplane.departure"
        case .weather: return "cloud.sun.fill"
        case .pet: return "pawprint.fill"
        case .deepPlanning: return "brain.head.profile"
        }
    }
}

@available(iOS 27.0, *)
struct DynamicProfileTool: LanguageModelSession.DynamicProfile {
    let mode: AIMode
    
    // Dynamic Profile 的重點：
    // 同一個 LanguageModelSession 可以依照 app 狀態啟用不同 Profile。
    // 每個 Profile 可以宣告自己的 Instructions、Tools、Model 與 generation options。
    var body: some LanguageModelSession.DynamicProfile {
        switch mode {
        case .chat:
            // 一般聊天模式：只有基礎 instructions，不注入工具，也不改 generation options。
            Profile {
                Instructions {
                    "你是繁體中文 AI 助手，回答要清楚、簡短。"
                }
            }

        case .travel:
            // 旅遊模式：提高一點 temperature，讓建議不要每次都太固定。
            // maximumResponseTokens 限制輸出長度，避免建議清單無限制延伸。
            Profile {
                Instructions {
                    "你是旅遊規劃助手，請提供實用、可執行的旅遊建議。"
                }
            }
            // .temperature 設定模型生成文字時的「隨機程度 / 創意程度」
            // 0 或很低：回答更穩定、保守、可預測
            // 0.7：有一點變化，適合聊天、旅遊建議、創意內容
            // 1.0 以上：更發散、更有創意，但也更容易不穩或離題
            .temperature(0.7)
            .maximumResponseTokens(800)

        case .weather:
            // 天氣模式：把 WeatherTool 放進 Profile。
            // 當 prompt 需要查天氣時，模型可以決定呼叫這個 tool 取得資料。
            Profile {
                Instructions {
                    "你是天氣查詢助手。需要天氣資料時必須使用工具。"
                }
                [WeatherTool()]
            }

        case .pet:
            // 寵物模式：主要靠 instructions 搭配 View 端的 generating: PetProfile.self，
            // 讓模型輸出符合 @Generable schema 的結構化資料。
            Profile {
                Instructions {
                    "你會產生可愛但合理的寵物資料，內容使用繁體中文。"
                }
            }

        case .deepPlanning:
            // 深度規劃模式：目前固定使用 on-device SystemLanguageModel。
            // PrivateCloudComputeLanguageModel 需要 entitlement；沒有申請時連初始化都可能造成 runtime 問題。
            // 之後拿到 PCC entitlement 後，可再改成：
            //
            // let pccModel = PrivateCloudComputeLanguageModel()
            // Profile { ... }
            //     .model(pccModel.isAvailable ? pccModel : SystemLanguageModel.default)
            //     .reasoningLevel(pccModel.isAvailable ? .deep : nil)
            Profile {
                Instructions {
                    "你是擅長複雜規劃的助手，請先分析限制再給出建議。"
                }
            }
            .model(SystemLanguageModel.default)
            .maximumResponseTokens(1_200)
        }
    }
}
