//
//  File.swift
//  GraphKit
//
//  Created by Illia Senchukov on 08.05.2026.
//

import SwiftUI
import MetalKit
import simd

public class MTKChartView: MTKView {

    let configuration: ChartConfiguration

    let controller: ChartController

    init(configuration: ChartConfiguration, controller: ChartController, device: MTLDevice?) {
        self.configuration = configuration
        self.controller = controller
        super.init(frame: .zero, device: device)

        self.preferredFramesPerSecond = 120
#if os(macOS)
        self.layer?.isOpaque = false
#elseif canImport(UIKit)
        self.isOpaque = false
        self.layer.isOpaque = false
        self.backgroundColor = .clear
#endif
        self.clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        self.isPaused = true
        self.enableSetNeedsDisplay = true
    }

    required init(coder: NSCoder) {
        fatalError()
    }

#if os(macOS)
    public override func scrollWheel(with event: NSEvent) {
        guard configuration.isPanGestureEnabled else {
            return super.scrollWheel(with: event)
        }

        let delta = Double(event.scrollingDeltaX)
        controller.contentOffset.x += delta / (bounds.size.simd.x * controller.scale.x)
        clampContentOffset()
        draw()
    }

    public override func magnify(with event: NSEvent) {
        guard configuration.isPanGestureEnabled, configuration.isZoomEnabled else {
            return super.magnify(with: event)
        }

        let delta = Double(event.magnification)
        let scale = controller.scale
        var newScale = scale

        newScale.x *= (1 + delta)
        if newScale.x < 1 {
            newScale.x = 1
        }

        let center = bounds.center.simd
        let mousePos = (convert(event.locationInWindow, from: nil).simd - center) / scale
        let point = ((mousePos) / bounds.size.simd) * 2

        let scaleDelta = scale / newScale
        let offset = (point * (1 - scaleDelta))

        controller.scale = newScale
        controller.contentOffset -= offset
        clampContentOffset()

        draw()
    }

    private func clampContentOffset() {
        let maxOffsetX = max(0, 1 - 1 / controller.scale.x)
        controller.contentOffset.x = min(max(controller.contentOffset.x, -maxOffsetX), maxOffsetX)
    }
    #endif

}

extension MTKChartView {

#if os(macOS)
    func ensurePointWidth(dataCount: Int) -> Int {
        guard configuration.useSampling,
              let screen = NSScreen.screens.min(by: { $0.backingScaleFactor < $1.backingScaleFactor }) else {
            return 1
        }

        let pixel = Double(1) / Double(screen.frame.width * screen.backingScaleFactor)
        let currentStep = 1 / Double(dataCount)
        return max(1, Int((pixel) / currentStep))
    }
#endif

#if canImport(UIKit)
    func ensurePointWidth(dataCount: Int, for screen: UIScreen) -> Int {

        guard configuration.useSampling else {
            return 1
        }

        let pixel = Double(1) / Double(screen.nativeBounds.width)
        let currentStep = 1 / Double(dataCount)
        return max(1, Int((pixel) / currentStep))
    }
#endif

}
