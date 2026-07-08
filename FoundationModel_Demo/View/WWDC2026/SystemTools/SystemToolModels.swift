//
//  SystemToolModels.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2026/7/8.
//

import Foundation
import FoundationModels

@available(iOS 27.0, *)
struct SystemToolTokenUsageSummary {
    let inputTokenCount: Int
    let cachedInputTokenCount: Int
    let outputTokenCount: Int
    let reasoningTokenCount: Int
    let totalTokenCount: Int

    init(usage: LanguageModelSession.Usage) {
        inputTokenCount = usage.input.totalTokenCount
        cachedInputTokenCount = usage.input.cachedTokenCount
        outputTokenCount = usage.output.totalTokenCount
        reasoningTokenCount = usage.output.reasoningTokenCount
        totalTokenCount = usage.totalTokenCount
    }
}

@available(iOS 27.0, *)
struct SystemToolResult {
    let content: String
    let toolEvents: [String]
    let tokenUsage: SystemToolTokenUsageSummary
}

@available(iOS 27.0, *)
enum SystemToolRequestStage {
    case idle
    case starting
    case validatingModel
    case creatingSession
    case preparingAttachment
    case waitingForModel
    case processingTranscript
    case completed
    case failed

    var title: String {
        switch self {
        case .idle:
            return "尚未開始"
        case .starting:
            return "準備請求"
        case .validatingModel:
            return "檢查模型狀態"
        case .creatingSession:
            return "建立 Session"
        case .preparingAttachment:
            return "準備圖片附件"
        case .waitingForModel:
            return "等待模型與工具回應"
        case .processingTranscript:
            return "整理工具紀錄"
        case .completed:
            return "完成"
        case .failed:
            return "失敗"
        }
    }

    var detail: String {
        switch self {
        case .idle:
            return "送出後會顯示目前執行階段。"
        case .starting:
            return "清空上一筆結果並開始計時。"
        case .validatingModel:
            return "確認 SystemLanguageModel 目前可用。"
        case .creatingSession:
            return "將 OCRTool / BarcodeReaderTool 注入 LanguageModelSession。"
        case .preparingAttachment:
            return "正在建立圖片 attachment，並套用固定 label。"
        case .waitingForModel:
            return "已呼叫 session.respond；若卡很久，通常是模型、system tool 或底層 ModelManagerServices 尚未回傳。"
        case .processingTranscript:
            return "session.respond 已回傳，正在整理 response、tool calls 與 usage。"
        case .completed:
            return "請求已完成。"
        case .failed:
            return "請求失敗，請查看錯誤訊息。"
        }
    }
}

@available(iOS 27.0, *)
enum SystemToolsDemoError: LocalizedError {
    case missingImage
    case invalidImageData
    case modelUnavailable(SystemLanguageModel.Availability.UnavailableReason)
    case systemToolsUnavailable

    var errorDescription: String? {
        switch self {
        case .missingImage:
            return "請先選擇一張圖片。"
        case .invalidImageData:
            return "無法讀取這張圖片，請換一張再試。"
        case .modelUnavailable(let reason):
            return "Model is unavailable: \(String(describing: reason))"
        case .systemToolsUnavailable:
            return "這個 SDK 目前沒有提供 Vision Foundation Models system tools。請改用 iOS 27 真機執行。"
        }
    }
}
