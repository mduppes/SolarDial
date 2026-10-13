import CoreGraphics

public enum FullscreenGeometry {
    public struct Window: Equatable, Sendable {
        public var bounds: CGRect
        public var layer: Int

        public init(bounds: CGRect, layer: Int) {
            self.bounds = bounds
            self.layer = layer
        }
    }

    public struct Display: Equatable, Sendable {
        public var id: UInt32
        public var bounds: CGRect
        /// Height of the camera notch area, which full-screen windows sit below.
        public var topInset: CGFloat

        public init(id: UInt32, bounds: CGRect, topInset: CGFloat = 0) {
            self.id = id
            self.bounds = bounds
            self.topInset = topInset
        }
    }

    /// Displays whose topmost application window fills them.
    ///
    /// `windows` must be ordered front to back, as `CGWindowListCopyWindowInfo` returns them, and
    /// should already exclude desktop elements. Only `eligibleLayers` count as application windows,
    /// so the menu bar, Dock and floating panels are ignored.
    public static func fullscreenDisplays(
        windows: [Window], displays: [Display], eligibleLayers: Set<Int> = [0]
    ) -> Set<UInt32> {
        var result: Set<UInt32> = []
        for display in displays {
            let topmost = windows.first {
                eligibleLayers.contains($0.layer) && !$0.bounds.intersection(display.bounds).isEmpty
            }
            if let topmost, window(topmost.bounds, covers: display.bounds, topInset: display.topInset) {
                result.insert(display.id)
            }
        }
        return result
    }

    /// Whether `window` fills `display`. Both rects are in the same global, top-left-origin space
    /// (`kCGWindowBounds` and `CGDisplayBounds`).
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
