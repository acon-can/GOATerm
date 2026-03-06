import SwiftUI

struct TerminalNameEditor: View {
    @Binding var name: String
    @Binding var isEditing: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Terminal Name", text: $name)
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .focused($isFocused)
            .onSubmit {
                isEditing = false
            }
            .onExitCommand {
                isEditing = false
            }
            .onAppear {
                isFocused = true
            }
    }
}
