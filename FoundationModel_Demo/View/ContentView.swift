//  ContentView.swift
//  FoundationModel_Demo
//
//  Created by Pulin on 2025/9/20.
//

import SwiftUI
import FoundationModels

struct ContentView: View {
    private let actions: [Action] = [
        .chat,
        .tripIdeas
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradient()
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer(minLength: 0)

                    TitleHeader( title: "Apple Intelligence",
                                 subtitle: "選擇一種模式開始互動" )
                        .padding(.horizontal)

                    ActionCard {
                        ForEach(actions, id: \.self) { action in
                            ActionLink(action: action)
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding()
            }
            .navigationTitle("")
        }
    }
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

private enum Action: Hashable {
    case chat
    case tripIdeas

    var systemImage: String {
        switch self {
        case .chat: return "message.fill"
        case .tripIdeas: return "airplane.departure"
        }
    }

    var title: String {
        switch self {
        case .chat: return "開始自由對話"
        case .tripIdeas: return "取得旅遊建議"
        }
    }

    var tint: Color {
        switch self {
        case .chat: return .blue
        case .tripIdeas: return .green
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .chat:
            ChatView()
        case .tripIdeas:
            TripIdeasView()
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
