//
//  TripIdeasView.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2025/10/15.
//

import Foundation
import SwiftUI
import FoundationModels

struct TripIdeasView: View {
    @FocusState private var isPromptFocused: Bool
    @State private var country = ""
    @State private var responseText = ""
    @State private var isLoading = false
    private let model = SystemLanguageModel.default
    private let tripModel = TripIdeasTool()

    var body: some View {
        VStack(spacing: 20) {
            if case .available = model.availability {
                PromptField(title: "輸入你想去的國家名稱", text: $country, isFocused: $isPromptFocused)
                    .focused($isPromptFocused)

                Button(action: submit) {
                    Text("送出")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                .opacity((country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading) ? 0.6 : 1)
            } else {
                Text("Model is unavailable")
            }

            loadingView()
            responseView()
        }
        .contentShape(Rectangle())
        .onTapGesture { isPromptFocused = false }
        .padding()
        .navigationTitle("旅遊規劃建議")
    }

    @ViewBuilder
    private func loadingView() -> some View {
        if isLoading {
            ProgressView("正在產生\(country)旅遊建議…")
                .frame(maxWidth: .infinity, alignment: .center)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private func responseView() -> some View {
        if !responseText.isEmpty && !isLoading {
            ScrollView {
                Text(responseText)
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

    private func submit() {
        Task {
            isPromptFocused = false
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoading = true
                responseText = ""
            }
            do {
                for try await partialTrip in tripModel.getTrip(country: country) {
                    await updateUI {
                        responseText = partialTrip
                        isLoading = false
                    }
                }
            } catch {
                await updateUI {
                    responseText = "發生錯誤：\(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    @MainActor
    private func updateUI(_ changes: @escaping () -> Void) async {
        withAnimation(.easeInOut(duration: 0.25)) {
            changes()
        }
    }
}

#Preview {
    NavigationStack {
        TripIdeasView()
    }
}
