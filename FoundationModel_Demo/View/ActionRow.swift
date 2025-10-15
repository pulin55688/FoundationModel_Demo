import SwiftUI

struct ActionRow: View {
    let systemImage: String
    let title: String
    let trailingSystemImage: String?

    init(systemImage: String, title: String, trailingSystemImage: String? = "chevron.right") {
        self.systemImage = systemImage
        self.title = title
        self.trailingSystemImage = trailingSystemImage
    }

    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .imageScale(.large)
            Text(title)
                .font(.headline)
            Spacer()
            if let trailing = trailingSystemImage {
                Image(systemName: trailing)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ActionRow(systemImage: "star.fill", title: "Example Row")
}
