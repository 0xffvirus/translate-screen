import SwiftUI

struct OnboardingView: View {
    let completion: () -> Void
    @State private var page = 0

    private let pages = [
        OnboardingPage(
            symbol: "rectangle.on.rectangle.angled",
            title: "Translate Anything",
            message: "Instantly translate text from any app on your iPhone.",
            color: .blue
        ),
        OnboardingPage(
            symbol: "button.programmable",
            title: "Press Your Action Button",
            message: "Use your iPhone Action Button to capture and translate your current screen.",
            color: .indigo
        ),
        OnboardingPage(
            symbol: "character.bubble.fill",
            title: "See the Translation",
            message: "Translated text appears directly over the original screenshot.",
            color: .teal
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pages.count - 1 {
                    Button("Skip") { completion() }
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 30) {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(item.color.opacity(0.12))
                                .frame(width: 180, height: 180)
                            Image(systemName: item.symbol)
                                .font(.system(size: 72, weight: .medium))
                                .foregroundStyle(item.color)
                                .symbolEffect(.breathe, options: .repeat(.periodic(delay: 2)))
                        }
                        VStack(spacing: 14) {
                            Text(item.title)
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            Text(item.message)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    completion()
                }
            } label: {
                Text(page == pages.count - 1 ? "Set Up Action Button" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemBackground))
    }
}

private struct OnboardingPage {
    let symbol: String
    let title: String
    let message: String
    let color: Color
}

struct ShortcutSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 112, height: 112)
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundStyle(.blue)
                        Image(systemName: "button.programmable")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.blue, in: Circle())
                            .offset(x: 39, y: 39)
                    }

                    VStack(spacing: 8) {
                        Text("Screenshot, then translate")
                            .font(.title2.bold())
                        Text("Create this two-action shortcut once. After that, the Action Button captures and translates the current screen automatically.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    ShortcutRecipeView()

                    VStack(spacing: 0) {
                        SetupStep(
                            number: 1,
                            title: "Create “Translate Screen”",
                            detail: "In Shortcuts, add the two actions shown above in that order."
                        )
                        Divider().padding(.leading, 58)
                        SetupStep(
                            number: 2,
                            title: "Choose it for Action Button",
                            detail: "Open Settings › Action Button › Shortcut, then select “Translate Screen”."
                        )
                    }
                    .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Button {
                        if let url = URL(string: "shortcuts://create-shortcut") { openURL(url) }
                    } label: {
                        Label("Create Screenshot Shortcut", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))

                    Label("No photo picker, If action, or separate Open action is needed.", systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Action Button Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct ShortcutRecipeView: View {
    var body: some View {
        VStack(spacing: 0) {
            ShortcutActionRow(
                icon: "camera.viewfinder",
                color: .gray,
                title: "Take Screenshot",
                detail: "Captures the current screen"
            )

            HStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 2, height: 24)
                    .padding(.leading, 31)
                Spacer()
            }

            ShortcutActionRow(
                icon: "character.bubble.fill",
                color: .blue,
                title: "Translate Screenshot",
                detail: "Screenshot"
            )
        }
        .padding(12)
        .background(Color.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Shortcut recipe: Take Screenshot, then Translate Screenshot")
    }
}

private struct ShortcutActionRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(14)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SetupStep: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.blue, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }
}
