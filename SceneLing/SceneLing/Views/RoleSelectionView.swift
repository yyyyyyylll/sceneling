import SwiftUI

struct RoleSelectionView: View {
    let roles: [Role]
    let onConfirm: (Role, Role) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedUserRole: Role?
    @State private var selectedAIRole: Role?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                roleSection(
                    title: "选择你的角色",
                    selection: $selectedUserRole,
                    disabledRole: selectedAIRole
                )

                roleSection(
                    title: "选择AI角色",
                    selection: $selectedAIRole,
                    disabledRole: selectedUserRole
                )

                Spacer()

                Button {
                    if let userRole = selectedUserRole, let aiRole = selectedAIRole {
                        onConfirm(userRole, aiRole)
                        dismiss()
                    }
                } label: {
                    Text("开始对话")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canStart ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundStyle(canStart ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canStart)
            }
            .padding()
            .navigationTitle("选择角色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var canStart: Bool {
        guard let userRole = selectedUserRole, let aiRole = selectedAIRole else {
            return false
        }
        return userRole != aiRole
    }

    private func roleSection(
        title: String,
        selection: Binding<Role?>,
        disabledRole: Role?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            if roles.isEmpty {
                Text("暂无可用角色")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                    ForEach(roles, id: \.roleEn) { role in
                        let isSelected = selection.wrappedValue == role
                        let isDisabled = disabledRole == role
                        Button {
                            if isDisabled { return }
                            if isSelected {
                                selection.wrappedValue = nil
                            } else {
                                selection.wrappedValue = role
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(role.roleCn)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text(role.roleEn)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .padding(.horizontal, 8)
                            .background(isSelected ? Color.blue.opacity(0.15) : Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .opacity(isDisabled ? 0.4 : 1)
                        }
                        .disabled(isDisabled)
                    }
                }
            }
        }
    }
}

#Preview {
    RoleSelectionView(
        roles: [
            Role(roleEn: "Customer", roleCn: "顾客", sentences: []),
            Role(roleEn: "Barista", roleCn: "店员", sentences: []),
            Role(roleEn: "Friend", roleCn: "朋友", sentences: []),
            Role(roleEn: "Clerk", roleCn: "店员", sentences: [])
        ],
        onConfirm: { _, _ in }
    )
}
