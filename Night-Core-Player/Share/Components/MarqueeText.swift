import SwiftUI

/// 文字幅計測
/// https://qiita.com/takehilo/items/2499c632c2e0e5cdcb06
private struct TextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// テキスト幅が visibleWidth を超える場合、自動横スクロールするコンポーネント
/// 幅を超えなければ中央固定、超えたら3秒停止→リニアで左へエンドレススクロール
struct MarqueeText: View {
    let text: String
    let font: Font
    let idleTextAlignment: Alignment
    let visibleWidth: CGFloat
    let speed: Double               // pt／秒
    let spacingBetweenTexts: CGFloat
    let delayBeforeScroll: Double   // 秒
    
    @State private var contentWidth: CGFloat = 0
    @State private var isAnimating: Bool = false
    
    init(
        text: String,
        font: Font = .body,
        idleTextAlignment: Alignment = .center,
        visibleWidth: CGFloat,
        speed: Double = Constants.MarqueeText.defaultSpeed,
        spacingBetweenTexts: CGFloat = Constants.MarqueeText.defaultSpacing,
        delayBeforeScroll: Double = Constants.MarqueeText.defaultDelay
    ) {
        self.text = text
        self.font = font
        self.idleTextAlignment = idleTextAlignment
        self.visibleWidth = visibleWidth
        self.speed = speed
        self.spacingBetweenTexts = spacingBetweenTexts
        self.delayBeforeScroll = delayBeforeScroll
    }
    
    private var shouldScroll: Bool {
        contentWidth > visibleWidth
    }
    
    private var animationDuration: Double {
        guard shouldScroll, speed > 0 else { return 0 }
        return (contentWidth + spacingBetweenTexts) / speed
    }
    
    var body: some View {
        GeometryReader { geo in
            // 親 View の幅が visibleWidth より小さい場合に合わせる
            let currentVisibleWidth = min(visibleWidth, geo.size.width)
            
            ZStack(alignment: .leading) {
                // hidden でコンテンツ幅を計測
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        GeometryReader { g in
                            Color.clear
                                .preference(key: TextWidthKey.self,
                                            value: g.size.width)
                        }
                    )
                    .hidden()
                
                if shouldScroll {
                    HStack(spacing: spacingBetweenTexts) {
                        // 実際に流すテキスト
                        Text(text)
                            .font(font)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        // ループ用にコピーを並べる
                        Text(text)
                            .font(font)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .offset(x: isAnimating ? -(contentWidth + spacingBetweenTexts) : 0)
                    .frame(width: currentVisibleWidth, alignment: .leading)
                    .clipped()
                    .onAppear {
                        // 初回：リセットしてから1フレーム後に開始
                        isAnimating = false
                        DispatchQueue.main.async { isAnimating = true }
                    }
                    .onChange(of: contentWidth) { _, newWidth in
                        // 幅が計測され直したら再トリガ
                        guard newWidth > visibleWidth else { return }
                        isAnimating = false
                        DispatchQueue.main.async { isAnimating = true }
                    }
                    .animation(
                        Animation.linear(duration: animationDuration)
                            .delay(delayBeforeScroll)      // 3秒停止
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                } else {
                    // 幅内に収まる場合、アイドル状態の場合
                    Text(text)
                        .font(font)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(width: currentVisibleWidth, alignment: idleTextAlignment)
                }
            }
            .id(text)
            .frame(maxHeight: .infinity, alignment: .center)
            .clipped()
            .onPreferenceChange(TextWidthKey.self) { newWidth in
                // 計測結果を受け取って状態更新
                contentWidth = newWidth
            }
            .onChange(of: text) { _, _ in
                // テキスト変更時はリセット
                contentWidth = 0
                isAnimating = false
            }
        }
    }
}
