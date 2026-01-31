import SwiftUI
import UIKit

struct RoleSelectionView: View {
    let roles: [Role]
    let onConfirm: (Role, Role) -> Void
    var sceneTag: String = ""
    var sceneTagCn: String = ""
    var category: String = ""
    var photoData: Data? = nil
    var createdAt: Date = Date()

    @Environment(\.dismiss) private var dismiss
    @State private var selectedUserRole: Role?
    @State private var selectedAIRole: Role?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scene info card
                if !sceneTag.isEmpty {
                    sceneInfoCard
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // User role section
                        roleSection(
                            title: "选择你的角色",
                            subtitle: "你将扮演这个角色进行对话",
                            selection: $selectedUserRole,
                            disabledRole: selectedAIRole,
                            isUserRole: true
                        )

                        // AI role section
                        roleSection(
                            title: "选择AI角色",
                            subtitle: "AI将扮演这个角色与你对话",
                            selection: $selectedAIRole,
                            disabledRole: selectedUserRole,
                            isUserRole: false
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }

                // Bottom button
                bottomButton
            }
            .background(AppTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color(red: 0.95, green: 0.96, blue: 0.96))
                        .clipShape(Circle())
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("选择角色")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
            }
        }
    }

    private var sceneInfoCard: some View {
        HStack(spacing: 12) {
            // Scene image
            if let photoData = photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.50, green: 0.23, blue: 0.27).opacity(0.50))
                    .frame(width: 64, height: 64)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(sceneTag.replacingOccurrences(of: "_", with: " "))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Text(category)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.98, green: 0.96, blue: 1))
                        .clipShape(Capsule())
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text("拍摄于 \(formattedDate)")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 0.90, green: 0.91, blue: 0.92), lineWidth: 0.5)
        )
        .shadow(color: AppTheme.Colors.cardShadow, radius: 2, y: 1)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: createdAt)
    }

    private var canStart: Bool {
        guard let userRole = selectedUserRole, let aiRole = selectedAIRole else {
            return false
        }
        return userRole != aiRole
    }

    private func roleSection(
        title: String,
        subtitle: String,
        selection: Binding<Role?>,
        disabledRole: Role?,
        isUserRole: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.21, green: 0.26, blue: 0.32))

            Text(subtitle)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(AppTheme.Colors.textSecondary)

            if roles.isEmpty {
                Text("暂无可用角色")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .padding(.top, 8)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(roles, id: \.roleEn) { role in
                        let isSelected = selection.wrappedValue == role
                        let isDisabled = disabledRole == role

                        RoleCard(
                            role: role,
                            isSelected: isSelected,
                            isDisabled: isDisabled,
                            isUserRole: isUserRole
                        ) {
                            if isDisabled { return }
                            if isSelected {
                                selection.wrappedValue = nil
                            } else {
                                selection.wrappedValue = role
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var bottomButton: some View {
        VStack {
            Button {
                if let userRole = selectedUserRole, let aiRole = selectedAIRole {
                    // Call onConfirm first, then dismiss
                    onConfirm(userRole, aiRole)
                    dismiss()
                }
            } label: {
                Text("开始对话")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canStart ? AppTheme.Colors.secondary : Color.gray.opacity(0.3))
                    .foregroundStyle(canStart ? .white : AppTheme.Colors.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canStart)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.white.opacity(0.9))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color(red: 0.90, green: 0.91, blue: 0.92).opacity(0.5)),
            alignment: .top
        )
    }
}

struct RoleCard: View {
    let role: Role
    let isSelected: Bool
    let isDisabled: Bool
    let isUserRole: Bool
    let action: () -> Void

    private var selectedColor: Color {
        isUserRole ? AppTheme.Colors.secondary : AppTheme.Colors.accent
    }

    private var selectedBackground: Color {
        isUserRole ? Color(red: 0.98, green: 0.96, blue: 1) : Color(red: 0.99, green: 0.95, blue: 0.97)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(role.roleCn)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.22))

                Text(role.roleEn.replacingOccurrences(of: "_", with: " "))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(isSelected ? selectedBackground : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? selectedColor : Color(red: 0.90, green: 0.91, blue: 0.92), lineWidth: isSelected ? 1 : 0.5)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(selectedColor)
                        .clipShape(Circle())
                        .padding(8)
                }
            }
            .opacity(isDisabled ? 0.4 : 1)
        }
        .disabled(isDisabled)
    }
}

#Preview {
    RoleSelectionView(
        roles: [
            Role(roleEn: "Customer", roleCn: "顾客", sentences: []),
            Role(roleEn: "Barista", roleCn: "咖啡师", sentences: []),
            Role(roleEn: "Friend", roleCn: "朋友", sentences: []),
            Role(roleEn: "Clerk", roleCn: "店员", sentences: [])
        ],
        onConfirm: { _, _ in },
        sceneTag: "Coffee Shop",
        sceneTagCn: "咖啡店",
        category: "日常",
        createdAt: Date()
    )
}
