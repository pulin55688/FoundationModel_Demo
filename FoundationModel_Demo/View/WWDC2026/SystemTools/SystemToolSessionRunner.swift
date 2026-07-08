//
//  SystemToolSessionRunner.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2026/7/8.
//

import FoundationModels
import UIKit

@available(iOS 27.0, *)
struct SystemToolSessionRunner {
    let model: SystemLanguageModel
    let imageAttachmentLabel: String

    func generateResponse(
        for prompt: String,
        image: UIImage,
        selectedTool: SystemToolMode,
        onStageChanged: @escaping (SystemToolRequestStage) async -> Void
    ) async throws -> SystemToolResult {
        await onStageChanged(.validatingModel)

        // System tools 仍然透過 LanguageModelSession 執行，因此要先確認 Foundation Model 可用。
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw SystemToolsDemoError.modelUnavailable(reason)
        }

#if canImport(_Vision_FoundationModels)
        await onStageChanged(.creatingSession)

        // 這裡是 system tools 的核心使用點：
        // 將 OCRTool / BarcodeReaderTool 放進 session tools，模型就能在需要時呼叫它。
        let session = LanguageModelSession(
            model: model,
            tools: selectedTool.tools,
            instructions: selectedTool.instructions(imageLabel: imageAttachmentLabel)
        )

        await onStageChanged(.preparingAttachment)

        guard let cgImage = image.cgImage else {
            throw SystemToolsDemoError.invalidImageData
        }

        // toolCallingMode: .required 讓模型必須嘗試呼叫工具，demo 結果比較明確。
        // prompt builder 裡同時放文字要求與 Attachment(cgImage)，tool 可從附件圖片取得輸入。
        // 這裡改用 CGImage 建立 attachment，避開 Xcode 27 beta 2 在 UIImage attachment 加 label 時的 crash。
        // 這裡一定要給固定 label；OCRTool / BarcodeReaderTool 會用 label 到 transcript 找圖片。
        await onStageChanged(.waitingForModel)

        let response = try await session.respond(
            options: GenerationOptions(toolCallingMode: .required)
        ) {
            selectedTool.requestInstruction(imageLabel: imageAttachmentLabel)
            prompt
            Attachment(cgImage).label(imageAttachmentLabel)
        }

        await onStageChanged(.processingTranscript)

        return SystemToolResult(
            content: response.content,
            toolEvents: SystemToolTranscriptFormatter.makeToolEvents(from: response.transcriptEntries),
            tokenUsage: SystemToolTokenUsageSummary(usage: response.usage)
        )
#else
        // simulator 會走到這裡，因為目前 simulator SDK 沒有 _Vision_FoundationModels。
        throw SystemToolsDemoError.systemToolsUnavailable
#endif
    }
}
