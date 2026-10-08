import SwiftUI

/// Two buttons side by side; with a very large Dynamic Type size they stack instead of
/// squeezing the labels.
struct ButtonRow<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.medium) {
                leading
                trailing
            }
            VStack(spacing: Theme.Spacing.small) {
                trailing
                leading
            }
        }
    }
}

/// Scrolls its content when the text size is so large that it no longer fits the screen.
struct ScrollsAtAccessibilitySizes: ViewModifier {
    @Environment(\.dynamicTypeSize) private var size

    func body(content: Content) -> some View {
        if size.isAccessibilitySize {
            ScrollView { content }
                .scrollBounceBehavior(.basedOnSize)
        } else {
            content
        }
    }
}

extension View {
    func scrollsAtAccessibilitySizes() -> some View {
        modifier(ScrollsAtAccessibilitySizes())
    }
}
