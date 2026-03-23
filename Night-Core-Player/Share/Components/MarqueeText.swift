import SwiftUI

/// https://qiita.com/takehilo/items/2499c632c2e0e5cdcb06
private struct TextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

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

    let selectedTab: PlayerNavigator.Tab
    
    init(
        text: String,
        font: Font = .body,
        idleTextAlignment: Alignment = .center,
        visibleWidth: CGFloat,
        speed: Double = Constants.MarqueeText.defaultSpeed,
        spacingBetweenTexts: CGFloat = Constants.MarqueeText.defaultSpacing,
        delayBeforeScroll: Double = Constants.MarqueeText.defaultDelay,
        selectedTab: PlayerNavigator.Tab = .player
    ) {
        self.text = text
        self.font = font
        self.idleTextAlignment = idleTextAlignment
        self.visibleWidth = visibleWidth
        self.speed = speed
        self.spacingBetweenTexts = spacingBetweenTexts
        self.delayBeforeScroll = delayBeforeScroll
        self.selectedTab = selectedTab
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
            let currentVisibleWidth = min(visibleWidth, geo.size.width)
            
            ZStack(alignment: .leading) {
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
                        Text(text).font(font).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                        Text(text).font(font).lineLimit(1).fixedSize()
                    }
                    .id("\(text)-\(selectedTab)")
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
                contentWidth = $0
            }
        }
    }
    
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
