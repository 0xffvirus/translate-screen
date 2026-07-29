import PhotosUI
import SwiftUI
import Translation

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0
    @State private var showsOnboarding = false
    @State private var showsFirstSetup = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Translate", systemImage: "viewfinder") }
            .tag(0)

            NavigationStack {
                HistoryView()
            }
            .tabItem { Label("History", systemImage: "clock") }
            .tag(1)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(2)
        }
        .tint(.blue)
        .fullScreenCover(isPresented: $showsOnboarding) {
            OnboardingView {
                hasCompletedOnboarding = true
                showsOnboarding = false
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    showsFirstSetup = true
                }
            }
        }
        .sheet(isPresented: $showsFirstSetup) {
            ShortcutSetupView()
        }
        .fullScreenCover(isPresented: $appState.presentsResult) {
            TranslationResultView()
        }
        .task {
            if !hasCompletedOnboarding {
                showsOnboarding = true
            }
            loadPendingShortcutImage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pendingScreenshotReady)) { _ in
            loadPendingShortcutImage()
        }
    }

    private func loadPendingShortcutImage() {
        if let image = PendingScreenshotStore.take() {
            appState.process(image)
        }
    }
}

private struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings
    @State private var photoItem: PhotosPickerItem?
    @State private var showsSetup = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                hero
                languageCard
                setupCard
                privacyNote
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Translate Screen")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showsSetup) {
            ShortcutSetupView()
        }
        .onChange(of: photoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                guard let data = try? await newValue.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                appState.process(image)
                photoItem = nil
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 104, height: 104)
                Image(systemName: "viewfinder")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(.blue)
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white, .blue)
                    .offset(x: 34, y: 34)
            }

            VStack(spacing: 8) {
                Text("Translate anything\nyou can see")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("Turn any screenshot into a translated screen in seconds.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Translate Screenshot", systemImage: "photo.badge.magnifyingglass")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.top, 8)
    }

    private var languageCard: some View {
        VStack(spacing: 0) {
            LanguageRow(title: "Source Language", selection: $settings.source, options: AppLanguage.sourceLanguages)
            Divider().padding(.leading, 54)
            LanguageRow(title: "Target Language", selection: $settings.target, options: AppLanguage.targetLanguages)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "button.programmable")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 42, height: 42)
                    .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Action Button Setup").font(.headline)
                    Text("Translate with one press").font(.subheadline).foregroundStyle(.secondary)
                }
            }

            Text("Use the Action Button to capture and translate whatever is on your screen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showsSetup = true
            } label: {
                Text("Set Up Shortcut")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 12))
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var privacyNote: some View {
        Label("Screenshots are read and translated on your device.", systemImage: "lock.shield.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }
}

private struct LanguageRow: View {
    let title: String
    @Binding var selection: AppLanguage
    let options: [AppLanguage]

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: selection.symbol)
                .foregroundStyle(.blue)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(selection.name).font(.body.weight(.medium))
            }
            Spacer()
            Menu {
                Picker(title, selection: $selection) {
                    ForEach(options) { language in
                        Text(language.name).tag(language)
                    }
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
        }
        .padding(16)
    }
}

private struct ProcessingView: View {
    let phase: AppState.Phase

    private var content: (String, String) {
        switch phase {
        case .reading: ("Reading screen…", "Finding text and its position")
        case .translating: ("Translating…", "Keeping the original layout")
        case .preparing: ("Preparing translation…", "Almost ready")
        default: ("Working…", "")
        }
    }

    var body: some View {
        VStack(spacing: 22) {
            ProgressView()
                .controlSize(.large)
                .tint(.blue)
            VStack(spacing: 6) {
                Text(content.0).font(.title3.weight(.semibold))
                Text(content.1).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

struct TranslationResultView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings
    @State private var showsOriginal = false
    @State private var selectedBlock: RecognizedBlock?
    @State private var showsAllText = false
    @State private var zoomScale: CGFloat = 1

    var body: some View {
        NavigationStack {
            Group {
                switch appState.phase {
                case .reading, .translating, .preparing:
                    ProcessingView(phase: appState.phase)
                case .failed(let message):
                    failureView(message)
                case .ready:
                    if let document = appState.document {
                        screenshot(document)
                    }
                case .idle:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .secondarySystemBackground))
            .navigationTitle(appState.phase == .ready ? settings.target.name : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { appState.closeResult() }
                }
                if appState.phase == .ready {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showsOriginal.toggle() }
                        } label: {
                            Image(systemName: showsOriginal ? "character.bubble" : "photo")
                        }
                        Button {
                            showsAllText = true
                        } label: {
                            Image(systemName: "text.alignleft")
                        }
                    }
                }
            }
        }
        .translationTask(appState.translationConfiguration) { session in
            await appState.translate(using: session)
        }
        .sheet(item: $selectedBlock) { block in
            TextDetailSheet(block: block, isRTL: settings.target.isRightToLeft)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showsAllText) {
            if let document = appState.document {
                AllTextView(document: document)
            }
        }
    }

    private func screenshot(_ document: TranslationDocument) -> some View {
        GeometryReader { proxy in
            let fitted = fittedRect(for: document.image.size, in: proxy.size)
            ZStack {
                Color.black.opacity(0.94)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: document.image)
                        .resizable()
                        .frame(width: fitted.width, height: fitted.height)

                    if !showsOriginal {
                        ForEach(document.blocks) { block in
                            OverlayTextView(
                                block: block,
                                canvasSize: fitted.size,
                                appearance: settings.appearance,
                                isRTL: settings.target.isRightToLeft,
                                onTap: { selectedBlock = block }
                            )
                        }
                    }
                }
                .frame(width: fitted.width, height: fitted.height)
                .scaleEffect(zoomScale)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in zoomScale = min(max(value.magnification, 1), 4) }
                        .onEnded { value in
                            withAnimation(.snappy) {
                                zoomScale = min(max(value.magnification, 1), 4)
                            }
                        }
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            Picker("View", selection: $showsOriginal) {
                Text("Translated").tag(false)
                Text("Original").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 42)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private func failureView(_ message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: message.contains("No text") ? "text.magnifyingglass" : "exclamationmark.triangle")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            HStack {
                if appState.document != nil {
                    Button("Try Again") { appState.retry() }.buttonStyle(.borderedProminent)
                    Button("View Original") {
                        appState.phase = .ready
                        showsOriginal = true
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Close") { appState.closeResult() }.buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(32)
    }

    private func fittedRect(for image: CGSize, in container: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0 else { return .zero }
        let scale = min(container.width / image.width, container.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
}

private struct OverlayTextView: View {
    let block: RecognizedBlock
    let canvasSize: CGSize
    let appearance: TranslationAppearance
    let isRTL: Bool
    let onTap: () -> Void
    @State private var revealsOriginal = false

    var body: some View {
        let rect = CGRect(
            x: block.boundingBox.minX * canvasSize.width,
            y: (1 - block.boundingBox.maxY) * canvasSize.height,
            width: max(block.boundingBox.width * canvasSize.width, 24),
            height: max(block.boundingBox.height * canvasSize.height, 14)
        )
        let text = revealsOriginal ? block.original : block.translation

        Text(text)
            .font(.system(size: max(8, min(rect.height * 0.68, 32)), weight: .semibold))
            .lineLimit(max(1, Int(rect.height / max(rect.height * 0.62, 9))))
            .minimumScaleFactor(0.42)
            .multilineTextAlignment(isRTL ? .trailing : .leading)
            .frame(width: rect.width, height: rect.height, alignment: isRTL ? .trailing : .leading)
            .foregroundStyle(foreground)
            .padding(.horizontal, appearance == .minimal ? 1 : 3)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: min(5, rect.height * 0.18)))
            .position(x: rect.midX, y: rect.midY)
            .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
            .onTapGesture(perform: onTap)
            .onLongPressGesture(minimumDuration: 0.12, pressing: { pressing in
                revealsOriginal = pressing
            }, perform: {})
            .accessibilityLabel("\(block.original), \(block.translation)")
    }

    private var foreground: Color {
        appearance == .readable ? .white : .primary
    }

    @ViewBuilder private var background: some View {
        switch appearance {
        case .natural:
            Rectangle().fill(.ultraThinMaterial)
        case .readable:
            Color.black.opacity(0.82)
        case .minimal:
            Color(uiColor: .systemBackground).opacity(0.72)
        }
    }
}

private struct TextDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let block: RecognizedBlock
    let isRTL: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Original") {
                    Text(block.original).textSelection(.enabled)
                    Button("Copy Original") { UIPasteboard.general.string = block.original }
                }
                Section("Translation") {
                    Text(block.translation)
                        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                        .textSelection(.enabled)
                    Button("Copy Translation") { UIPasteboard.general.string = block.translation }
                }
            }
            .navigationTitle("Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct AllTextView: View {
    @Environment(\.dismiss) private var dismiss
    let document: TranslationDocument

    var body: some View {
        NavigationStack {
            List {
                Section("Original") {
                    Text(document.originalText).textSelection(.enabled)
                }
                Section("Translated") {
                    Text(document.translatedText)
                        .textSelection(.enabled)
                        .environment(\.layoutDirection, document.target.isRightToLeft ? .rightToLeft : .leftToRight)
                }
            }
            .navigationTitle("All Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        UIPasteboard.general.string = document.translatedText
                    } label: {
                        Label("Copy Translation", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }
}
