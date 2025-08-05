import SwiftUI

struct SizeMeasuringViewModifier: ViewModifier {
    @Binding var size: CGSize
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self) { self.size = $0 }
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

extension View {
    func measure(_ size: Binding<CGSize>) -> some View {
        modifier(SizeMeasuringViewModifier(size: size))
    }
}

struct MarqueeText: View {
    var text: String
    var startDelay: Double = 1.0
    var maxWidth: Double? = nil
    var speed: Double = 30.0 // points/sec

    @State private var textSize: CGSize = .zero

    var body: some View {
        TheMarquee(
            forcedWidth: maxWidth,
            secsBeforeLooping: startDelay,
            speedPtsPerSec: speed,
            marqueeAlignment: .leading,
            nonMovingAlignment: .center,
            spacingBetweenElements: 8,
            horizontalPadding: 8,
            fadeLength: 8
        ) {
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .lineLimit(1)
                .measure($textSize)
        }
    }
}

struct TheMarquee<C: View>: View {
    var forcedWidth: Double?
    var secsBeforeLooping: Double = 0
    var speedPtsPerSec: Double = 30
    var marqueeAlignment: Alignment = .leading
    var nonMovingAlignment: Alignment = .center
    var spacingBetweenElements: Double = 8
    var horizontalPadding: Double = 8
    var fadeLength: Double = 8
    @ViewBuilder var content: () -> C
    @State private var contentSize: CGSize = .zero
    @State private var offset: Double = 0
    @State private var animating = false
    @State private var actualWidth: CGFloat = 0

    var measured: Bool { contentSize != .zero }

    var internalShouldMove: Bool {
        let displayRegionWidth = forcedWidth ?? actualWidth
        return measured && displayRegionWidth > 0 && contentSize.width > displayRegionWidth
    }

    private func updateAnimationState() {
        if internalShouldMove {
            if !animating {
                offset = 0
                startAnimation()
            }
        } else {
            if animating {
                animating = false
                offset = 0
            }
        }
    }

    func startAnimation() {
        if !internalShouldMove || animating { return }
        animating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + secsBeforeLooping) {
            if !animating { return }
            animLoop()
        }
    }

    func animLoop() {
        if !animating { return }
        let offsetAmount = contentSize.width + spacingBetweenElements
        let duration = offsetAmount / speedPtsPerSec

        withAnimation(.easeInOut(duration: duration)) {
            offset = -offsetAmount
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            if animating {
                offset = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + secsBeforeLooping) {
                    if animating {
                        animLoop()
                    }
                }
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let displayRegionWidth = forcedWidth ?? geo.size.width
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacingBetweenElements) {
                    content()
                        .measure($contentSize)
                    if measured && internalShouldMove {
                        content()
                    }
                }
                .padding(.horizontal, internalShouldMove ? horizontalPadding : 0)
                .frame(minWidth: internalShouldMove ? displayRegionWidth : nil, alignment: internalShouldMove ? marqueeAlignment : nonMovingAlignment)
                .offset(x: internalShouldMove ? offset : 0)
                .onChange(of: contentSize) { _ in updateAnimationState() }
                .onChange(of: displayRegionWidth) { _ in updateAnimationState() }
                .onAppear { actualWidth = geo.size.width; updateAnimationState() }
            }
            .disabled(true)
        }
        .frame(height: 22)
    }
}
