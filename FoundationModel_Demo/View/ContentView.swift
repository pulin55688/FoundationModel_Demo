//  ContentView.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2025/9/20.
//

import SwiftUI
import FoundationModels
import Playgrounds

struct ContentView: View {
    @AppStorage("showsWWDC26Features")
    private var showsWWDC26Features = false

    private let actions: [Action] = [
        .chat,
        .tripIdeas,
        .pet,
        .weather,
        .contextInspector,
        .imageUnderstanding,
        .dynamicProfile
    ]
    
    private var visibleActions: [Action] {
        actions.filter { showsWWDC26Features || !$0.isWWDC26Feature }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradient()
                    .ignoresSafeArea()

                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 24) {
                            Spacer(minLength: 0)

                            TitleHeader( title: "Apple Intelligence",
                                         subtitle: "選擇一種模式開始互動" )
                                .padding(.horizontal)

                            WWDC26FeatureToggle(isOn: $showsWWDC26Features)
                                .padding(.horizontal)

                            ActionCard {
                                ForEach(visibleActions, id: \.self) { action in
                                    ActionLink(action: action)
                                }
                            }
                            .padding(.horizontal)

                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .center)
                        .padding()
                    }
                }
            }
            .navigationTitle("")
        }
    }
    
//    func createModel() -> GenerativeModel {
//        // Create a `GenerativeModel` instance with a model that supports your use case
//        return ai.generativeModel(modelName: "gemini-2.5-pro")
//    }
}

private struct BackgroundGradient: View {
    var body: some View {
        LinearGradient(
            colors: [ Color(.systemBackground),
                      Color(.secondarySystemBackground) ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct TitleHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct ActionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 16) {
            content
                .buttonStyle(.glassProminent)
        }
        .padding(20)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }
}

private struct WWDC26FeatureToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label("顯示 WWDC26 功能", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
        }
        .tint(.purple)
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}

private enum Action: Hashable {
    case chat
    case tripIdeas
    case pet
    case weather
    case contextInspector
    case imageUnderstanding
    case dynamicProfile

    var systemImage: String {
        switch self {
        case .chat: return "message.fill"
        case .tripIdeas: return "airplane.departure"
        case .pet: return "pawprint.fill"
        case .weather: return "cloud.sun.fill"
        case .contextInspector: return "ruler"
        case .imageUnderstanding: return "photo.fill.on.rectangle.fill"
        case .dynamicProfile: return "slider.horizontal.3"
        }
    }

    var title: String {
        switch self {
        case .chat: return "開始自由對話"
        case .tripIdeas: return "取得旅遊建議"
        case .pet: return "來養一隻寵物"
        case .weather: return "查詢天氣"
        case .contextInspector: return "Context Inspector"
        case .imageUnderstanding: return "圖片理解"
        case .dynamicProfile: return "Dynamic Profiles"
        }
    }

    var tint: Color {
        switch self {
        case .chat: return .blue
        case .tripIdeas: return .green
        case .pet: return .orange
        case .weather: return .teal
        case .contextInspector: return .mint
        case .imageUnderstanding: return .indigo
        case .dynamicProfile: return .purple
        }
    }

    var isWWDC26Feature: Bool {
        switch self {
        case .contextInspector, .imageUnderstanding, .dynamicProfile:
            return true
        case .chat, .tripIdeas, .pet, .weather:
            return false
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .chat:
            ChatView()
        case .tripIdeas:
            TripIdeasView()
        case .pet:
            PetView()
        case .weather:
            WeatherView()
        case .contextInspector:
            if #available(iOS 26.4, *) {
                ContextInspectorView()
            } else {
                Text("Context Inspector requires iOS 26.4.")
            }
        case .imageUnderstanding:
            if #available(iOS 27.0, *) {
                ImageUnderstandingView()
            } else {
                Text("Image Understanding requires iOS 27.")
            }
        case .dynamicProfile:
            if #available(iOS 27.0, *) {
                DynamicProfileView()
            } else {
                Text("Dynamic Profiles require iOS 27.")
            }
        }
    }
}

private struct ActionLink: View {
    let action: Action

    var body: some View {
        NavigationLink {
            action.destination
        } label: {
            ActionRow(systemImage: action.systemImage, title: action.title)
        }
        .tint(action.tint)
    }
}



#Preview {
    ContentView()
}
