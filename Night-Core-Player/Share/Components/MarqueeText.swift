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

    @EnvironmentObject private var nav: PlayerNavigator
    
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
                        Text(text).font(font).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                        // ループ用にコピーを並べる
                        Text(text).font(font).lineLimit(1).fixedSize()
                    }
                    .id("\(text)-\(nav.selectedTab)") // tab切り替えでアニメーションがリセットされるように
                    .offset(x: isAnimating ? -(contentWidth + spacingBetweenTexts) : 0)
                    .frame(width: currentVisibleWidth, alignment: .leading)
                    .clipped()
                    .onAppear {
                        restartAnimation()
                    }
                    .onChange(of: contentWidth) {
                        restartAnimation()
                    }
                    .onChange(of: text) {
                        contentWidth = 0
                    }
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
            .onPreferenceChange(TextWidthKey.self) {
                // 計測結果を受け取って状態更新
                contentWidth = $0
            }
        }
    }
    
    // アニメーションがリセットするように、一度offにしてから開始する
    private func restartAnimation() {
        guard contentWidth > visibleWidth, speed > 0 else { return }
        withAnimation(.none) {
            isAnimating = false
        }
        DispatchQueue.main.async {
            withAnimation(
                Animation.linear(duration: animationDuration)
                    .delay(delayBeforeScroll)
                    .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
}
