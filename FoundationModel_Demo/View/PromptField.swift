import SwiftUI

public struct PromptField: View {
    let title: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    public init(title: String, text: Binding<String>, isFocused: FocusState<Bool>.Binding) {
        self.title = title
        self._text = text
        self.isFocused = isFocused
    }

    public var body: some View {
        ZStack(alignment: .trailing) {
            TextField(title, text: $text)
                .textFieldStyle(.roundedBorder)
                .padding()
                .focused(isFocused)
                .submitLabel(.done)
                .onSubmit {
                    isFocused.wrappedValue = false
                }

            if isFocused.wrappedValue && !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .tint(.secondary)
                        .padding(4)
                }
                .padding(.trailing, 16) // 與 .padding() 對齊調整
            }
        }
    }
}

#Preview {
    struct PreviewHost: View {
        @State var text = ""
        @FocusState var focused: Bool
        var body: some View {
            PromptField(title: "請輸入問題…", text: $text, isFocused: $focused)
        }
    }
    return PreviewHost()
}
