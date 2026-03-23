import SwiftUI

struct TermsView: View {
    private let markdownContent: String

    init() {
        if let url = Bundle.main.url(forResource: "terms", withExtension: "md"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            self.markdownContent = content
        } else {
            self.markdownContent = "利用規約を読み込めませんでした。"
        }
    }

    var body: some View {
        ScrollView {
            Text(LocalizedStringKey(markdownContent))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("利用規約・プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}
