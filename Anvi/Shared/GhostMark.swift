import SwiftUI

/// The Anvi ghost. Geometry is defined on a 100 × 110 grid, plus the orbiting dot to the
/// top-right. The app icon uses the same shape.
struct GhostShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width / 122, rect.height / 122)
        let origin = CGPoint(x: rect.midX - 61 * s, y: rect.midY - 62 * s)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: origin.x + x * s, y: origin.y + (y + 10) * s) }

        var path = Path()
        path.move(to: p(0, 70))
        path.addLine(to: p(0, 12))
        path.addCurve(to: p(10, 0), control1: p(0, 4), control2: p(4, 0))
        path.addCurve(to: p(32, 8), control1: p(18, 0), control2: p(24, 8))
        path.addLine(to: p(80, 8))
        path.addQuadCurve(to: p(100, 28), control: p(100, 8))
        path.addLine(to: p(100, 70))
        path.addCurve(to: p(50, 110), control1: p(100, 96), control2: p(80, 110))
        path.addCurve(to: p(0, 70), control1: p(20, 110), control2: p(0, 96))
        path.closeSubpath()
        return path
    }

    /// Eye and dot positions on the same grid, for drawing on top of the body.
    static let leftEye = CGPoint(x: 34, y: 62)
    static let rightEye = CGPoint(x: 70, y: 62)
    static let eyeRadius: CGFloat = 10
    static let dot = CGPoint(x: 114, y: 2)
    static let dotRadius: CGFloat = 8
}

/// The ghost with eyes and its orbiting dot.
struct GhostMark: View {
    var bodyColor: Color = .accentColor
    var eyeColor: Color = Color(nsColor: .windowBackgroundColor)
    var size: CGFloat = 96

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
            context.fill(GhostShape().path(in: rect), with: .color(bodyColor))

            let s = min(rect.width / 122, rect.height / 122)
            let origin = CGPoint(x: rect.midX - 61 * s, y: rect.midY - 62 * s)
            func point(_ q: CGPoint) -> CGPoint { CGPoint(x: origin.x + q.x * s, y: origin.y + (q.y + 10) * s) }
            func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            }

            for eye in [GhostShape.leftEye, GhostShape.rightEye] {
                let center = point(eye)
                context.fill(circle(center, GhostShape.eyeRadius * s), with: .color(eyeColor))
                let glint = CGPoint(x: center.x + 3 * s, y: center.y - 3.5 * s)
                context.fill(circle(glint, 3 * s), with: .color(bodyColor))
            }
            context.fill(circle(point(GhostShape.dot), GhostShape.dotRadius * s), with: .color(bodyColor))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Centered mascot, title, message and optional actions for empty screens.
struct EmptyStateView<Actions: View>: View {
    var title: LocalizedStringKey
    var message: LocalizedStringKey
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 14) {
            GhostMark(size: 88)
                .padding(.bottom, 6)
            Text(title)
                .font(.title2.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            HStack { actions }
                .padding(.top, 6)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    GhostMark(size: 200).padding()
}
