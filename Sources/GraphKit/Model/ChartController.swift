//
//  ChartController.swift
//  GraphKit
//
//  Created by Illia Senchukov on 08.05.2026.
//

import SwiftUI

public final class ChartController {

    public var scale: SIMD2<Double> = .one
    public var contentOffset: SIMD2<Double> = .zero

    public init(scale: SIMD2<Double> = .one, contentOffset: SIMD2<Double> = .zero) {
        self.scale = scale
        self.contentOffset = contentOffset
    }

    public func reset() {
        scale = .one
        contentOffset = .zero
    }

}

public extension ChartController {

    func xPosition(for index: Int, step: CGFloat, canvasSize: CGSize) -> CGFloat {
        let effectiveStep = self.effectiveStep(step: step)
        let x = CGFloat(index) * CGFloat(effectiveStep)

        return xPositionToScreen(position: x, canvasSize: canvasSize)
    }

    func yPosition(for nY: Double, canvasSize: CGSize) -> CGFloat {
        let y = (nY + 1) / 2
        return yPositionToScreen(y: y, canvasSize: canvasSize)
    }

    func pointIdxAt(mousePos: CGPoint, step: CGFloat, canvasSize: CGSize) -> Int {
        let effectiveStep = self.effectiveStep(step: step)
        let x = xPositionFromScreen(position: mousePos.x, canvasSize: canvasSize)

        return Int(x / effectiveStep)
    }

}

public extension ChartController {

    func effectiveStep(step: CGFloat) -> Double {
        Double(step) * scale.x
    }

    func chartOffsetX(canvasWidth: CGFloat) -> Double {
        let canvasOffset = Double(canvasWidth) * (1 - scale.x) / 2
        return (contentOffset.x * Double(canvasWidth)) / (2 / scale.x) + canvasOffset
    }

    func chartOffsetY(canvasHeight: CGFloat) -> Double {
        let canvasOffset = Double(canvasHeight) * (1 - scale.y) / 2
        return (contentOffset.y * Double(canvasHeight)) / (2 / scale.y) + canvasOffset
    }

    func xPositionFromScreen(position: CGFloat, canvasSize: CGSize) -> Double {
        Double(position) - chartOffsetX(canvasWidth: canvasSize.width)
    }

    func yPositionFromScreen(y: Double, canvasSize: CGSize) -> Double {
        let pixelOffset = chartOffsetY(canvasHeight: canvasSize.height)
        return y - pixelOffset
    }

    func xPositionToScreen(position: CGFloat, canvasSize: CGSize) -> CGFloat {
        let pixelOffset = chartOffsetX(canvasWidth: canvasSize.width)
        return position + CGFloat(pixelOffset)
    }

    func yPositionToScreen(y: Double, canvasSize: CGSize) -> CGFloat {
        let pixelOffset = chartOffsetY(canvasHeight: canvasSize.height)
        let scaledHeight = Double(canvasSize.height) * scale.y
        return canvasSize.height - CGFloat(y * scaledHeight + pixelOffset)
    }

}

extension ChartController {

    struct Viewport {
        let startX: Double
        let endX: Double
        let pointsCount: Int
        let pointWidth: Double
    }

    func viewport(for size: CGSize, data: inout [Double]) -> Viewport {
        let step = size.width / CGFloat(data.count)
        let minX = Double(pointIdxAt(mousePos: .zero, step: step, canvasSize: size)) / Double(data.count)
        let maxX = Double(pointIdxAt(mousePos: .init(x: size.width, y: 0), step: step, canvasSize: size)) / Double(data.count)

        let startX = max((2 * minX - 1), -1)
        let endX = min((2 * maxX - 1), 1)

        let pointWidth = Double(2) / Double(data.count) // 2 because -1 to 1
        let pointsCount = Int((endX - startX) / pointWidth)

        return .init(startX: startX, endX: endX, pointsCount: pointsCount, pointWidth: pointWidth)
    }

}
