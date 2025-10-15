import SwiftUI
import FoundationModels

struct ChatView: View {
    @FocusState private var isPromptFocused: Bool
    @State private var prompt = ""
    @State private var responseText = ""
    @State private var isLoading = false
    private let model = SystemLanguageModel.default
    
    var body: some View {
        VStack(spacing: 20) {
            mainContent

            if isLoading {
                ProgressView("正在產生回應…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
            }

            ResponseArea(text: responseText, isLoading: isLoading)
        }
        .contentShape(Rectangle())
        .onTapGesture { isPromptFocused = false }
        .padding()
        .navigationTitle("AI 對話")
    }
    
    private func send() {
        Task {
            isPromptFocused = false
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoading = true
                responseText = ""
            }
            let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                withAnimation(.easeInOut(duration: 0.2)) { isLoading = false }
                return
            }
            let answer = await AITool.shared.generateResponse(for: trimmed)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isLoading = false
                    responseText = answer
                }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch model.availability {
        case .available:
            PromptField(title: "請輸入問題…", text: $prompt, isFocused: $isPromptFocused)
                .focused($isPromptFocused)

            Button(action: send) {
                Text("送出")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            .opacity((prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading) ? 0.6 : 1)
        case .unavailable(_):
            Text("Model is unavailable")
        }
    }
}

private struct ResponseArea: View {
    let text: String
    let isLoading: Bool

    var body: some View {
        Group {
            if !text.isEmpty && !isLoading {
                ScrollView {
                    Text(text)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .font(.body)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
