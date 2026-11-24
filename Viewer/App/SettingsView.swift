import SwiftUI
import ViewerCore

/// Themes, fonts and text size.
struct SettingsView: View {
    @EnvironmentObject private var themes: ThemeStore
    @EnvironmentObject private var fonts: FontStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme") {
                    ForEach(themes.themes) { theme in
                        Button { themes.themeName = theme.name } label: { themeRow(theme) }
                            .buttonStyle(.plain)
                    }
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 12)], spacing: 12) {
                        swatch(nil, name: "Default")
                        ForEach(AccentCSS.presets, id: \.hex) { swatch($0.hex, name: $0.name) }
                    }
                    .padding(.vertical, 6)
                    ColorPicker("Custom color", selection: customAccent, supportsOpacity: false)
                } header: {
                    Text("Accent color")
                } footer: {
                    Text("Used for links, tags and the selected note, and for the widgets.")
                }

                Section {
                    Picker("Reading font", selection: Binding(get: { fonts.settings.bodyID }, set: { var s = fonts.settings; s.bodyID = $0; fonts.settings = s })) {
                        Text("Default").tag("")
                        ForEach(fonts.bodyChoices) { Text($0.displayName).tag($0.id) }
                    }
                    TextField("Or type a font name", text: Binding(get: { fonts.settings.customBody }, set: { var s = fonts.settings; s.customBody = $0; fonts.settings = s }))
                        .textInputAutocapitalization(.words).autocorrectionDisabled()
                    Picker("Code font", selection: Binding(get: { fonts.settings.codeID }, set: { var s = fonts.settings; s.codeID = $0; fonts.settings = s })) {
                        Text("Default").tag("")
                        ForEach(fonts.codeChoices) { Text($0.displayName).tag($0.id) }
                    }
                    TextField("Or type a font name", text: Binding(get: { fonts.settings.customCode }, set: { var s = fonts.settings; s.customCode = $0; fonts.settings = s }))
                        .textInputAutocapitalization(.words).autocorrectionDisabled()
                } header: {
                    Text("Fonts")
                } footer: {
                    Text("A typed name must be a font installed on this device. Nerd Font symbols show with the bundled fonts.")
                }

                Section("Text size") {
                    HStack {
                        Image(systemName: "textformat.size.smaller")
                        Slider(value: Binding(get: { themes.textScale }, set: { themes.textScale = $0 }), in: 0.7...2.0, step: 0.05)
                        Image(systemName: "textformat.size.larger")
                    }
                    Button("Reset") { themes.textScale = 1.0; themes.accentHex = ""; fonts.settings = FontSettings() }
                }
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    /// One round color choice; the chosen one has a ring and a check mark.
    private func swatch(_ hex: String?, name: String) -> some View {
        let selected = (hex ?? "") == (AccentCSS.normalized(themes.accentHex) ?? "")
        return Button { themes.accentHex = hex ?? "" } label: {
            ZStack {
                Circle().fill(hex.map { Color(hex: $0) } ?? Color(hex: "#0a84ff"))
                    .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                if hex == nil { Image(systemName: "sparkles").font(.caption).foregroundStyle(.white) }
                if selected { Image(systemName: "checkmark").font(.body.weight(.bold)).foregroundStyle(hex.map { AccentCSS.onAccentIsDark($0) } == true ? .black : .white) }
            }
            .frame(width: 36, height: 36)
            .padding(3)
            .overlay(Circle().stroke(selected ? Color.primary.opacity(0.7) : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var customAccent: Binding<Color> {
        Binding(get: { Color(hex: AccentCSS.normalized(themes.accentHex) ?? "#0a84ff") },
                set: { themes.accentHex = $0.hexString ?? "" })
    }

    private func themeRow(_ theme: ViewerTheme) -> some View {
        let dark = colorScheme == .dark
        return HStack(spacing: 12) {
            Text("Aa")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(hex: theme.accentHex(systemDark: dark)))
                .frame(width: 44, height: 30)
                .background(Color(hex: theme.backgroundHex(systemDark: dark)), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.35), lineWidth: 1))
            Text(theme.name)
            Spacer()
            if theme.name == themes.themeName { Image(systemName: "checkmark").foregroundStyle(.tint) }
        }
        .contentShape(Rectangle())
    }
}

extension Color {
    /// `#rrggbb`, or nil if the color cannot be read.
    var hexString: String? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        func byte(_ v: CGFloat) -> Int { Int((max(0, min(1, v)) * 255).rounded()) }
        return String(format: "#%02x%02x%02x", byte(r), byte(g), byte(b))
    }
}
