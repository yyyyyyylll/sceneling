import SwiftUI

struct CommunityPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "person.3.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue.opacity(0.5))

                Text("社区功能即将上线")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("敬请期待！")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    FeaturePreviewRow(icon: "square.and.arrow.up", text: "分享你的学习场景")
                    FeaturePreviewRow(icon: "heart", text: "发现他人的精彩内容")
                    FeaturePreviewRow(icon: "bubble.left.and.bubble.right", text: "与学友交流互动")
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("社区")
        }
    }
}

struct FeaturePreviewRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    CommunityPlaceholderView()
}
