import SwiftUI
import AppKit

/// Keep navigation above a native material; the form uses the standard content background.
struct SettingsNavigationPane<Content: View>: NSViewRepresentable {
    let material: String
    @ViewBuilder let content: () -> Content
    func makeNSView(context: Context) -> MaterialSurface {
        let surface = MaterialSurface(cornerRadius: 0)
        surface.appearance = Preferences.shared.appearance
        surface.updateMaterial(material)
        let hosting = NSHostingView(rootView: content())
        hosting.frame = surface.content.bounds
        hosting.autoresizingMask = [.width, .height]
        surface.content.addSubview(hosting)
        return surface
    }
    func updateNSView(_ surface: MaterialSurface, context: Context) {
        surface.appearance = Preferences.shared.appearance
        surface.updateMaterial(material)
        (surface.content.subviews.first as? NSHostingView<Content>)?.rootView = content()
    }
}

struct ThemeChoice: View {
    let value: String
    let title: String
    @Binding var selection: String
    var body: some View {
        Button { selection = value } label: {
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        miniature(dark: value == "dark")
                        if value == "system" { miniature(dark: true) }
                    }.frame(width: geometry.size.width, height: geometry.size.height)
                }.frame(height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selection == value ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: selection == value ? 2 : 1))
                HStack(spacing: 4) {
                    Image(systemName: selection == value ? "checkmark.circle.fill" : "circle").foregroundStyle(selection == value ? Color.accentColor : .secondary)
                    Text(title).foregroundStyle(.primary)
                }.font(.caption)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(title)
            .accessibilityAddTraits(selection == value ? .isSelected : [])
    }
    private func miniature(dark: Bool) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 2) { ForEach(0..<3) { _ in Circle().fill(Color.gray.opacity(0.45)).frame(width: 3, height: 3) } }.padding(.bottom, 4)
                RoundedRectangle(cornerRadius: 2).fill(Color.accentColor.opacity(0.75)).frame(height: 5)
                RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.3)).frame(height: 4)
                RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.3)).frame(height: 4)
                Spacer(minLength: 0)
            }.padding(7).frame(maxWidth: 40).background(dark ? Color(white: 0.19) : Color(white: 0.88))
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(dark ? Color.white.opacity(0.75) : Color.black.opacity(0.5)).frame(width: 22, height: 4)
                RoundedRectangle(cornerRadius: 3).fill(dark ? Color(white: 0.27) : .white).frame(height: 13)
                RoundedRectangle(cornerRadius: 3).fill(dark ? Color(white: 0.27) : .white).frame(height: 13)
            }.padding(8).frame(maxWidth: .infinity, maxHeight: .infinity).background(dark ? Color(white: 0.13) : Color(white: 0.96))
        }.accessibilityHidden(true)
    }
}
