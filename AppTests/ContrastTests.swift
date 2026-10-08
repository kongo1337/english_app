import Testing
import UIKit

@testable import EnglishCards

/// WCAG contrast of the design tokens, light and dark. The automatic accessibility audit
/// samples pixels and is too noisy for this, so the colours themselves are checked.
private let styles: [UIUserInterfaceStyle] = [.light, .dark]

@Suite struct ContrastTests {
    private func color(_ name: String, _ style: UIUserInterfaceStyle) throws -> UIColor {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let dynamic = try #require(UIColor(named: name, in: .main, compatibleWith: traits), "missing colour \(name)")
        return dynamic.resolvedColor(with: traits)
    }

    private func luminance(_ color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ value: CGFloat) -> Double {
            let v = Double(value)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    private func contrast(_ a: UIColor, _ b: UIColor) -> Double {
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    /// `foreground` at `alpha` over `background`.
    private func blend(_ foreground: UIColor, over background: UIColor, alpha: CGFloat) -> UIColor {
        var f: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var b: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        foreground.getRed(&f.0, green: &f.1, blue: &f.2, alpha: &f.3)
        background.getRed(&b.0, green: &b.1, blue: &b.2, alpha: &b.3)
        return UIColor(
            red: f.0 * alpha + b.0 * (1 - alpha), green: f.1 * alpha + b.1 * (1 - alpha),
            blue: f.2 * alpha + b.2 * (1 - alpha), alpha: 1)
    }

    @Test(arguments: styles) func bodyTextReadsOnEverySurface(style: UIUserInterfaceStyle) throws {
        for text in ["TextPrimary", "TextSecondary"] {
            for surface in ["Bg", "Surface", "SurfaceMuted"] {
                let ratio = contrast(try color(text, style), try color(surface, style))
                #expect(ratio >= 4.5, "\(text) on \(surface) (\(style.rawValue)): \(ratio)")
            }
        }
    }

    @Test(arguments: styles) func statusColoursReadAsText(style: UIUserInterfaceStyle) throws {
        for text in ["Success", "Warning"] {
            for surface in ["Bg", "Surface"] {
                let ratio = contrast(try color(text, style), try color(surface, style))
                #expect(ratio >= 4.5, "\(text) on \(surface) (\(style.rawValue)): \(ratio)")
            }
        }
    }

    @Test(arguments: styles) func levelChipsReadOnTheirOwnTint(style: UIUserInterfaceStyle) throws {
        for level in ["LevelA1", "LevelA2", "LevelB1", "LevelB2", "LevelC1"] {
            let text = try color(level, style)
            for surface in ["Bg", "Surface"] {
                let chip = blend(text, over: try color(surface, style), alpha: 0.14)
                let ratio = contrast(text, chip)
                #expect(ratio >= 4.5, "\(level) on \(surface) (\(style.rawValue)): \(ratio)")
            }
        }
    }

    @Test(arguments: styles) func primaryButtonLabelIsReadable(style: UIUserInterfaceStyle) throws {
        // 20 pt semibold counts as large text: 3 : 1 is enough.
        let ratio = contrast(.white, try color("Accent", style))
        #expect(ratio >= 3.0, "white on Accent (\(style.rawValue)): \(ratio)")
    }

    @Test(arguments: styles) func accentIsVisibleOnTheBackground(style: UIUserInterfaceStyle) throws {
        for surface in ["Bg", "Surface"] {
            let ratio = contrast(try color("Accent", style), try color(surface, style))
            #expect(ratio >= 4.5, "Accent on \(surface) (\(style.rawValue)): \(ratio)")
        }
    }
}
