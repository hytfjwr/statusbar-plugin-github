import SwiftUI

/// GitHub brand marks drawn as vector shapes so they tint via `foregroundStyle`
/// like SF Symbols — no bundled image resources needed in the dylib.
enum GitHubMarkStyle {
    /// Official mark: Octocat silhouette knocked out of a solid circle.
    case badge
    /// Invertocat: just the cat silhouette — lighter visual weight at bar size.
    case cat
}

/// Path data adapted from the octicons `mark-github-16` glyph (MIT).
struct GitHubMarkShape: Shape {
    var style: GitHubMarkStyle = .badge

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 16
        var path = Path()
        path.move(to: CGPoint(x: 6.766, y: 11.33))
        path.addCurve(to: CGPoint(x: 3.25, y: 7.672), control1: CGPoint(x: 4.703, y: 11.08), control2: CGPoint(x: 3.25, y: 9.594))
        path.addCurve(to: CGPoint(x: 4, y: 5.484), control1: CGPoint(x: 3.25, y: 6.891), control2: CGPoint(x: 3.531, y: 6.047))
        path.addCurve(to: CGPoint(x: 4.063, y: 3.422), control1: CGPoint(x: 3.797, y: 4.969), control2: CGPoint(x: 3.828, y: 3.875))
        path.addCurve(to: CGPoint(x: 6.031, y: 4.125), control1: CGPoint(x: 4.688, y: 3.344), control2: CGPoint(x: 5.531, y: 3.672))
        path.addCurve(to: CGPoint(x: 8.016, y: 3.844), control1: CGPoint(x: 6.625, y: 3.938), control2: CGPoint(x: 7.25, y: 3.844))
        path.addCurve(to: CGPoint(x: 9.969, y: 4.109), control1: CGPoint(x: 8.781, y: 3.844), control2: CGPoint(x: 9.406, y: 3.938))
        path.addCurve(to: CGPoint(x: 11.94, y: 3.422), control1: CGPoint(x: 10.45, y: 3.672), control2: CGPoint(x: 11.31, y: 3.344))
        path.addCurve(to: CGPoint(x: 11.98, y: 5.469), control1: CGPoint(x: 12.16, y: 3.844), control2: CGPoint(x: 12.19, y: 4.937))
        path.addCurve(to: CGPoint(x: 12.75, y: 7.672), control1: CGPoint(x: 12.48, y: 6.062), control2: CGPoint(x: 12.75, y: 6.859))
        path.addCurve(to: CGPoint(x: 9.203, y: 11.31), control1: CGPoint(x: 12.75, y: 9.594), control2: CGPoint(x: 11.3, y: 11.05))
        path.addCurve(to: CGPoint(x: 10.09, y: 13.27), control1: CGPoint(x: 9.734, y: 11.66), control2: CGPoint(x: 10.09, y: 12.41))
        path.addLine(to: CGPoint(x: 10.09, y: 14.89))
        path.addCurve(to: CGPoint(x: 10.95, y: 15.44), control1: CGPoint(x: 10.09, y: 15.36), control2: CGPoint(x: 10.48, y: 15.62))
        path.addCurve(to: CGPoint(x: 16, y: 8.03), control1: CGPoint(x: 13.78, y: 14.36), control2: CGPoint(x: 16, y: 11.53))
        path.addCurve(to: CGPoint(x: 7.984, y: 0), control1: CGPoint(x: 16, y: 3.61), control2: CGPoint(x: 12.41, y: 0))
        path.addCurve(to: CGPoint(x: 0, y: 8.031), control1: CGPoint(x: 3.563, y: 0), control2: CGPoint(x: 0, y: 3.61))
        path.addCurve(to: CGPoint(x: 5.172, y: 15.45), control1: CGPoint(x: -0.00922, y: 11.35), control2: CGPoint(x: 2.058, y: 14.31))
        path.addCurve(to: CGPoint(x: 6, y: 14.91), control1: CGPoint(x: 5.594, y: 15.61), control2: CGPoint(x: 6, y: 15.33))
        path.addLine(to: CGPoint(x: 6, y: 13.66))
        path.addCurve(to: CGPoint(x: 5.25, y: 13.81), control1: CGPoint(x: 5.781, y: 13.75), control2: CGPoint(x: 5.5, y: 13.81))
        path.addCurve(to: CGPoint(x: 3.172, y: 12.2), control1: CGPoint(x: 4.219, y: 13.81), control2: CGPoint(x: 3.61, y: 13.25))
        path.addCurve(to: CGPoint(x: 2.453, y: 11.48), control1: CGPoint(x: 3, y: 11.78), control2: CGPoint(x: 2.812, y: 11.53))
        path.addCurve(to: CGPoint(x: 2.203, y: 11.3), control1: CGPoint(x: 2.266, y: 11.47), control2: CGPoint(x: 2.203, y: 11.39))
        path.addCurve(to: CGPoint(x: 2.828, y: 10.97), control1: CGPoint(x: 2.203, y: 11.11), control2: CGPoint(x: 2.516, y: 10.97))
        path.addCurve(to: CGPoint(x: 4.078, y: 11.83), control1: CGPoint(x: 3.281, y: 10.97), control2: CGPoint(x: 3.672, y: 11.25))
        path.addCurve(to: CGPoint(x: 5.109, y: 12.48), control1: CGPoint(x: 4.391, y: 12.28), control2: CGPoint(x: 4.718, y: 12.48))
        path.addCurve(to: CGPoint(x: 6.109, y: 11.98), control1: CGPoint(x: 5.5, y: 12.48), control2: CGPoint(x: 5.75, y: 12.34))
        path.addCurve(to: CGPoint(x: 6.766, y: 11.33), control1: CGPoint(x: 6.375, y: 11.72), control2: CGPoint(x: 6.579, y: 11.48))
        if style == .cat {
            // Filling even-odd with an extra copy of the outer circle leaves
            // only the knocked-out silhouette: just the cat.
            path.addEllipse(in: CGRect(x: 0, y: 0.03, width: 16, height: 16))
        }
        return path.applying(CGAffineTransform(scaleX: scale, y: scale))
    }

    var fillStyle: FillStyle { FillStyle(eoFill: style == .cat) }
}
