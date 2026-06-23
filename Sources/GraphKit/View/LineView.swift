//
//  LineView.swift
//  GraphKit
//
//  Created by Illia Senchukov on 08.05.2026.
//

import SwiftUI
import MetalKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if os(macOS)
public struct LineView: NSViewRepresentable {

    public typealias Configuration = ChartConfiguration

    let color: Color
    let device: MTLDevice?
    let dataPoints: [Double]
    let configuration: Configuration
    let controller: ChartController

    public init(color: Color, dataPoints: [Double], configuration: Configuration, controller: ChartController) {
        self.color = color
        self.device = MTLCreateSystemDefaultDevice()
        self.dataPoints = dataPoints
        self.configuration = configuration
        self.controller = controller
    }

    public func makeNSView(context: Context) -> MTKLineView {
        MTKLineView(configuration: configuration, controller: controller, device: device)
    }

    public func updateNSView(_ nsView: MTKLineView, context: Context) {
        nsView.color = color
        nsView.setData(dataPoints)
    }
}
#endif

#if canImport(UIKit)
public struct LineView: UIViewRepresentable {

    public typealias Configuration = ChartConfiguration

    let color: Color
    let device: MTLDevice?
    let dataPoints: [Double]
    let configuration: Configuration
    let controller: ChartController

    public init(color: Color, dataPoints: [Double], configuration: Configuration, controller: ChartController) {
        self.color = color
        self.device = MTLCreateSystemDefaultDevice()
        self.dataPoints = dataPoints
        self.configuration = configuration
        self.controller = controller
    }

    public func makeUIView(context: Context) -> MTKLineView {
        MTKLineView(configuration: configuration, controller: controller, device: device)
    }

    public func updateUIView(_ uiView: MTKLineView, context: Context) {
        uiView.color = color
        uiView.setData(dataPoints)
    }
}
#endif

public class MTKLineView: MTKChartView {

    var color: Color = .primary

    private var commandQueue: MTLCommandQueue!

    private var linePipelineState: MTLRenderPipelineState!
    private var gradientPipelineState: MTLRenderPipelineState!

    private var vertexBuffer: MTLBuffer?
    private var gradientVertexBuffer: MTLBuffer?
    private var uniformsBuffer: MTLBuffer?

    private var data: [Double]?

    override init(configuration: ChartConfiguration, controller: ChartController, device: (any MTLDevice)?) {
        super.init(configuration: configuration, controller: controller, device: device)

        selectSampleCount()
        setupPipeline()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupPipeline() {
        guard let device, let library = try? device.makeDefaultLibrary(bundle: .module) else {
            fatalError("Could not create Metal library")
        }

        let lineVertexFunction = library.makeFunction(name: "line_vertex_main")
        let lineFragmentFunction = library.makeFunction(name: "line_fragment_main")
        let gradientVertexFunction = library.makeFunction(name: "line_vertex_background")
        let gradientFragmentFunction = library.makeFunction(name: "line_fragment_background")

        let vertexDescriptor = MTLVertexDescriptor()

        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD2<Float>>.stride

        let gradientPipelineDescriptor = MTLRenderPipelineDescriptor()
        gradientPipelineDescriptor.vertexFunction = gradientVertexFunction
        gradientPipelineDescriptor.fragmentFunction = gradientFragmentFunction
        gradientPipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        gradientPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        gradientPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        gradientPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        gradientPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        gradientPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        gradientPipelineDescriptor.vertexDescriptor = vertexDescriptor
        gradientPipelineDescriptor.rasterSampleCount = sampleCount

        gradientPipelineState = try! device.makeRenderPipelineState(descriptor: gradientPipelineDescriptor)

        let linePipelineDescriptor = MTLRenderPipelineDescriptor()
        linePipelineDescriptor.vertexFunction = lineVertexFunction
        linePipelineDescriptor.fragmentFunction = lineFragmentFunction
        linePipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        linePipelineDescriptor.vertexDescriptor = vertexDescriptor
        linePipelineDescriptor.rasterSampleCount = sampleCount

        linePipelineState = try! device.makeRenderPipelineState(descriptor: linePipelineDescriptor)

        commandQueue = device.makeCommandQueue()
    }

    public override func draw(_ rect: CGRect) {
        updateUniforms(rect.size)
        updateResolution(size: rect.size)

        guard let drawable = currentDrawable,
              let renderPassDescriptor = currentRenderPassDescriptor,
              let vertexBuffer,
              let gradientVertexBuffer else {
            return
        }

        let commandBuffer = commandQueue.makeCommandBuffer()

        if let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            encoder.setRenderPipelineState(gradientPipelineState)

            encoder.setVertexBuffer(gradientVertexBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
            encoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 1)

            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: gradientVertexBuffer.length / MemoryLayout<SIMD2<Float>>.stride)

            encoder.setRenderPipelineState(linePipelineState)

            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertexBuffer.length / MemoryLayout<SIMD2<Float>>.stride)

            encoder.endEncoding()
        }

        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }

}

extension MTKLineView {

    func setData(_ data: [Double]) {
        guard !data.isEmpty else { return }
        self.data = data
        controller.reset()

        rerender()
    }

#if canImport(UIKit)
    func rerender() {
        setNeedsDisplay()
    }

    func dataStep(for dataCount: Int) -> Int? {
        guard let screen = window?.screen else { return nil }
        return ensurePointWidth(dataCount: dataCount, for: screen)
    }
#endif

#if os(macOS)
    func rerender() {
        needsDisplay = true
    }

    func dataStep(for dataCount: Int) -> Int? {
        ensurePointWidth(dataCount: dataCount)
    }
#endif

    func updateResolution(size: CGSize) {
        guard var data, !data.isEmpty else { return }

        let viewport = controller.viewport(for: size, data: &data)

        guard let dataStep = dataStep(for: data.count / max(Int(controller.scale.x), 1)) else {
            return
        }
        let xStep = Double(dataStep) * viewport.pointWidth

        let startI = Int(viewport.startX.displayToNormalized * Double(data.count))
        let effectiveStartI = max(startI.roundTo(dataStep: dataStep, rule: .down), 0)
        let effectiveStartX = (Double(effectiveStartI) / Double(data.count)).displayNormalized

        let endI = Int(viewport.endX.displayToNormalized * Double(data.count))
        let effectiveEndI = min(endI.roundTo(dataStep: dataStep, rule: .up) + 1, data.count - 1)
        let effectiveEndX = (Double(effectiveEndI) / Double(data.count)).displayNormalized

        var linePoints = [SIMD2<Float>]()
        linePoints.reserveCapacity(viewport.pointsCount / dataStep * 4)
        var gradientVertices: [SIMD2<Float>] = []
        gradientVertices.reserveCapacity(viewport.pointsCount / dataStep * 2)

        for x1 in stride(from: effectiveStartX, to: effectiveEndX, by: xStep) {
            let i = Int((((x1 + 1) / 2) * Double(data.count)).rounded())
            if i + dataStep >= data.count { break }

            let y1 = data[i]

            let x2 = x1 + xStep
            let y2 = data[i + dataStep]

            let p1 = SIMD2(Float(x1), Float(y1))
            let p2 = SIMD2(Float(x2), Float(y2))

            linePoints += [p1, p1, p2, p2]
            gradientVertices += [p1, .init(Float(x1), -1)]
        }

        guard !linePoints.isEmpty else { return }
        // last point
        gradientVertices += [.init(Float(effectiveEndX), Float(data[effectiveEndI])), .init(Float(effectiveEndX), -1)]

        gradientVertexBuffer = device?.makeBuffer(bytes: gradientVertices, length: MemoryLayout<SIMD2<Float>>.size * gradientVertices.count, options: [])
        vertexBuffer = device?.makeBuffer(bytes: linePoints, length: linePoints.count * MemoryLayout<SIMD2<Float>>.stride, options: [])
    }

}

private extension MTKLineView {

#if canImport(UIKit)
    var isDarkMode: Bool {
        traitCollection.userInterfaceStyle == .dark
    }
#endif

#if os(macOS)
    var isDarkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
#endif

    func updateUniforms(_ size: CGSize) {
#if os(macOS)
        guard let screen = NSScreen.screens.min(by: { $0.backingScaleFactor < $1.backingScaleFactor }) else {
            return
        }

        let lineWidthClip = (configuration.lineWidth / Float(screen.frame.height * screen.backingScaleFactor)) * Float(screen.frame.height / size.height)
#elseif canImport(UIKit)
        // The macOS expression above algebraically reduces to
        // `lineWidth / (scale * viewHeight)`; use the screen's native scale.
        let scale = Float(window?.screen.nativeScale ?? UIScreen.main.nativeScale)
        let lineWidthClip = configuration.lineWidth / (scale * Float(size.height))
#endif

        var env = EnvironmentValues()
        env.colorScheme = isDarkMode ? .dark : .light
        let resolvedColor = self.color.resolve(in: env)

        let color = SIMD4(
            [\Color.Resolved.red, \.green, \.blue, \.opacity]
                .map { resolvedColor[keyPath: $0] }
        )
        let aspectRatio: SIMD2<Float> = if size.width > size.height {
            .init(Float(size.width / size.height), 1)
        } else {
            .init(1, Float(size.height / size.width))
        }

        let uniforms = Uniforms(color: color,
                                aspectRatio: aspectRatio,
                                lineWidth: lineWidthClip,
                                scale: .init(controller.scale),
                                scrollOffset: .init(controller.contentOffset))
        uniformsBuffer.update(with: uniforms, device: device, options: .storageModeShared)
    }

}

fileprivate struct Uniforms {
    let color: SIMD4<Float>
    let aspectRatio: SIMD2<Float>
    let lineWidth: Float
    var scale: SIMD2<Float>
    var scrollOffset: SIMD2<Float>
}

