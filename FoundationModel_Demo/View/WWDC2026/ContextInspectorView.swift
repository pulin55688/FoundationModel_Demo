//
//  ContextInspectorView.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2026/7/7.
//

import Foundation
import FoundationModels
import SwiftUI

@available(iOS 26.4, *)
struct ContextInspectorView: View {
    @FocusState private var isPromptFocused: Bool

    @State private var prompt = """
        請你閱讀以下產品需求文件，整理成技術規格、風險清單、開發排程、測試案例與上線檢查表。

        背景：這是一個使用 Foundation Models Framework 的 iOS Demo App，目標是比較 WWDC25 與 WWDC26 的差異，包含 SystemLanguageModel、Dynamic Profiles、Image Understanding、Usage API、Context Inspector、Evaluation Framework，以及 Private Cloud Compute Language Model 的限制。請特別注意每個功能在真機、模擬器、開發者帳號、entitlement、模型 availability、token usage 與 context size 上的差異。

        需求：使用者可以輸入 prompt、選擇不同模式、上傳圖片、查看模型診斷資訊、計算 token 用量，並在回應完成後自動捲動到結果區塊。UI 必須適合小螢幕，不可以因為內容太長而超出畫面，也要避免診斷資訊佔用太多空間。
        
        請不要只摘要，請逐段分析每一個需求，列出實作細節、可能失敗原因、替代方案與測試方式。
        """
    @State private var result: TokenInspectionResult?
    @State private var isInspecting = false
    @State private var errorMessage: String?

    private let model = SystemLanguageModel.default

    // 這個頁面只關心「輸入內容佔用多少 context」，
    // 不會真的呼叫 respond 產生模型回答。
    private struct TokenInspectionResult {
        let prompt: String
        let contextSize: Int
        let promptTokenCount: Int

        var remainingTokenCount: Int {
            max(contextSize - promptTokenCount, 0)
        }

        var usageRatio: Double {
            guard contextSize > 0 else { return 0 }
            return min(Double(promptTokenCount) / Double(contextSize), 1)
        }

        var usagePercentageText: String {
            usageRatio.formatted(.percent.precision(.fractionLength(1)))
        }

        var isOverContext: Bool {
            promptTokenCount > contextSize
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                inputArea
                statusArea
                resultArea
                modelInfoArea
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture { isPromptFocused = false }
        .navigationTitle("Context Inspector")
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("提示詞")
                .font(.headline)

            PromptField(
                title: "請輸入要估算 token 的 prompt",
                text: $prompt,
                isFocused: $isPromptFocused
            )
            .focused($isPromptFocused)

            Button(action: inspectPrompt) {
                Label("計算 Token", systemImage: "number")
                    .font(.title3)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(isSubmitDisabled)
            .opacity(isSubmitDisabled ? 0.6 : 1)
        }
    }

    @ViewBuilder
    private var statusArea: some View {
        if isInspecting {
            ProgressView("正在計算 token…")
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
    private var resultArea: some View {
        if let result, !isInspecting {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Context 使用量")
                        .font(.headline)
                    Spacer()
                    Text(result.usagePercentageText)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(result.isOverContext ? .red : .primary)
                }

                ProgressView(value: result.usageRatio)
                    .tint(result.isOverContext ? .red : .blue)

                VStack(spacing: 8) {
                    metricRow("Context size", result.contextSize)
                    metricRow("Prompt tokens", result.promptTokenCount)
                    metricRow("剩餘 tokens", result.remainingTokenCount)
                }
                .font(.footnote)

                if result.isOverContext {
                    Text("這段 prompt 已超過目前模型的 context size，需要縮短內容或切分成多次請求。")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private var modelInfoArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("模型資訊")
                .font(.headline)

            metricRow("Availability", String(describing: model.availability))
            metricRow("isAvailable", model.isAvailable ? "true" : "false")
            metricRow("Context size", model.contextSize)
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func metricRow(_ title: String, _ value: Int) -> some View {
        metricRow(title, value.formatted())
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
    }

    private var isSubmitDisabled: Bool {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || isInspecting
    }

    private func inspectPrompt() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            prepareForInspection()

            do {
                // tokenCount 只計算 prompt 佔用量，不會產生模型回答。
                let count = try await model.tokenCount(for: trimmed)
                let inspection = TokenInspectionResult(
                    prompt: trimmed,
                    contextSize: model.contextSize,
                    promptTokenCount: count
                )

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        result = inspection
                        isInspecting = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        errorMessage = "計算失敗：\(error.localizedDescription)"
                        isInspecting = false
                    }
                }
            }
        }
    }

    @MainActor
    private func prepareForInspection() {
        isPromptFocused = false
        withAnimation(.easeInOut(duration: 0.2)) {
            isInspecting = true
            result = nil
            errorMessage = nil
        }
    }
}

@available(iOS 26.4, *)
#Preview {
    NavigationStack {
        ContextInspectorView()
    }
}

//請你閱讀以下產品需求文件，整理成技術規格、風險清單、開發排程、測試案例與上線檢查表。
//
//背景：這是一個使用 Foundation Models Framework 的 iOS Demo App，目標是比較 WWDC25 與 WWDC26 的差異，包含 SystemLanguageModel、Dynamic Profiles、Image Understanding、Usage API、Context Inspector、Evaluation Framework，以及 Private Cloud Compute Language Model 的限制。請特別注意每個功能在真機、模擬器、開發者帳號、entitlement、模型 availability、token usage 與 context size 上的差異。
//
//需求：使用者可以輸入 prompt、選擇不同模式、上傳圖片、查看模型診斷資訊、計算 token 用量，並在回應完成後自動捲動到結果區塊。UI 必須適合小螢幕，不可以因為內容太長而超出畫面，也要避免診斷資訊佔用太多空間。
//
//請不要只摘要，請逐段分析每一個需求，列出實作細節、可能失敗原因、替代方案與測試方式。
//
//請你閱讀以下產品需求文件，整理成技術規格、風險清單、開發排程、測試案例與上線檢查表。
//
//背景：這是一個使用 Foundation Models Framework 的 iOS Demo App，目標是比較 WWDC25 與 WWDC26 的差異，包含 SystemLanguageModel、Dynamic Profiles、Image Understanding、Usage API、Context Inspector、Evaluation Framework，以及 Private Cloud Compute Language Model 的限制。請特別注意每個功能在真機、模擬器、開發者帳號、entitlement、模型 availability、token usage 與 context size 上的差異。
//
//需求：使用者可以輸入 prompt、選擇不同模式、上傳圖片、查看模型診斷資訊、計算 token 用量，並在回應完成後自動捲動到結果區塊。UI 必須適合小螢幕，不可以因為內容太長而超出畫面，也要避免診斷資訊佔用太多空間。
//
//請不要只摘要，請逐段分析每一個需求，列出實作細節、可能失敗原因、替代方案與測試方式。
//
//請你閱讀以下產品需求文件，整理成技術規格、風險清單、開發排程、測試案例與上線檢查表。
//
//背景：這是一個使用 Foundation Models Framework 的 iOS Demo App，目標是比較 WWDC25 與 WWDC26 的差異，包含 SystemLanguageModel、Dynamic Profiles、Image Understanding、Usage API、Context Inspector、Evaluation Framework，以及 Private Cloud Compute Language Model 的限制。請特別注意每個功能在真機、模擬器、開發者帳號、entitlement、模型 availability、token usage 與 context size 上的差異。
//
//需求：使用者可以輸入 prompt、選擇不同模式、上傳圖片、查看模型診斷資訊、計算 token 用量，並在回應完成後自動捲動到結果區塊。UI 必須適合小螢幕，不可以因為內容太長而超出畫面，也要避免診斷資訊佔用太多空間。
//
//請不要只摘要，請逐段分析每一個需求，列出實作細節、可能失敗原因、替代方案與測試方式。
//
//請你閱讀以下產品需求文件，整理成技術規格、風險清單、開發排程、測試案例與上線檢查表。
//
//背景：這是一個使用 Foundation Models Framework 的 iOS Demo App，目標是比較 WWDC25 與 WWDC26 的差異，包含 SystemLanguageModel、Dynamic Profiles、Image Understanding、Usage API、Context Inspector、Evaluation Framework，以及 Private Cloud Compute Language Model 的限制。請特別注意每個功能在真機、模擬器、開發者帳號、entitlement、模型 availability、token usage 與 context size 上的差異。
//
//需求：使用者可以輸入 prompt、選擇不同模式、上傳圖片、查看模型診斷資訊、計算 token 用量，並在回應完成後自動捲動到結果區塊。UI 必須適合小螢幕，不可以因為內容太長而超出畫面，也要避免診斷資訊佔用太多空間。
//
//請不要只摘要，請逐段分析每一個需求，列出實作細節、可能失敗原因、替代方案與測試方式。
//
//請你閱讀以下產品需求文件，整理成技術規格、風險清單、開發排程、測試案例與上線檢查表。
//
//背景：這是一個使用 Foundation Models Framework 的 iOS Demo App，目標是比較 WWDC25 與 WWDC26 的差異，包含 SystemLanguageModel、Dynamic Profiles、Image Understanding、Usage API、Context Inspector、Evaluation Framework，以及 Private Cloud Compute Language Model 的限制。請特別注意每個功能在真機、模擬器、開發者帳號、entitlement、模型 availability、token usage 與 context size 上的差異。
//
//需求：使用者可以輸入 prompt、選擇不同模式、上傳圖片、查看模型診斷資訊、計算 token 用量，並在回應完成後自動捲動到結果區塊。UI 必須適合小螢幕，不可以因為內容太長而超出畫面，也要避免診斷資訊佔用太多空間。
//
//請不要只摘要，請逐段分析每一個需求，列出實作細節、可能失敗原因、替代方案與測試方式。
//
//請你閱讀以下產品需求文件，整理成技術規格、風險清單、開發排程、測試案例與上線檢查表。
//
//背景：這是一個使用 Foundation Models Framework 的 iOS Demo App，目標是比較 WWDC25 與 WWDC26 的差異，包含 SystemLanguageModel、Dynamic Profiles、Image Understanding、Usage API、Context Inspector、Evaluation Framework，以及 Private Cloud Compute Language Model 的限制。請特別注意每個功能在真機、模擬器、開發者帳號、entitlement、模型 availability、token usage 與 context size 上的差異。
//
//需求：使用者可以輸入 prompt、選擇不同模式、上傳圖片、查看模型診斷資訊、計算 token 用量，並在回應完成後自動捲動到結果區塊。UI 必須適合小螢幕，不可以因為內容太長而超出畫面，也要避免診斷資訊佔用太多空間。
//
//請不要只摘要，請逐段分析每一個需求，列出實作細節、可能失敗原因、替代方案與測試方式。
//
//請你閱讀以下產品需求文件，整理成技術規格、風險清單、開發排程、測試案例與上線檢查表。
//
//背景：這是一個使用 Foundation Models Framework 的 iOS Demo App，目標是比較 WWDC25 與 WWDC26 的差異，包含 SystemLanguageModel、Dynamic Profiles、Image Understanding、Usage API、Context Inspector、Evaluation Framework，以及 Private Cloud Compute Language Model 的限制。請特別注意每個功能在真機、模擬器、開發者帳號、entitlement、模型 availability、token usage 與 context size 上的差異。
//
//需求：使用者可以輸入 prompt、選擇不同模式、上傳圖片、查看模型診斷資訊、計算 token 用量，並在回應完成後自動捲動到結果區塊。UI 必須適合小螢幕，不可以因為內容太長而超出畫面，也要避免診斷資訊佔用太多空間。
//
//請不要只摘要，請逐段分析每一個需求，列出實作細節、可能失敗原因、替代方案與測試方式。
//
//請你閱讀以下產品需求文件，整理成技術規格、風險清單、開發排程、測試案例與上線檢查表。
//
//背景：這是一個使用 Foundation Models Framework 的 iOS Demo App，目標是比較 WWDC25 與 WWDC26 的差異，包含 SystemLanguageModel、Dynamic Profiles、Image Understanding、Usage API、Context Inspector、Evaluation Framework，以及 Private Cloud Compute Language Model 的限制。請特別注意每個功能在真機、模擬器、開發者帳號、entitlement、模型 availability、token usage 與 context size 上的差異。
//
//需求：使用者可以輸入 prompt、選擇不同模式、上傳圖片、查看模型診斷資訊、計算 token 用量，並在回應完成後自動捲動到結果區塊。UI 必須適合小螢幕，不可以因為內容太長而超出畫面，也要避免診斷資訊佔用太多空間。
//
//請不要只摘要，請逐段分析每一個需求，列出實作細節、可能失敗原因、替代方案與測試方式。
