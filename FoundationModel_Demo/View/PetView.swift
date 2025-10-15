//
//  PetView.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2025/10/15.
//

import SwiftUI
import FoundationModels

struct PetView: View {
    @FocusState private var isPromptFocused: Bool
    @State private var petType: String = ""
    @State private var responseText: String = ""
    @State private var isLoading: Bool = false
    private let model = SystemLanguageModel.default
    private let petModel = PetModel()

    var body: some View {
        VStack(spacing: 20) {
            if case .available = model.availability {
                PromptField(title: "輸入你想養的寵物類型", text: $petType, isFocused: $isPromptFocused)
                    .focused($isPromptFocused)

                Button(action: submit) {
                    Text("送出")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(petType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                .opacity((petType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading) ? 0.6 : 1)
            } else {
                Text("Model is unavailable")
            }

            if isLoading {
                ProgressView("正在建立你的寵物，請稍候…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
            }
            
            responseView()
        }
        .contentShape(Rectangle())
        .onTapGesture { isPromptFocused = false }
        .padding()
        .navigationTitle("養一隻寵物")
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
            let trimmed = petType.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let pet = await petModel.getAPet( petType: petType ) else {
                withAnimation(.easeInOut(duration: 0.2)) { isLoading = false }
                return
            }
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isLoading = false
                    responseText = """
                        寵物種類：\(petType)
                        寵物姓名：\(pet.name)
                        寵物年齡：\(pet.age)
                        寵物個性：\(pet.description)
                        """
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PetView()
    }
}
