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

// MARK: - Panel Tab Button Style

/// Pill-style tab button: active item gets a filled capsule, inactive items are plain text.
struct PanelTabButtonStyle: ButtonStyle {
    var isActive: Bool = false
    var activeColor: Color = .accentColor

    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Capsule()
                    .fill(
                        isActive
                            ? activeColor.opacity(0.2)
                            : (isHovered ? Color.primary.opacity(0.06) : Color.clear)
                    )
            )
            .foregroundColor(isActive ? .primary : .secondary)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

/// Wraps a row of PanelTabButtonStyle buttons in a rounded track background.
struct PillTabTrack<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 2) {
            content
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.06))
        )
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

/// Shared tracker that ensures only one row is "revealed" at a time.
@Observable
final class HoverRevealTracker {
    var activeRowId: UUID?
}

private struct HoverRevealTrackerKey: EnvironmentKey {
    static let defaultValue = HoverRevealTracker()
}

private struct IsRowHoveredKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var hoverRevealTracker: HoverRevealTracker {
        get { self[HoverRevealTrackerKey.self] }
        set { self[HoverRevealTrackerKey.self] = newValue }
    }

    var isRowHovered: Bool {
        get { self[IsRowHoveredKey.self] }
        set { self[IsRowHoveredKey.self] = newValue }
    }
}

/// Attach to a row container to track hover and propagate via environment.
/// Uses a shared tracker so only one row shows its revealed content at a time.
struct HoverRevealModifier: ViewModifier {
    @Environment(\.hoverRevealTracker) private var tracker
    private let rowId = UUID()

    private var isHovered: Bool { tracker.activeRowId == rowId }

    func body(content: Content) -> some View {
        content
            .environment(\.isRowHovered, isHovered)
            .onHover { hovering in
                if hovering {
                    tracker.activeRowId = rowId
                } else if tracker.activeRowId == rowId {
                    tracker.activeRowId = nil
                }
            }
    }
}

/// Makes a view visible only when its parent row is hovered.
/// Uses contentShape to keep the hit target active even when visually hidden.
struct VisibleOnRowHoverModifier: ViewModifier {
    @Environment(\.isRowHovered) private var isRowHovered

    func body(content: Content) -> some View {
        content
            .opacity(isRowHovered ? 1 : 0)
            .contentShape(Rectangle())
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
