//
//  WeatherView.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2025/10/15.
//

import SwiftUI
import FoundationModels

struct WeatherView: View {
    @FocusState private var isPromptFocused: Bool
    @State private var city = ""
    @State private var responseText = ""
    @State private var isLoading = false
    private let model = SystemLanguageModel.default
    
    var body: some View {
        VStack(spacing: 20) {
            mainContent

            if isLoading {
                ProgressView("正在查詢\(city)天氣…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
            }

            ResponseArea(text: responseText, isLoading: isLoading)
        }
        .contentShape(Rectangle())
        .onTapGesture { isPromptFocused = false }
        .padding()
        .navigationTitle("查詢天氣")
    }
    
    private func send() {
        Task {
            isPromptFocused = false
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoading = true
                responseText = ""
            }
            let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                withAnimation(.easeInOut(duration: 0.2)) { isLoading = false }
                return
            }
            let answer = await AITool.shared.queryWithWeatherTool(city: city)
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
            PromptField(title: "請輸入地區名稱", text: $city, isFocused: $isPromptFocused)
                .focused($isPromptFocused)

            Button(action: send) {
                Text("送出")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            .opacity((city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading) ? 0.6 : 1)
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
        WeatherView()
    }
}
