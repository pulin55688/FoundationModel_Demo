//
//  SystemToolSupport.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2026/7/8.
//

import Foundation
import FoundationModels

@available(iOS 27.0, *)
enum SystemToolTranscriptFormatter {
    static func makeToolEvents(from entries: ArraySlice<Transcript.Entry>) -> [String] {
        // transcriptEntries 是模型本次回應新增的 transcript，
        // 可用來觀察模型實際有沒有呼叫 tool、以及 tool 是否有回傳 output。
        var events: [String] = []

        for entry in entries {
            switch entry {
            case .toolCalls(let calls):
                for call in calls {
                    events.append("呼叫 \(call.toolName)")
                }
            case .toolOutput(let output):
                events.append("收到 \(output.toolName) 輸出")
            default:
                break
            }
        }

        return events
    }
}

@available(iOS 27.0, *)
enum SystemToolErrorFormatter {
    static func message(for error: any Error) -> String {
        let rawMessage = error.localizedDescription
        let debugMessage = String(describing: error)
        let combinedMessage = "\(rawMessage)\n\(debugMessage)".lowercased()

        // Barcode 內容可能是網址、付款資訊、登入資訊或其他未知 payload。
        // 若 prompt 要求模型解釋用途或判斷內容，安全規則有機會在工具結果回來後擋下回答。
        if combinedMessage.contains("safety guardrails") || combinedMessage.contains("guardrail") {
            return """
            發生錯誤：模型安全規則擋下這次回應。

            Barcode / QR Code 內容可能包含網址、付款、登入或其他敏感資訊。這不是圖片 label 錯誤；請先改用「只列出原始內容」的 prompt，避免要求模型推測用途、開啟連結或判斷安全性。
            """
        }

        if combinedMessage.contains("maximum allowed") && combinedMessage.contains("tokens") {
            return """
            發生錯誤：這次請求超過模型 context token 上限。

            OCRTool 讀到的文字也會進入 session context；文字很多的圖片可能在模型摘要前就超過限制。可以先用「只用 Vision OCR」確認原文，或改用較短圖片、裁切圖片、分段處理。
            """
        }

        return "發生錯誤：\(rawMessage)"
    }
}
