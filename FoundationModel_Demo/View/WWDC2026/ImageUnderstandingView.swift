//
//  ImageUnderstandingView.swift
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
struct ImageUnderstandingView: View {
    @FocusState private var isPromptFocused: Bool

    // PhotosPickerItem 是系統照片選擇器回傳的暫存項目；
    // selectedImage 則是轉成 Foundation Models 可以吃的 UIImage。
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var prompt = "請用繁體中文描述這張圖片的內容。"
    @State private var responseText = ""
    @State private var tokenUsage: TokenUsageSummary?
    @State private var isLoadingImage = false
    @State private var isGenerating = false
    @State private var isDiagnosticsExpanded = false
    @State private var errorMessage: String?

    private let model = SystemLanguageModel.default

    // ScrollViewReader 需要穩定的 id，response 回來後會捲到這個位置。
    private enum ScrollTarget {
        case response
    }

    // Usage API 回傳的資料比畫面需要的多，這裡只整理 Demo 要顯示的 token 數字。
    private struct TokenUsageSummary {
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

    // 將這個 Demo 可能遇到的狀態轉成 LocalizedError，方便直接顯示在畫面上。
    private enum DemoError: LocalizedError {
        case missingImage
        case invalidImageData
        case modelUnavailable(SystemLanguageModel.Availability.UnavailableReason)
        case visionUnavailable

        var errorDescription: String? {
            switch self {
            case .missingImage:
                return "請先選擇一張圖片。"
            case .invalidImageData:
                return "無法讀取這張圖片，請換一張再試。"
            case .modelUnavailable(let reason):
                return "Model is unavailable: \(String(describing: reason))"
            case .visionUnavailable:
                return "目前的 SystemLanguageModel 不支援 vision capability。"
            }
        }
    }

    var body: some View {
        // ScrollViewReader 用來在模型完成回應後，自動捲到 responseArea。
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    imagePickerArea
                    promptArea
                    diagnosticArea
                    statusArea
                    usageArea
                    responseArea
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture { isPromptFocused = false }
            .navigationTitle("Image Understanding")
            .onChange(of: selectedPhotoItem) { _, newItem in
                loadImage(from: newItem)
            }
            .task(id: isGenerating) {
                guard !isGenerating, !responseText.isEmpty else { return }
                await scrollToResponse(using: proxy)
            }
        }
    }

    @MainActor
    private func scrollToResponse(using proxy: ScrollViewProxy) async {
        // responseArea 需要等 isGenerating=false 後才會被插入畫面；
        // 稍微延後可以確保 transition/layout 完成後，ScrollViewReader 找得到目標 id。
        try? await Task.sleep(for: .milliseconds(300))

        guard !isGenerating, !responseText.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(ScrollTarget.response, anchor: .top)
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
                        Image(systemName: "photo")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)

                        Text("選擇一張圖片開始")
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
        // 圖片理解仍然要先確認 on-device model 可用；不可用時不提供送出按鈕。
        switch model.availability {
        case .available:
            PromptField(title: "請輸入你想問圖片的問題", text: $prompt, isFocused: $isPromptFocused)
                .focused($isPromptFocused)

            Button(action: submit) {
                Label("分析圖片", systemImage: "sparkles")
                    .font(.title3)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(isSubmitDisabled)
            .opacity(isSubmitDisabled ? 0.6 : 1)

        case .unavailable(let reason):
            Text("Model is unavailable: \(String(describing: reason))")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var diagnosticArea: some View {
        // 平常只顯示一行摘要；需要排查時再展開完整 availability。
        DisclosureGroup(isExpanded: $isDiagnosticsExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                diagnosticRow("模型狀態", String(describing: model.availability))
                diagnosticRow("模型可用", model.isAvailable ? "是" : "否")
                diagnosticRow("支援圖片理解", model.capabilities.contains(.vision) ? "是" : "否")
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
        let visionText = model.capabilities.contains(.vision) ? "可分析圖片" : "不支援圖片"
        return "\(availabilityText) · \(visionText)"
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
    private var statusArea: some View {
        if isGenerating {
            ProgressView("正在分析圖片…")
                .frame(maxWidth: .infinity, alignment: .center)
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
            // 選到新圖片時清掉舊輸出，避免使用者誤以為舊回應屬於新圖片。
            await MainActor.run {
                isLoadingImage = true
                errorMessage = nil
                responseText = ""
                tokenUsage = nil
            }

            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    throw DemoError.invalidImageData
                }

                // 大圖會增加模型處理成本與失敗機率；Demo 先縮到合理尺寸再送進模型。
                let preparedImage = image.preparedForFoundationModels(maxPixelLength: 1_280)
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
            errorMessage = DemoError.missingImage.localizedDescription
            return
        }

        Task {
            prepareForRequest()

            do {
                // response.usage 是「這次請求」的 token 統計，適合用在單次 Demo 結果。
                let response = try await generateResponse(for: trimmed, image: selectedImage)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        responseText = response.content
                        tokenUsage = TokenUsageSummary(usage: response.usage)
                        isGenerating = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        errorMessage = "發生錯誤：\(error.localizedDescription)"
                        isGenerating = false
                    }
                }
            }
        }
    }

    @MainActor
    private func prepareForRequest() {
        isPromptFocused = false
        withAnimation(.easeInOut(duration: 0.2)) {
            isGenerating = true
            responseText = ""
            tokenUsage = nil
            errorMessage = nil
        }
    }

    private func generateResponse(
        for prompt: String,
        image: UIImage
    ) async throws -> LanguageModelSession.Response<String> {
        // availability 與 vision capability 分開檢查，錯誤訊息會比較容易定位問題。
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw DemoError.modelUnavailable(reason)
        }

        guard model.capabilities.contains(.vision) else {
            throw DemoError.visionUnavailable
        }

        let session = LanguageModelSession(model: model)
        return try await session.respond {
            prompt
            // Attachment(image) 是 WWDC26 新增的圖片輸入形式，和文字 prompt 放在同一個 builder。
            Attachment(image)
        }
    }
}

private extension UIImage {
    func preparedForFoundationModels(maxPixelLength: CGFloat) -> UIImage {
        // 只縮超過限制的圖片；小圖保留原尺寸，避免不必要的重新繪製。
        let longestSide = max(size.width, size.height)
        guard longestSide > maxPixelLength else { return self }

        let scale = maxPixelLength / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

@available(iOS 27.0, *)
#Preview {
    NavigationStack {
        ImageUnderstandingView()
    }
}
