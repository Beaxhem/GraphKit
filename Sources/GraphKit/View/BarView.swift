//
//  BarView.swift
//  GraphKit
//
//  Created by Illia Senchukov on 08.05.2026.
//

import SwiftUI
import MetalKit
import simd

#if os(macOS)
public struct BarView: NSViewRepresentable {

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

    public func makeNSView(context: Context) -> MTKBarView {
        MTKBarView(configuration: configuration, controller: controller, device: device)
    }

    public func updateNSView(_ barGraphView: MTKBarView, context: Context) {
        barGraphView.color = color
        barGraphView.setData(dataPoints)
    }
}
#endif

public class MTKBarView: MTKChartView {

    var color: Color = .primary

    private var commandQueue: MTLCommandQueue!

    private var linePipelineState: MTLRenderPipelineState!
    private var gradientPipelineState: MTLRenderPipelineState!

    private var lineVertexBuffer: MTLBuffer?
    private var gradientVertexBuffer: MTLBuffer?

    private var barDimensionsBuffer: MTLBuffer?
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

        self.commandQueue = device.makeCommandQueue()

        let lineVertexFunction = library.makeFunction(name: "bar_vertex_main")
        let lineFragmentFunction = library.makeFunction(name: "bar_fragment_main")
        let gradientVertexFunction = library.makeFunction(name: "bar_vertex_background")
        let gradientFragmentFunction = library.makeFunction(name: "bar_fragment_background")

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD2<Float>>.stride

        let linePipelineDescriptor = MTLRenderPipelineDescriptor()
        linePipelineDescriptor.vertexFunction = lineVertexFunction
        linePipelineDescriptor.fragmentFunction = lineFragmentFunction
        linePipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        linePipelineDescriptor.vertexDescriptor = vertexDescriptor
        linePipelineDescriptor.rasterSampleCount = sampleCount

        self.linePipelineState = try! device.makeRenderPipelineState(descriptor: linePipelineDescriptor)

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

        self.gradientPipelineState = try! device.makeRenderPipelineState(descriptor: gradientPipelineDescriptor)
    }

    public override func draw(_ rect: CGRect) {
        updateUniforms(size: rect.size)
        updateResolution(size: rect.size)

        guard let drawable = currentDrawable,
              let renderPassDescriptor = currentRenderPassDescriptor,
              let lineVertexBuffer, let gradientVertexBuffer else {
            return
        }

        let commandBuffer = commandQueue.makeCommandBuffer()

        if let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            encoder.setRenderPipelineState(gradientPipelineState)

            encoder.setVertexBuffer(gradientVertexBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
            encoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 1)

            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: gradientVertexBuffer.length / MemoryLayout<SIMD2<Float>>.stride)

            encoder.setRenderPipelineState(linePipelineState)

            encoder.setVertexBuffer(lineVertexBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: lineVertexBuffer.length / MemoryLayout<SIMD2<Float>>.stride)

            encoder.endEncoding()
        }

        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }

}

extension MTKBarView {

    func setData(_ data: [Double]) {
        guard !data.isEmpty else { return }

        self.data = data
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
        guard var data else { return }

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

        var lineVertices = [SIMD2<Float>]()
        lineVertices.reserveCapacity(viewport.pointsCount * 6)
        var gradientVertices = [SIMD2<Float>]()
        gradientVertices.reserveCapacity(viewport.pointsCount * 6)

        let proportionalWidth: Double = 0.9

        let lineOffset = SIMD2(0, configuration.lineWidth / Float(size.height) / 2)

        for x in stride(from: effectiveStartX, to: effectiveEndX, by: xStep) {
            let i = Int((x.displayToNormalized * Double(data.count)).rounded())
            let barWidth = Float(xStep * proportionalWidth)
            let x = Float(x)
            let y = Float(data[i])

            let p1 = SIMD2(x, y)
            let p2 = SIMD2(x + barWidth, y)

            lineVertices += [
                p1 - lineOffset,
                p1 + lineOffset,
                p2 + lineOffset,

                p1 - lineOffset,
                p2 + lineOffset,
                p2 - lineOffset
            ]

            gradientVertices += [
                .init(x, -1),
                .init(x + barWidth, -1),
                p1,

                p1,
                .init(x + barWidth, -1),
                p2,
            ]
        }

        guard !lineVertices.isEmpty else { return }

        lineVertexBuffer = device?.makeBuffer(bytes: lineVertices, length: lineVertices.count * MemoryLayout<SIMD2<Float>>.stride)
        gradientVertexBuffer = device?.makeBuffer(bytes: gradientVertices, length: gradientVertices.count * MemoryLayout<SIMD2<Float>>.stride, options: [])
    }

}

private extension MTKBarView {

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

    func updateUniforms(size: CGSize) {
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
                                scale: .init(controller.scale),
                                scrollOffset: .init(controller.contentOffset))
        uniformsBuffer.update(with: uniforms, device: device, options: .storageModeShared)
    }

}

fileprivate struct Uniforms {
    let color: SIMD4<Float>
    let aspectRatio: SIMD2<Float>
    let scale: SIMD2<Float>
    let scrollOffset: SIMD2<Float>
}
