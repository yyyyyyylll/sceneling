import SwiftUI
import Combine

// MARK: - Filter Options

enum TimeFilter: String, CaseIterable {
    case all = "全部时间"
    case week = "7天内"
    case month = "30天内"
    case threeMonths = "3个月内"
    case halfYear = "半年内"

    var dateThreshold: Date? {
        let calendar = Calendar.current
        switch self {
        case .all: return nil
        case .week: return calendar.date(byAdding: .day, value: -7, to: Date())
        case .month: return calendar.date(byAdding: .day, value: -30, to: Date())
        case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: Date())
        case .halfYear: return calendar.date(byAdding: .month, value: -6, to: Date())
        }
    }
}

enum DialogueFilter: String, CaseIterable {
    case all = "全部"
    case none = "未对话"
    case oneToFive = "1-5次"
    case fiveToTen = "5-10次"
    case moreThanTen = "10次以上"

    func matches(count: Int) -> Bool {
        switch self {
        case .all: return true
        case .none: return count == 0
        case .oneToFive: return count >= 1 && count <= 5
        case .fiveToTen: return count > 5 && count <= 10
        case .moreThanTen: return count > 10
        }
    }
}

enum SortOption: String, CaseIterable {
    case byTime = "按时间"
    case byDialogue = "按对话次数"
    case random = "随机排序"
}

// MARK: - Filter State

class FilterState: ObservableObject {
    @Published var selectedCategory: String = "全部"
    @Published var selectedTimeFilter: TimeFilter = .all
    @Published var selectedDialogueFilter: DialogueFilter = .all
    @Published var selectedSortOption: SortOption = .byTime

    var hasActiveFilters: Bool {
        selectedCategory != "全部" ||
        selectedTimeFilter != .all ||
        selectedDialogueFilter != .all ||
        selectedSortOption != .byTime
    }

    func reset() {
        selectedCategory = "全部"
        selectedTimeFilter = .all
        selectedDialogueFilter = .all
        selectedSortOption = .byTime
    }
}

// MARK: - Filter Panel View

struct FilterPanelView: View {
    @ObservedObject var filterState: FilterState
    let categories: [String]
    let onDismiss: () -> Void

    private let accentColor = Color(red: 0.68, green: 0.27, blue: 1)  // 紫色
    private let chipBackground = Color(red: 0.95, green: 0.96, blue: 0.96)
    private let textColor = Color(red: 0.29, green: 0.33, blue: 0.40)
    private let labelColor = Color(red: 0.44, green: 0.44, blue: 0.51)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 场景分类
            filterSection(title: "场景分类") {
                FlowLayout(spacing: 8) {
                    FilterChip(
                        title: "全部",
                        isSelected: filterState.selectedCategory == "全部",
                        accentColor: accentColor,
                        chipBackground: chipBackground,
                        textColor: textColor
                    ) {
                        filterState.selectedCategory = "全部"
                    }

                    ForEach(categories.filter { $0 != "全部" }, id: \.self) { category in
                        FilterChip(
                            title: category,
                            isSelected: filterState.selectedCategory == category,
                            accentColor: accentColor,
                            chipBackground: chipBackground,
                            textColor: textColor
                        ) {
                            filterState.selectedCategory = category
                        }
                    }
                }
            }

            // 时间筛选
            filterSection(title: "时间筛选") {
                FlowLayout(spacing: 8) {
                    ForEach(TimeFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.rawValue,
                            isSelected: filterState.selectedTimeFilter == filter,
                            accentColor: accentColor,
                            chipBackground: chipBackground,
                            textColor: textColor
                        ) {
                            filterState.selectedTimeFilter = filter
                        }
                    }
                }
            }

            // 对话次数
            filterSection(title: "对话次数") {
                FlowLayout(spacing: 8) {
                    ForEach(DialogueFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.rawValue,
                            isSelected: filterState.selectedDialogueFilter == filter,
                            accentColor: accentColor,
                            chipBackground: chipBackground,
                            textColor: textColor
                        ) {
                            filterState.selectedDialogueFilter = filter
                        }
                    }
                }
            }

            // 排序方式
            filterSection(title: "排序方式") {
                FlowLayout(spacing: 8) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        FilterChip(
                            title: option.rawValue,
                            isSelected: filterState.selectedSortOption == option,
                            accentColor: accentColor,
                            chipBackground: chipBackground,
                            textColor: textColor
                        ) {
                            filterState.selectedSortOption = option
                        }
                    }
                }
            }

            // 底部按钮
            HStack(spacing: 12) {
                // 重置按钮
                Button {
                    filterState.reset()
                } label: {
                    Text("重置")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(chipBackground)
                        .cornerRadius(8)
                }

                // 确定按钮
                Button {
                    onDismiss()
                } label: {
                    Text("确定")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(accentColor)
                        .cornerRadius(8)
                }
            }
            .padding(.top, 8)
        }
        .padding(13)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.10), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 4, y: 2)
    }

    private func filterSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(labelColor)

            content()
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let accentColor: Color
    let chipBackground: Color
    let textColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .white : textColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? accentColor : chipBackground)
                .cornerRadius(10)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))

            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

#Preview {
    FilterPanelView(
        filterState: FilterState(),
        categories: ["全部", "日常", "学习", "旅行", "购物", "美食", "其他"],
        onDismiss: {}
    )
    .padding()
    .background(Color.gray.opacity(0.2))
}
