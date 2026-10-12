import CoreGraphics

public enum FullscreenGeometry {
    /// Whether `window` fills `display`. Both rects are in the same global, top-left-origin space
    /// (`kCGWindowBounds` and `CGDisplayBounds`). `topInset` allows for the camera notch, which
    /// full-screen windows sit below.
    public static func window(
        _ window: CGRect, covers display: CGRect, topInset: CGFloat = 0, tolerance: CGFloat = 2
    ) -> Bool {
        guard display.width > 0, display.height > 0 else { return false }
        return window.minX <= display.minX + tolerance
            && window.maxX >= display.maxX - tolerance
            && window.maxY >= display.maxY - tolerance
            && window.minY <= display.minY + topInset + tolerance
    }
}
