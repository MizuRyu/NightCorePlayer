import SwiftUI

/// 文字幅計測した値をMarqueeTextView全体に伝搬する
/// https://qiita.com/takehilo/items/2499c632c2e0e5cdcb06
private struct TextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// テキスト幅がvisibleWidthを超える場合、自動横スクロールするコンポーネント
struct MarqueeTextView: View {
    let text: String
    let font: Font
    let visibleWidth: CGFloat
    let speed: Double               // pt／秒
    let spacingBetweenTexts: CGFloat
    let delayBeforeScroll: Double   // 秒
    
    @State private var contentWidth: CGFloat = 0
    @State private var offsetX: CGFloat = 0
    @State private var isScrolling = false
    
    var body: some View {
        ZStack(alignment: .leading) {
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: TextWidthKey.self, value: geo.size.width)
                    }
                )
                .hidden()
            
            if contentWidth <= visibleWidth {
                // コンテナ内に収まる場合はそのままテキスト表示
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: visibleWidth, alignment: .center)
                
            } else {
                // 長い文字列である場合、スクロール対応
                HStack(spacing: spacingBetweenTexts) {
                    Text(text)
                        .font(font)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Text(text)
                        .font(font)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .offset(x: offsetX)
            }
        }
        // 3) 外側の ZStack を固定幅＋クリップして「はみ出し禁止」
        .frame(width: visibleWidth, alignment: .leading)
        .clipped()
        // テキストが変更されるたびに、contentWidth を更新＆状態リセット
        .onPreferenceChange(TextWidthKey.self) { newWidth in
            contentWidth = newWidth
            offsetX = 0
            isScrolling = false
        }
        // 5) 「幅オーバーかつ未開始」でループ発火
        .onChange(of: contentWidth) { _, newWidth in
            guard newWidth > visibleWidth, !isScrolling else { return }
            isScrolling = true
        }
        // delay → 左スクロール → reset を再帰的に実行
        .onAppear {
            guard contentWidth > visibleWidth else { return }
            let distance = contentWidth + spacingBetweenTexts
            let duration = distance / speed
            withAnimation(
                Animation.linear(duration: duration)
                    .delay(delayBeforeScroll)
                    .repeatForever(autoreverses: false)
            ) {
                offsetX = -distance
            }
        }
    }
}

