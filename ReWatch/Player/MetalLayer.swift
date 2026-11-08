import QuartzCore

/// The surface mpv draws video onto (through MoltenVK, which runs mpv's
/// Vulkan renderer on top of Metal). Both overrides are workarounds from
/// MPVKit's demo for MoltenVK bugs, kept as-is.
final class MetalLayer: CAMetalLayer {

    // MoltenVK sometimes shrinks the drawable to 1x1 to force a frame out.
    // That shows as flicker, and the size can get stuck there. Ignore it.
    // https://github.com/mpv-player/mpv/pull/13651
    override var drawableSize: CGSize {
        get { super.drawableSize }
        set {
            if Int(newValue.width) > 1 && Int(newValue.height) > 1 {
                super.drawableSize = newValue
            }
        }
    }

    // HDR: this flag only takes effect when set on the main thread, but mpv
    // sets it from its render thread.
    override var wantsExtendedDynamicRangeContent: Bool {
        get { super.wantsExtendedDynamicRangeContent }
        set {
            if Thread.isMainThread {
                super.wantsExtendedDynamicRangeContent = newValue
            } else {
                DispatchQueue.main.sync { super.wantsExtendedDynamicRangeContent = newValue }
            }
        }
    }
}
