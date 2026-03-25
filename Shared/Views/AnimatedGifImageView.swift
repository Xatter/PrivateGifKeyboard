import UIKit
import ImageIO

final class AnimatedGifImageView: UIView {

    private var imageSource: CGImageSource?
    private var frameCount: Int = 0
    private var frameDelays: [Double] = []
    private var currentFrameIndex: Int = 0
    private var accumulatedTime: Double = 0
    private var displayLink: CADisplayLink?
    private var previousTimestamp: CFTimeInterval = 0
    private var shouldAnimate = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        layer.contentsGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Load a GIF from disk on a background thread and display the first frame immediately.
    /// Automatically starts animation once loaded if `startAnimating()` was called
    /// or if animation hasn't been explicitly stopped.
    func loadGif(from url: URL) {
        reset()
        shouldAnimate = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let data = try? Data(contentsOf: url),
                  let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }

            let count = CGImageSourceGetCount(source)
            let delays = GifFrameExtractor.frameDelays(from: source)

            let opts = [kCGImageSourceShouldCacheImmediately: false] as CFDictionary
            let firstFrame = CGImageSourceCreateImageAtIndex(source, 0, opts)

            DispatchQueue.main.async {
                guard let self else { return }
                self.imageSource = source
                self.frameCount = count
                self.frameDelays = delays
                self.currentFrameIndex = 0

                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.layer.contents = firstFrame
                CATransaction.commit()

                if self.shouldAnimate && count > 1 {
                    self.startAnimating()
                }
            }
        }
    }

    func startAnimating() {
        shouldAnimate = true
        guard displayLink == nil, frameCount > 1 else { return }
        previousTimestamp = 0
        accumulatedTime = 0
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stopAnimating() {
        shouldAnimate = false
        displayLink?.invalidate()
        displayLink = nil
        previousTimestamp = 0
    }

    func reset() {
        stopAnimating()
        shouldAnimate = false
        imageSource = nil
        frameCount = 0
        frameDelays = []
        currentFrameIndex = 0
        accumulatedTime = 0
        layer.contents = nil
    }

    override var contentMode: UIView.ContentMode {
        didSet {
            switch contentMode {
            case .scaleAspectFit:
                layer.contentsGravity = .resizeAspect
            case .scaleToFill:
                layer.contentsGravity = .resize
            default:
                layer.contentsGravity = .resizeAspectFill
            }
        }
    }

    // MARK: - Display Link

    @objc private func tick(_ link: CADisplayLink) {
        guard frameCount > 1 else { return }

        if previousTimestamp == 0 {
            previousTimestamp = link.timestamp
            return
        }

        let elapsed = link.timestamp - previousTimestamp
        previousTimestamp = link.timestamp
        accumulatedTime += elapsed

        let currentDelay = frameDelays[currentFrameIndex]
        if accumulatedTime >= currentDelay {
            accumulatedTime -= currentDelay
            currentFrameIndex = (currentFrameIndex + 1) % frameCount

            if let source = imageSource {
                let opts = [kCGImageSourceShouldCacheImmediately: false] as CFDictionary
                if let frame = CGImageSourceCreateImageAtIndex(source, currentFrameIndex, opts) {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    layer.contents = frame
                    CATransaction.commit()
                }
            }
        }
    }
}
