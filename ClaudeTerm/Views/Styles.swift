import SwiftUI

// MARK: - Hover Button Style

/// macOS-idiomatic icon button style: subtle rounded background on hover, spring press animation.
struct HoverButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 4
    var padding: CGFloat = 4

    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.primary.opacity(isHovered ? 0.08 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Add Button Style

/// Dashed-border pill for "Add group" / "Add prompt" buttons.
struct AddButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primary.opacity(isHovered ? 0.04 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundColor(.secondary.opacity(isHovered ? 0.5 : 0.25))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Pulsing Modifier

struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 0.8)
            .opacity(isPulsing ? 1.0 : 0.5)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

extension View {
    func pulsing() -> some View {
        modifier(PulsingModifier())
    }
}

// MARK: - Hover Reveal System

private struct IsRowHoveredKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isRowHovered: Bool {
        get { self[IsRowHoveredKey.self] }
        set { self[IsRowHoveredKey.self] = newValue }
    }
}

/// Attach to a row container to track hover and propagate via environment.
struct HoverRevealModifier: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .environment(\.isRowHovered, isHovered)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

/// Makes a view visible only when its parent row is hovered.
struct VisibleOnRowHoverModifier: ViewModifier {
    @Environment(\.isRowHovered) private var isRowHovered

    func body(content: Content) -> some View {
        content
            .opacity(isRowHovered ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isRowHovered)
    }
}

extension View {
    func hoverReveal() -> some View {
        modifier(HoverRevealModifier())
    }

    func visibleOnRowHover() -> some View {
        modifier(VisibleOnRowHoverModifier())
    }
}
