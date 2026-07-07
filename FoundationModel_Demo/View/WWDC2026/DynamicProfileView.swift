//
//  DynamicProfileView.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2026/7/7.
//

import Foundation
import FoundationModels
import SwiftUI

@available(iOS 27.0, *)
struct DynamicProfileView: View {
    @FocusState private var isPromptFocused: Bool

    // mode 是這個 demo 的核心狀態。
    // 使用者切換 mode 時，下面建立的 LanguageModelSession 會套用不同 DynamicProfile。
    @State private var mode: AIMode = .chat
    @State private var prompt = AIMode.chat.samplePrompt
    @State private var responseText = ""
    @State private var tokenUsage: TokenUsageSummary?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let model = SystemLanguageModel.default

    // ScrollViewReader 需要穩定的 id，response 回來後會捲到這個位置。
    private enum ScrollTarget {
        case response
    }

    // Usage API 會回傳這次 response 的 token 統計。
    // View 只保留畫面需要的數字，避免直接把完整 Usage metadata 放進 UI state。
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

    private struct GenerationResult {
        let content: String
        let tokenUsage: TokenUsageSummary
    }

    var body: some View {
        // ScrollViewReader 用來在模型完成回應後，自動捲到 responseArea。
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    modePicker
                    promptArea
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
            .navigationTitle("Dynamic Profiles")
            .onChange(of: mode) { _, newMode in
                // 切換 profile 時重設範例 prompt 與輸出，讓每個模式可以獨立展示。
                prompt = newMode.samplePrompt
                responseText = ""
                tokenUsage = nil
                errorMessage = nil
            }
            .task(id: isLoading) {
                guard !isLoading, !responseText.isEmpty else { return }
                await scrollToResponse(using: proxy)
            }
        }
    }

    @MainActor
    private func scrollToResponse(using proxy: ScrollViewProxy) async {
        // responseArea 需要等 isLoading=false 後才會被插入畫面；
        // 稍微延後可以確保 transition/layout 完成後，ScrollViewReader 找得到目標 id。
        try? await Task.sleep(for: .milliseconds(300))

        guard !isLoading, !responseText.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(ScrollTarget.response, anchor: .top)
        }
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("模式")
                .font(.headline)

            // 這個 Picker 只改變 UI state；真正的 session profile 會在送出時建立。
            Picker("模式", selection: $mode) {
                ForEach(AIMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var promptArea: some View {
        // Foundation Models 仍然需要先檢查 availability。
        // Simulator、Apple Intelligence 未啟用、模型未下載完成時都可能 unavailable。
        switch model.availability {
        case .available:
            PromptField(title: mode.promptPlaceholder, text: $prompt, isFocused: $isPromptFocused)
                .focused($isPromptFocused)

            Button(action: submit) {
                Text("送出")
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

    @ViewBuilder
    private var statusArea: some View {
        if isLoading {
            ProgressView("正在使用 \(mode.title) profile…")
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
        if let tokenUsage, !isLoading {
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
        if !responseText.isEmpty && !isLoading {
            ScrollView {
                Text(responseText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .id(ScrollTarget.response)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private var isSubmitDisabled: Bool {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
    }

    private func submit() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            prepareForRequest()

            do {
                // generateResponse 會依目前 mode 建立對應 DynamicProfile session。
                let result = try await generateResponse(for: trimmed)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        responseText = result.content
                        tokenUsage = result.tokenUsage
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        errorMessage = "發生錯誤：\(error.localizedDescription)"
                        isLoading = false
                    }
                }
            }
        }
    }

    @MainActor
    private func prepareForRequest() {
        // 所有 UI state 更新集中在 MainActor，避免 async request 回來時更新 SwiftUI 狀態出現競態。
        isPromptFocused = false
        withAnimation(.easeInOut(duration: 0.2)) {
            isLoading = true
            responseText = ""
            tokenUsage = nil
            errorMessage = nil
        }
    }

    private func generateResponse(for prompt: String) async throws -> GenerationResult {
        // 這行是 Dynamic Profiles 的實際使用點：
        // session 會根據 DynamicProfileTool(mode:) 啟用不同 instructions / tools / model options。
        let session = LanguageModelSession(profile: DynamicProfileTool(mode: mode))

        switch mode {
        case .chat:
            // 一般文字回應，使用目前 profile 的 instructions。
            let response = try await session.respond(to: prompt)
            return makeResult(content: response.content, usage: response.usage)

        case .travel:
            // 旅遊模式展示 structured output。
            // Profile 決定模型行為；generating: TripIdeas.self 決定輸出 schema。
            let response = try await session.respond(
                to: "推薦 5 個\(prompt)旅遊行程",
                generating: TripIdeas.self
            )
            return makeResult(content: response.content.ideas, usage: response.usage)

        case .weather:
            // 天氣模式的 Profile 已注入 WeatherTool，模型可在需要時呼叫 tool。
            let response = try await session.respond(to: "請查詢\(prompt)地區的天氣")
            return makeResult(content: response.content, usage: response.usage)

        case .pet:
            // 寵物模式展示另一個 structured output，用 @Guide 限制欄位內容。
            let response = try await session.respond(
                to: "請產生一隻種類為\(prompt)的寵物資料",
                generating: PetProfile.self
            )
            let pet = response.content
            let content = """
            寵物種類：\(prompt)
            寵物姓名：\(pet.name)
            寵物年齡：\(pet.age)
            寵物個性：\(pet.description)
            """
            return makeResult(content: content, usage: response.usage)

        case .deepPlanning:
            // deepPlanning 目前固定使用 SystemLanguageModel。
            // PCC 需要 entitlement，未申請前不要初始化 PrivateCloudComputeLanguageModel。
            let response = try await session.respond(to: prompt)
            return makeResult(content: response.content, usage: response.usage)
        }
    }

    private func makeResult(content: String, usage: LanguageModelSession.Usage) -> GenerationResult {
        GenerationResult(content: content, tokenUsage: TokenUsageSummary(usage: usage))
    }
}

@available(iOS 27.0, *)
#Preview {
    NavigationStack {
        DynamicProfileView()
    }
}
