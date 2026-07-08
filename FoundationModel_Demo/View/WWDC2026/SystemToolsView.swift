//
//  SystemToolsView.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2026/7/7.
//

import Foundation
import FoundationModels
import PhotosUI
import SwiftUI
import UIKit

@available(iOS 27.0, *)
struct SystemToolsView: View {
    @FocusState private var isPromptFocused: Bool

    // selectedTool 決定這次 session 要注入哪一個 system tool。
    // selectedPhotoItem 是 PhotosPicker 回傳的項目，selectedImage 則是轉成 UIImage 後送給 Attachment。
    @State private var selectedTool: SystemToolMode = .ocr
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var prompt = SystemToolMode.ocr.samplePrompt

    // 這些 state 都只代表「單次請求」的畫面結果；
    // 使用者換圖片或換工具時會清空，避免舊結果被誤認成新圖片的分析。
    @State private var responseText = ""
    @State private var toolEvents: [String] = []
    @State private var tokenUsage: SystemToolTokenUsageSummary?
    @State private var isLoadingImage = false
    @State private var isGenerating = false
    @State private var isDiagnosticsExpanded = false
    @State private var errorMessage: String?
    @State private var requestStage: SystemToolRequestStage = .idle
    @State private var requestStageEvents: [String] = []
    @State private var requestStartedAt: Date?
    @State private var elapsedSeconds = 0
    @State private var directOCRResult = ""
    @State private var directOCRError: String?
    @State private var isReadingOCRDirectly = false
    @State private var directQRCodeResult = ""
    @State private var directQRCodeError: String?
    @State private var isReadingQRCodeDirectly = false

    private let model = SystemLanguageModel.default
    private let imageAttachmentLabel = "inputImage"

    // ScrollViewReader 需要穩定的 id，模型回應完成後會捲到結果區。
    private enum ScrollTarget {
        case response
    }

    var body: some View {
        // 這個頁面有圖片、prompt、診斷、usage、response，多數小螢幕會需要捲動。
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    toolPicker
                    imagePickerArea
                    promptArea
                    directOCRArea
                    directQRCodeArea
                    diagnosticArea
                    statusArea
                    usageArea
                    toolEventsArea
                    responseArea
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture { isPromptFocused = false }
            .navigationTitle("System Tools")
            .onChange(of: selectedTool) { _, newTool in
                // 切換 OCR / Barcode 時換成對應範例 prompt，並清掉上一個工具的結果。
                prompt = newTool.samplePrompt
                clearResult()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                loadImage(from: newItem)
            }
            .task(id: isGenerating) {
                guard !isGenerating, !responseText.isEmpty else { return }
                await scrollToResponse(using: proxy)
            }
            .task(id: isGenerating) {
                await updateElapsedTimeWhileGenerating()
            }
        }
    }

    @MainActor
    private func scrollToResponse(using proxy: ScrollViewProxy) async {
        // responseArea 需要等 isGenerating=false 後才會被插入畫面；
        // 稍微延後可以確保 transition/layout 完成後 ScrollViewReader 找得到目標 id。
        try? await Task.sleep(for: .milliseconds(300))

        guard !isGenerating, !responseText.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(ScrollTarget.response, anchor: .top)
        }
    }

    private var toolPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("工具")
                .font(.headline)

            Picker("工具", selection: $selectedTool) {
                ForEach(SystemToolMode.allCases) { tool in
                    Label(tool.title, systemImage: tool.systemImage)
                        .tag(tool)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var imagePickerArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("圖片")
                .font(.headline)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))

                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: selectedTool.emptyStateImage)
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)

                        Text(selectedTool.emptyStateText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if isLoadingImage {
                    ProgressView()
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label(selectedImage == nil ? "選擇圖片" : "更換圖片", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(isGenerating || isLoadingImage)
        }
    }

    @ViewBuilder
    private var promptArea: some View {
        // 先檢查 on-device model availability；模型不可用時不要讓使用者送出。
        switch model.availability {
        case .available:
            if selectedTool.isAvailableInCurrentSDK {
                PromptField(title: selectedTool.promptPlaceholder, text: $prompt, isFocused: $isPromptFocused)
                    .focused($isPromptFocused)

                Button(action: submit) {
                    Label(selectedTool.buttonTitle, systemImage: "wand.and.sparkles")
                        .font(.title3)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(isSubmitDisabled)
                .opacity(isSubmitDisabled ? 0.6 : 1)
            } else {
                // Simulator SDK 沒有 _Vision_FoundationModels，所以 demo 保留入口但明確提示限制。
                Text("OCR / Barcode system tools 目前不在 iPhoneSimulator SDK 內，請用 iOS 27 真機執行。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .unavailable(let reason):
            Text("Model is unavailable: \(String(describing: reason))")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var diagnosticArea: some View {
        // 診斷資訊預設收合，避免佔掉主要操作區；需要排查時再展開。
        DisclosureGroup(isExpanded: $isDiagnosticsExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                diagnosticRow("模型狀態", String(describing: model.availability))
                diagnosticRow("模型可用", model.isAvailable ? "是" : "否")
                diagnosticRow("支援圖片輸入", model.capabilities.contains(.vision) ? "是" : "否")
                diagnosticRow("目前工具", selectedTool.toolName)
                diagnosticRow("工具 SDK", selectedTool.isAvailableInCurrentSDK ? "可用" : "Simulator 不可用")
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "stethoscope")
                    .foregroundStyle(.secondary)

                Text("診斷資訊")
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 8)

                Text(diagnosticSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var diagnosticSummary: String {
        let availabilityText = model.isAvailable ? "模型可用" : "模型不可用"
        return "\(availabilityText) · \(selectedTool.toolName)"
    }

    private func diagnosticRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private var directOCRArea: some View {
        if selectedTool == .ocr {
            VStack(alignment: .leading, spacing: 10) {
                Button(action: readOCRDirectly) {
                    if isReadingOCRDirectly {
                        Label("Vision OCR 讀取中…", systemImage: "text.viewfinder")
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("只用 Vision OCR", systemImage: "text.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(selectedImage == nil || isGenerating || isLoadingImage || isReadingOCRDirectly)
                .opacity(selectedImage == nil || isGenerating || isLoadingImage || isReadingOCRDirectly ? 0.6 : 1)

                if isReadingOCRDirectly {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if !directOCRResult.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Vision OCR 結果")
                            .font(.subheadline.weight(.semibold))

                        Text(directOCRResult)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }

                if let directOCRError {
                    Text(directOCRError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private var directQRCodeArea: some View {
        if selectedTool == .barcode {
            VStack(alignment: .leading, spacing: 10) {
                Button(action: readQRCodeDirectly) {
                    if isReadingQRCodeDirectly {
                        Label("Vision 讀取中…", systemImage: "qrcode.viewfinder")
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("只用 Vision 讀 QR Code", systemImage: "qrcode.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(selectedImage == nil || isGenerating || isLoadingImage || isReadingQRCodeDirectly)
                .opacity(selectedImage == nil || isGenerating || isLoadingImage || isReadingQRCodeDirectly ? 0.6 : 1)

                if isReadingQRCodeDirectly {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if !directQRCodeResult.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Vision QR Code 結果")
                            .font(.subheadline.weight(.semibold))

                        Text(directQRCodeResult)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }

                if let directQRCodeError {
                    Text(directQRCodeError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private var statusArea: some View {
        if isGenerating {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ProgressView()

                    VStack(alignment: .leading, spacing: 2) {
                        Text(requestStage.title)
                            .font(.subheadline.weight(.semibold))

                        Text(requestStage.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Text("\(elapsedSeconds)s")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if !requestStageEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(requestStageEvents.enumerated()), id: \.offset) { _, event in
                            Text(event)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .transition(.opacity)
        }

        if let errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var usageArea: some View {
        // Usage API 回傳的是這次 response 的 token 統計，適合用來比較 OCR / Barcode 成本。
        if let tokenUsage, !isGenerating {
            VStack(alignment: .leading, spacing: 10) {
                Text("Token 使用量")
                    .font(.headline)

                VStack(spacing: 6) {
                    usageRow("Input", tokenUsage.inputTokenCount)
                    usageRow("Cached input", tokenUsage.cachedInputTokenCount)
                    usageRow("Output", tokenUsage.outputTokenCount)
                    usageRow("Reasoning output", tokenUsage.reasoningTokenCount)
                    Divider()
                    usageRow("Total", tokenUsage.totalTokenCount, isEmphasized: true)
                }
                .font(.footnote)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private var toolEventsArea: some View {
        // transcriptEntries 會包含 tool call / tool output，這裡整理成 demo 可讀的呼叫紀錄。
        if !toolEvents.isEmpty && !isGenerating {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tool 呼叫紀錄")
                    .font(.headline)

                ForEach(Array(toolEvents.enumerated()), id: \.offset) { _, event in
                    Label(event, systemImage: "checkmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .transition(.opacity)
        }
    }

    private func usageRow(_ title: String, _ count: Int, isEmphasized: Bool = false) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(isEmphasized ? .primary : .secondary)
            Spacer()
            Text(count.formatted())
                .fontWeight(isEmphasized ? .semibold : .regular)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var responseArea: some View {
        if !responseText.isEmpty && !isGenerating {
            ScrollView {
                Text(responseText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .id(ScrollTarget.response)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private var isSubmitDisabled: Bool {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        selectedImage == nil ||
        isGenerating ||
        isLoadingImage
    }

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            // 選到新圖片時清掉舊輸出，避免舊回應留在新圖片底下。
            await MainActor.run {
                isLoadingImage = true
                clearResult()
            }

            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    throw SystemToolsDemoError.invalidImageData
                }

                // 大圖會增加 Vision tool 和模型處理成本；demo 先縮到合理尺寸。
                let preparedImage = image.preparedForSystemTools(maxPixelLength: 1_280)
                await MainActor.run {
                    selectedImage = preparedImage
                    isLoadingImage = false
                }
            } catch {
                await MainActor.run {
                    selectedImage = nil
                    errorMessage = "圖片載入失敗：\(error.localizedDescription)"
                    isLoadingImage = false
                }
            }
        }
    }

    private func submit() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let selectedImage else {
            errorMessage = SystemToolsDemoError.missingImage.localizedDescription
            return
        }

        Task {
            prepareForRequest()

            do {
                let runner = SystemToolSessionRunner(model: model, imageAttachmentLabel: imageAttachmentLabel)
                let result = try await runner.generateResponse(
                    for: trimmed,
                    image: selectedImage,
                    selectedTool: selectedTool
                ) { stage in
                    await setRequestStage(stage)
                }
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        updateRequestStage(.completed)
                        responseText = result.content
                        toolEvents = result.toolEvents
                        tokenUsage = result.tokenUsage
                        isGenerating = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        updateRequestStage(.failed)
                        errorMessage = SystemToolErrorFormatter.message(for: error)
                        print("發生錯誤：\(error.localizedDescription)")
                        isGenerating = false
                    }
                }
            }
        }
    }

    @MainActor
    private func prepareForRequest() {
        // 所有 UI state 更新集中在 MainActor，避免 async request 回來時更新 SwiftUI 狀態出現競態。
        isPromptFocused = false
        requestStartedAt = Date()
        elapsedSeconds = 0
        requestStageEvents = []
        withAnimation(.easeInOut(duration: 0.2)) {
            isGenerating = true
            updateRequestStage(.starting)
            responseText = ""
            toolEvents = []
            tokenUsage = nil
            errorMessage = nil
        }
    }

    @MainActor
    private func clearResult() {
        responseText = ""
        toolEvents = []
        tokenUsage = nil
        errorMessage = nil
        directOCRResult = ""
        directOCRError = nil
        isReadingOCRDirectly = false
        directQRCodeResult = ""
        directQRCodeError = nil
        isReadingQRCodeDirectly = false
        requestStage = .idle
        requestStageEvents = []
        requestStartedAt = nil
        elapsedSeconds = 0
    }

    private func readOCRDirectly() {
        guard let selectedImage else {
            directOCRError = SystemToolsDemoError.missingImage.localizedDescription
            return
        }

        Task {
            await MainActor.run {
                directOCRResult = ""
                directOCRError = nil
                isReadingOCRDirectly = true
            }

            do {
                let result = try DirectTextRecognizer.recognizeText(in: selectedImage)
                await MainActor.run {
                    directOCRResult = result
                    isReadingOCRDirectly = false
                }
            } catch {
                await MainActor.run {
                    directOCRError = "Vision OCR 讀取失敗：\(error.localizedDescription)"
                    isReadingOCRDirectly = false
                }
            }
        }
    }

    private func readQRCodeDirectly() {
        guard let selectedImage else {
            directQRCodeError = SystemToolsDemoError.missingImage.localizedDescription
            return
        }

        Task {
            await MainActor.run {
                directQRCodeResult = ""
                directQRCodeError = nil
                isReadingQRCodeDirectly = true
            }

            do {
                let result = try DirectQRCodeReader.readPayloads(in: selectedImage)
                await MainActor.run {
                    directQRCodeResult = result
                    isReadingQRCodeDirectly = false
                }
            } catch {
                await MainActor.run {
                    directQRCodeError = "Vision QR Code 讀取失敗：\(error.localizedDescription)"
                    isReadingQRCodeDirectly = false
                }
            }
        }
    }

    @MainActor
    private func updateRequestStage(_ stage: SystemToolRequestStage) {
        requestStage = stage
        requestStageEvents.append(stageEventText(for: stage))
    }

    private func setRequestStage(_ stage: SystemToolRequestStage) async {
        await MainActor.run {
            updateRequestStage(stage)
        }
    }

    private func stageEventText(for stage: SystemToolRequestStage) -> String {
        let elapsed = requestStartedAt.map { Int(Date().timeIntervalSince($0)) } ?? 0
        return "+\(elapsed)s \(stage.title)"
    }

    @MainActor
    private func updateElapsedTimeWhileGenerating() async {
        guard isGenerating else { return }

        while !Task.isCancelled, isGenerating {
            if let requestStartedAt {
                elapsedSeconds = Int(Date().timeIntervalSince(requestStartedAt))
            }

            try? await Task.sleep(for: .seconds(1))
        }
    }
}

@available(iOS 27.0, *)
#Preview {
    NavigationStack {
        SystemToolsView()
    }
}
