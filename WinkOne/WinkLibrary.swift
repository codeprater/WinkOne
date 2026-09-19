import Combine
import SwiftUI
import UIKit

// MARK: - Item

/// One row in the library, whatever page it came from. Received cards, sent
/// cards and the built-in packs all normalize to this so search, the grid and
/// the context menu only ever deal with one shape.
struct LibraryItem: Identifiable, Equatable {
    enum Source: Equatable {
        case received(UUID)
        case sent(UUID)
        case pack
    }

    let id: UUID
    let message: WinkMessage
    let title: String
    let subtitle: String
    let date: Date?
    let source: Source

    var isRemovable: Bool {
        switch source {
        case .received, .sent: true
        case .pack: false
        }
    }

    /// Everything search looks at. Deliberately not the payload bytes.
    var searchText: String {
        [message.text, message.pack, message.atmosphere, title,
         message.moodWord ?? "", message.emojiSequence ?? "",
         message.zodiacSign ?? "", message.nameTagName ?? ""]
            .joined(separator: " ")
            .lowercased()
    }
}

enum LibraryPage: String, CaseIterable, Identifiable {
    case recent = "Recent"
    case shared = "Shared"
    case browse = "Browse"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .recent: "clock"
        case .shared: "paperplane"
        case .browse: "square.grid.2x2"
        }
    }

    var emptyLine: String {
        switch self {
        case .recent: "Nothing has arrived yet."
        case .shared: "You haven't sent a card yet."
        case .browse: "No cards match that."
        }
    }
}

// MARK: - Library

/// The Preview-app shape: three pages, a search icon, a menu, and a grid you
/// can long-press straight into a send.
struct WinkLibrary: View {
    var peers: [WinkPeer]
    var fromName: String
    var onUse: (WinkMessage) -> Void
    var onQuickSend: (WinkMessage, WinkPeer) -> Void
    var onClose: () -> Void

    @ObservedObject private var moderation = ModerationStore.shared

    @AppStorage("wink.walletScroll") private var walletScroll = false
    @AppStorage("wink.library.page") private var storedPage = LibraryPage.recent.rawValue

    @State private var query = ""
    @State private var searching = false
    @State private var preview: LibraryItem?
    @State private var showSettings = false
    @State private var confirmClear = false
    @FocusState private var searchFocused: Bool

    private var page: LibraryPage {
        LibraryPage(rawValue: storedPage) ?? .recent
    }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    // MARK: Data

    private var allItems: [LibraryItem] {
        switch page {
        case .recent:
            return moderation.received.map { wink in
                LibraryItem(
                    id: wink.id,
                    message: wink.payload.asMessage,
                    title: wink.fromName,
                    subtitle: Self.stamp.string(from: wink.date),
                    date: wink.date,
                    source: .received(wink.id)
                )
            }
        case .shared:
            return moderation.sent.map { wink in
                LibraryItem(
                    id: wink.id,
                    message: wink.payload.asMessage,
                    title: "To \(wink.toName)",
                    subtitle: Self.stamp.string(from: wink.date),
                    date: wink.date,
                    source: .sent(wink.id)
                )
            }
        case .browse:
            return DeckLoader.loadDecks().flatMap { deck in
                deck.messages.map { card in
                    LibraryItem(
                        id: card.id,
                        message: card,
                        title: deck.name,
                        subtitle: deck.atmosphere,
                        date: nil,
                        source: .pack
                    )
                }
            }
        }
    }

    private var items: [LibraryItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return allItems }
        return allItems.filter { $0.searchText.contains(trimmed) }
    }

    /// Browse groups by atmosphere so twelve packs do not read as one wall.
    private var groups: [(String, [LibraryItem])] {
        guard page == .browse else { return [("", items)] }
        let buckets = Dictionary(grouping: items, by: { $0.subtitle })
        return DeckLoader.atmospheres
            .compactMap { atmosphere in
                guard let bucket = buckets[atmosphere.name], !bucket.isEmpty else { return nil }
                return (Composer.display(atmosphere.name), bucket)
            }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                WinkColor.night.ignoresSafeArea()

                if items.isEmpty {
                    emptyState
                } else if walletScroll {
                    walletStack
                } else {
                    grid
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { chrome }
            .navigationBarHidden(true)
        }
        .presentationBackground(WinkColor.night)
        .sheet(item: $preview) { item in
            LibraryPreview(
                item: item,
                fromName: fromName,
                peers: peers,
                onUse: { card in
                    preview = nil
                    onUse(card)
                },
                onQuickSend: { card, peer in
                    preview = nil
                    onQuickSend(card, peer)
                },
                onClose: { preview = nil }
            )
        }
        .sheet(isPresented: $showSettings) {
            WinkSettingsView(onClose: { showSettings = false })
        }
        .confirmationDialog(
            page == .recent ? "Remove every received card?" : "Remove every sent card?",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button("Remove All", role: .destructive) {
                if page == .recent { moderation.removeAllReceived() } else { moderation.removeAllSent() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Chrome

    private var chrome: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Button(action: onClose) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Close the library")

                Text("WINKS")
                    .font(WinkFont.brand(20))
                    .tracking(3)
                    .foregroundStyle(WinkColor.volt)
                    .fixedSize()

                Spacer(minLength: 4)

                Button {
                    withAnimation(.easeOut(duration: 0.22)) { searching.toggle() }
                    if searching {
                        searchFocused = true
                    } else {
                        query = ""
                        searchFocused = false
                    }
                } label: {
                    Image(systemName: searching ? "xmark" : "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(searching ? WinkColor.volt : .white.opacity(0.7))
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel(searching ? "Close search" : "Search your cards")

                Menu {
                    Picker("View", selection: $storedPage) {
                        ForEach(LibraryPage.allCases) { item in
                            Label(item.rawValue, systemImage: item.icon).tag(item.rawValue)
                        }
                    }
                    Toggle(isOn: $walletScroll) {
                        Label("Wallet Stack", systemImage: "rectangle.stack")
                    }
                    Divider()
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    if page != .browse, !allItems.isEmpty {
                        Button(role: .destructive) {
                            confirmClear = true
                        } label: {
                            Label("Remove All", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("More")
            }
            .padding(.horizontal, 10)

            if searching {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                    TextField("Search winks", text: $query)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .tint(WinkColor.volt)
                        .autocorrectionDisabled()
                        .focused($searchFocused)
                        .submitLabel(.search)
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            pageBar
        }
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private var pageBar: some View {
        HStack(spacing: 0) {
            ForEach(LibraryPage.allCases) { item in
                let on = item == page
                Button {
                    storedPage = item.rawValue
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 5) {
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(item.rawValue.uppercased())
                                .font(WinkFont.label(11))
                                .tracking(1.1)
                                .fixedSize()
                        }
                        .foregroundStyle(on ? WinkColor.volt : .white.opacity(0.42))
                        Rectangle()
                            .fill(on ? WinkColor.volt : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Pages

    private var grid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                ForEach(groups, id: \.0) { name, bucket in
                    Section {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(bucket) { item in
                                tile(item)
                            }
                        }
                        .padding(.horizontal, 16)
                    } header: {
                        if !name.isEmpty {
                            Text(name.uppercased())
                                .font(WinkFont.label(11))
                                .tracking(1.6)
                                .foregroundStyle(.white.opacity(0.45))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(WinkColor.night.opacity(0.94))
                        }
                    }
                }
            }
            .padding(.vertical, 14)
        }
    }

    /// Wallet's stack: cards overlap from the bottom up, newest on top.
    private var walletStack: some View {
        ScrollView {
            LazyVStack(spacing: -150) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    WinkCardView(message: item.message, fromName: item.title)
                        .frame(height: 330)
                        .shadow(color: .black.opacity(0.5), radius: 16, y: -6)
                        .zIndex(Double(items.count - index))
                        .onTapGesture { preview = item }
                        .contextMenu { menu(for: item) }
                        .accessibilityLabel("\(item.title). \(item.message.text)")
                        .accessibilityHint("Double tap to open. Long press to send.")
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 14)
            .padding(.bottom, 180)
        }
    }

    private func tile(_ item: LibraryItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            WinkCardView(message: item.message, fromName: item.title)
                .onTapGesture { preview = item }
                .contextMenu { menu(for: item) }

            Text(item.title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
            Text(Composer.display(item.subtitle))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap to open. Long press to send it to someone nearby.")
    }

    @ViewBuilder
    private func menu(for item: LibraryItem) -> some View {
        if peers.isEmpty {
            Label("No one nearby", systemImage: "antenna.radiowaves.left.and.right.slash")
        } else {
            Menu {
                ForEach(peers) { peer in
                    Button {
                        onQuickSend(item.message, peer)
                    } label: {
                        Label(peer.winkName, systemImage: "paperplane.fill")
                    }
                }
            } label: {
                Label("Send Nearby", systemImage: "paperplane.fill")
            }
        }

        Button {
            onUse(item.message)
        } label: {
            Label("Open in Composer", systemImage: "square.and.pencil")
        }

        if item.isRemovable {
            Divider()
            Button(role: .destructive) {
                remove(item)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private func remove(_ item: LibraryItem) {
        switch item.source {
        case .received(let id):
            if let wink = moderation.received.first(where: { $0.id == id }) {
                moderation.remove(wink)
            }
        case .sent(let id):
            if let wink = moderation.sent.first(where: { $0.id == id }) {
                moderation.removeSent(wink)
            }
        case .pack:
            break
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: page.icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.white.opacity(0.25))
            Text(query.isEmpty ? page.emptyLine : "No cards match \"\(query)\".")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Preview sheet

/// One card, full size, with the two things you actually want to do to it.
struct LibraryPreview: View {
    let item: LibraryItem
    let fromName: String
    let peers: [WinkPeer]
    var onUse: (WinkMessage) -> Void
    var onQuickSend: (WinkMessage, WinkPeer) -> Void
    var onClose: () -> Void

    var body: some View {
        ZStack {
            WinkColor.night.ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Text(item.title.uppercased())
                        .font(WinkFont.label(11))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 40, height: 40)
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                WinkCardView(message: item.message, fromName: fromName)
                    .padding(.horizontal, 34)

                Text(Composer.display(item.subtitle))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))

                Spacer(minLength: 0)

                if peers.isEmpty {
                    Text("No one nearby right now.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(peers) { peer in
                                Button {
                                    onQuickSend(item.message, peer)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 12, weight: .bold))
                                        Text(peer.winkName)
                                            .font(WinkFont.label(12))
                                            .lineLimit(1)
                                    }
                                    .foregroundStyle(WinkColor.night)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(WinkColor.volt))
                                }
                                .accessibilityLabel("Send to \(peer.winkName)")
                            }
                        }
                        .padding(.horizontal, 22)
                    }
                }

                Button {
                    onUse(item.message)
                } label: {
                    Text("OPEN IN COMPOSER")
                        .font(WinkFont.label(13))
                        .tracking(1.4)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 18)
            }
        }
        .presentationBackground(WinkColor.night)
    }
}
