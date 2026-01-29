import SwiftUI
import SwiftData
import UIKit

struct SceneLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalScene.createdAt, order: .reverse) private var scenes: [LocalScene]

    @State private var searchText = ""
    @State private var showCamera = false
    @State private var showFilterPanel = false
    @StateObject private var filterState = FilterState()

    private let categories = ["全部", "日常", "学习", "旅行", "购物", "美食", "其他"]

    private var filteredScenes: [LocalScene] {
        var result = scenes

        // 分类筛选
        if filterState.selectedCategory != "全部" {
            result = result.filter { $0.category == filterState.selectedCategory }
        }

        // 时间筛选
        if let threshold = filterState.selectedTimeFilter.dateThreshold {
            result = result.filter { $0.createdAt >= threshold }
        }

        // 对话次数筛选
        result = result.filter { filterState.selectedDialogueFilter.matches(count: $0.dialogueCount) }

        // 搜索筛选
        if !searchText.isEmpty {
            result = result.filter {
                $0.sceneTag.localizedCaseInsensitiveContains(searchText) ||
                $0.sceneTagCn.contains(searchText)
            }
        }

        // 排序
        switch filterState.selectedSortOption {
        case .byTime:
            result = result.sorted { $0.createdAt > $1.createdAt }
        case .byDialogue:
            result = result.sorted { $0.dialogueCount > $1.dialogueCount }
        case .random:
            result = result.shuffled()
        }

        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()

                if scenes.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }

                // Right side floating buttons
                floatingButtons
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showCamera) {
                CameraView()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.Colors.textSecondary)

            Text("还没有场景")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("去拍一张吧！")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(AppTheme.Colors.textSecondary)

            Button {
                showCamera = true
            } label: {
                Text("去拍照")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.Colors.secondary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var contentView: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Category Filter
                categoryFilter
                    .padding(.top, 12)

                // Scenes Grid - 3 columns
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6)
                    ], spacing: 6) {
                        ForEach(filteredScenes) { scene in
                            NavigationLink(destination: SceneDetailView(scene: scene)) {
                                SceneLibraryCard(scene: scene)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }

            // Filter Panel Overlay
            if showFilterPanel {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showFilterPanel = false
                        }
                    }

                VStack {
                    Spacer()
                        .frame(height: 100) // Position below search and filter bar

                    FilterPanelView(
                        filterState: filterState,
                        categories: categories,
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showFilterPanel = false
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                    Spacer()
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Colors.textSecondary)

            TextField("搜索场景...", text: $searchText)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: AppTheme.Colors.cardShadow, radius: 2, y: 1)
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Filter button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showFilterPanel.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 12))
                        Text("筛选")
                            .font(.system(size: 12, design: .rounded))
                        if filterState.hasActiveFilters {
                            Circle()
                                .fill(Color(red: 0.68, green: 0.27, blue: 1))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .foregroundStyle(showFilterPanel ? Color(red: 0.68, green: 0.27, blue: 1) : AppTheme.Colors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(showFilterPanel ? Color(red: 0.68, green: 0.27, blue: 1).opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }

                // Quick category chips
                ForEach(categories.filter { $0 != "全部" }, id: \.self) { category in
                    CategoryChip(
                        title: category,
                        isSelected: category == filterState.selectedCategory
                    ) {
                        if filterState.selectedCategory == category {
                            filterState.selectedCategory = "全部"
                        } else {
                            filterState.selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var floatingButtons: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    // Button 1 - Grid view (placeholder)
                    FloatingActionButton(icon: "square.grid.2x2", color: Color.white) {
                        // TODO: Toggle grid view
                    }

                    // Button 2 - Translation (placeholder)
                    FloatingActionButton(icon: "character.book.closed", color: Color.white) {
                        // TODO: Translation feature
                    }

                    // Button 3 - AI Chat
                    FloatingActionButton(icon: "book.fill", color: Color(red: 0.32, green: 0.64, blue: 1)) {
                        // TODO: AI learning feature
                    }

                    // Button 4 - Camera
                    FloatingActionButton(icon: "sparkles", color: AppTheme.Colors.accent) {
                        showCamera = true
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, 100)
            }
        }
    }
}

struct FloatingActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color == .white ? AppTheme.Colors.textSecondary : .white)
                .frame(width: 48, height: 48)
                .background(color)
                .clipShape(Circle())
                .shadow(color: AppTheme.Colors.cardShadow, radius: 4, y: 2)
        }
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AppTheme.Colors.secondary : Color.white)
                .foregroundStyle(isSelected ? .white : AppTheme.Colors.textSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color(red: 0.90, green: 0.91, blue: 0.92), lineWidth: 0.5)
                )
        }
    }
}

struct SceneLibraryCard: View {
    @Bindable var scene: LocalScene
    @State private var showRoleSelection = false
    @State private var showChat = false
    @State private var selectedUserRole: Role?
    @State private var selectedAIRole: Role?
    @State private var pendingChatNavigation = false
    @State private var didStartChat = false  // 追踪是否开始了对话

    private var sceneContext: SceneAnalyzeResponse {
        SceneAnalyzeResponse(
            sceneTag: scene.sceneTag,
            sceneTagCn: scene.sceneTagCn,
            objectTags: scene.objectTags,
            description: Description(en: scene.descriptionEn, cn: scene.descriptionCn),
            expressions: scene.expressions,
            category: scene.category
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image with category badge
            ZStack(alignment: .topTrailing) {
                if let photoData = scene.photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 116, height: 128)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(red: 0.50, green: 0.23, blue: 0.27).opacity(0.50))
                        .frame(width: 116, height: 128)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                }

                // Category badge
                Text(scene.category)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(6)
            }

            // Title and chat button
            HStack(spacing: 8) {
                Text(scene.sceneTag)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                // Chat button
                Button {
                    showRoleSelection = true
                } label: {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.Colors.secondary)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .frame(width: 116)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .fullScreenCover(isPresented: $showRoleSelection) {
            RoleSelectionView(
                roles: scene.expressions.roles,
                onConfirm: { userRole, aiRole in
                    selectedUserRole = userRole
                    selectedAIRole = aiRole
                    pendingChatNavigation = true
                },
                sceneTag: scene.sceneTag,
                sceneTagCn: scene.sceneTagCn,
                category: scene.category,
                photoData: scene.photoData,
                createdAt: scene.createdAt
            )
        }
        .onChange(of: showRoleSelection) { oldValue, newValue in
            if oldValue == true && newValue == false && pendingChatNavigation {
                pendingChatNavigation = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showChat = true
                }
            }
        }
        .fullScreenCover(isPresented: $showChat) {
            if let userRole = selectedUserRole, let aiRole = selectedAIRole {
                ChatView(sceneContext: sceneContext, userRole: userRole, aiRole: aiRole)
                    .onAppear {
                        didStartChat = true
                    }
            } else {
                Text("加载中...")
                    .onAppear {
                        if selectedUserRole == nil || selectedAIRole == nil {
                            showChat = false
                        }
                    }
            }
        }
        .onChange(of: showChat) { oldValue, newValue in
            // 当对话结束时（showChat从true变为false），增加对话次数
            if oldValue == true && newValue == false && didStartChat {
                scene.incrementDialogueCount()
                didStartChat = false
            }
        }
    }
}

#Preview {
    SceneLibraryView()
}
