import SwiftUI

struct SymbolStudio: View {
    @Binding var selectedName: String
    @Binding var caption: String
    var fromName: String
    var placeName: String? = nil

    @State private var query = ""
    @State private var category = ""

    private var current: WinkMessage {
        WinkMessage(
            text: caption,
            pack: "Symbols",
            atmosphere: "Symbols",
            ink: .volt,
            symbolName: selectedName,
            placeName: placeName
        )
    }

    private var results: [SFSymbolRecord] {
        SFSymbolCatalog.matches(query, category: category)
    }

    var body: some View {
        StudioLayout {
            WinkCardView(message: current, fromName: fromName)
        } controls: {
            VStack(spacing: 12) {
            TextField("Caption", text: $caption)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .tint(WinkColor.volt)
                .padding(.horizontal, 36)
                .winkWritingTools()
                .onChange(of: caption) { _, newValue in
                    if newValue.count > 40 {
                        caption = String(newValue.prefix(40))
                    }
                }

            SuggestLinesRow(composerName: "Symbol", seed: selectedName, target: $caption)

            TextField("Search symbols", text: $query)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.white.opacity(0.08)).padding(.horizontal, 24))
                .tint(WinkColor.volt)
                .padding(.horizontal, 36)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    categoryChip("All", key: "")
                    ForEach(SFSymbolCatalog.categories) { item in
                        categoryChip(item.label, key: item.key)
                    }
                }
                .padding(.horizontal, 22)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(results) { record in
                    Button {
                        selectedName = record.name
                    } label: {
                        Image(systemName: record.name)
                            .font(.system(size: 22, weight: .regular))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(selectedName == record.name ? WinkColor.night : .white.opacity(0.85))
                            .frame(width: 52, height: 52)
                            .background(selectedName == record.name ? WinkColor.volt : Color.white.opacity(0.06))
                    }
                    .accessibilityLabel(record.name)
                }
            }
            .padding(.horizontal, 18)
            }
        }
    }

    private func categoryChip(_ label: String, key: String) -> some View {
        Button {
            category = key
        } label: {
            VStack(spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(category == key ? WinkColor.volt : .white.opacity(0.7))
                Rectangle()
                    .fill(category == key ? WinkColor.volt : Color.clear)
                    .frame(height: 2)
            }
        }
    }
}
