//
//  SystemToolMode.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2026/7/8.
//

import FoundationModels

// OCRTool / BarcodeReaderTool 是 WWDC26 新增的 Vision + Foundation Models system tools。
// 目前 Xcode 27 beta 的 iPhoneSimulator SDK 沒有提供這個 module，因此要用 canImport
// 讓 simulator 仍可 build；實際 OCR / Barcode tool demo 需要在 iOS 27 真機上執行。
#if canImport(_Vision_FoundationModels)
import _Vision_FoundationModels
#endif

@available(iOS 27.0, *)
enum SystemToolMode: String, CaseIterable, Identifiable {
    case ocr
    case barcode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ocr: return "OCR"
        case .barcode: return "Barcode"
        }
    }

    var toolName: String {
        switch self {
        case .ocr: return "OCRTool"
        case .barcode: return "BarcodeReaderTool"
        }
    }

    var systemImage: String {
        switch self {
        case .ocr: return "text.viewfinder"
        case .barcode: return "barcode.viewfinder"
        }
    }

    var emptyStateImage: String {
        switch self {
        case .ocr: return "doc.text.viewfinder"
        case .barcode: return "barcode.viewfinder"
        }
    }

    var emptyStateText: String {
        switch self {
        case .ocr: return "選擇含有文字的圖片"
        case .barcode: return "選擇含有條碼或 QR Code 的圖片"
        }
    }

    var promptPlaceholder: String {
        switch self {
        case .ocr: return "請輸入要如何處理圖片中的文字"
        case .barcode: return "請輸入要如何處理圖片中的條碼"
        }
    }

    var samplePrompt: String {
        switch self {
        case .ocr:
            return "請摘要圖片文字，最多 5 點。"
        case .barcode:
            return "只列出條碼原始內容。"
        }
    }

    var buttonTitle: String {
        switch self {
        case .ocr: return "執行 OCR"
        case .barcode: return "讀取 Barcode"
        }
    }

    func instructions(imageLabel: String) -> String {
        // instructions 明確要求模型使用對應 tool，搭配 toolCallingMode: .required
        // 可以降低模型只憑圖片理解直接回答、沒有真的呼叫 tool 的機率。
        let sharedInstruction = "圖片 label 是 \(imageLabel)，呼叫工具只能使用此 label。"

        switch self {
        case .ocr:
            return "\(sharedInstruction) 使用 OCRTool。用繁體中文簡短回答，不逐字重抄全文。"
        case .barcode:
            return "\(sharedInstruction) 使用 BarcodeReaderTool。只列出原始內容與格式，不開啟連結、不判斷安全性。"
        }
    }

    func requestInstruction(imageLabel: String) -> String {
        switch self {
        case .ocr:
            return "使用 OCRTool 讀取 label \(imageLabel)，簡短摘要。"
        case .barcode:
            return "使用 BarcodeReaderTool 讀取 label \(imageLabel)，只列原始內容。"
        }
    }

    var tools: [any Tool] {
#if canImport(_Vision_FoundationModels)
        // 真機 iPhoneOS SDK 才會編到這段，並建立 Apple 提供的 system tool。
        switch self {
        case .ocr:
            return [OCRTool()]
        case .barcode:
            return [BarcodeReaderTool()]
        }
#else
        // Simulator 不提供 system tool module，回傳空陣列讓 UI 可以保留但不執行工具。
        return []
#endif
    }

    var isAvailableInCurrentSDK: Bool {
#if canImport(_Vision_FoundationModels)
        return true
#else
        return false
#endif
    }
}
