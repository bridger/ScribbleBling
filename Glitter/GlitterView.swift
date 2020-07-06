//
//  MetalGlitterView.swift
//  ScribbleApp
//
//  Created by Bridger Maxwell on 3/31/19.
//  Copyright © 2019 Bridger Maxwell. All rights reserved.
//


import Foundation
import CoreMotion

import MetalKit
import MetalPerformanceShaders

@available(iOS 10.0, *)
public class GlitterView: MTKView {
    private let compositePipelineState: MTLRenderPipelineState
    private let glitterPipelineState: MTLRenderPipelineState
    private var _glitterRenderPassDescriptor: MTLRenderPassDescriptor?
    private var computeCompositePipelineState: MTLComputePipelineState
    private let fullScreenColorVertices: MTLBuffer
    private let fullScreenTexturedVertices: MTLBuffer
    private let commandQueue: MTLCommandQueue

    public var config: GlitterConfig

    var fullscreenTextVertices: [TextureFloatPoint] = [
        TextureFloatPoint(x: -1, y: -1, texX: 0, texY: 1),
        TextureFloatPoint(x: 1, y: -1, texX: 1, texY: 1),
        TextureFloatPoint(x: -1, y: 1, texX: 0, texY: 0),
        TextureFloatPoint(x: 1, y: 1, texX: 1, texY: 0)
    ]

    static var pixelFormat: MTLPixelFormat{
        #if targetEnvironment(simulator)
        return .bgra8Unorm
        #else
        return (UIScreen.main.traitCollection.displayGamut == .P3) ? .bgra10_xr : .bgra8Unorm
        #endif
    }

    public required init?(config: GlitterConfig) {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let pipelineState = Pipeline.buildComposite(device: device, pixelFormat: Self.pixelFormat),
            let glitterPipelineState = Pipeline.build(device: device, pixelFormat: Self.pixelFormat),
            let compositePipelineState = Pipeline.buildComputeComposite(device: device, pixelFormat: Self.pixelFormat),
            let commandQueue = device.makeCommandQueue()
            else { return nil }

        self.compositePipelineState = pipelineState
        self.glitterPipelineState = glitterPipelineState
        self.computeCompositePipelineState = compositePipelineState
        self.commandQueue = commandQueue
        self.config = config

        let fullScreenColorVertices = config.fullScreenColorVertices.vertices
        let dataSize = fullScreenColorVertices.count * MemoryLayout.size(ofValue: fullScreenColorVertices[0])

        guard let verticesBuffer = device.makeBuffer(bytes: fullScreenColorVertices, length: dataSize, options: []) else {
            return nil
        }
        self.fullScreenColorVertices = verticesBuffer

        let textureDataSize = fullscreenTextVertices.count * MemoryLayout.size(ofValue: fullscreenTextVertices[0])
        self.fullScreenTexturedVertices = device.makeBuffer(bytes: fullscreenTextVertices, length: textureDataSize, options: [])!

        super.init(frame: CGRect.zero, device: device)

        let motionEffect = GlitterMotionEffect { [weak self] (offset) in
            if offset.horizontal != 0 || offset.vertical != 0 {
                if offset != self?.motionTilt {
                    self?.motionTilt = offset
                    self?.setNeedsDisplay()
                }
            }
        }
        self.addMotionEffect(motionEffect)

        self.enableSetNeedsDisplay = false
        self.isPaused = true
        self.layer.isOpaque = true
        self.colorPixelFormat = Self.pixelFormat
        self.sampleCount = 1
        self.framebufferOnly = false
    }

    private var displayOnNextFrame = true

    private var motionManager: CMMotionManager?
    private var motionTilt: UIOffset?
    private var gravity: CMAcceleration?
    private let startTime = Date()

    public func startMotionUpdates() {
        if self.motionManager == nil {
            let manager = CMMotionManager()
            manager.deviceMotionUpdateInterval = 1.0 / 60.0
            manager.startDeviceMotionUpdates()

            self.motionManager = manager
        }
        if self.displayLink == nil {
            self.displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
            self.displayLink?.add(to: RunLoop.current, forMode: RunLoop.Mode.common)
        }
    }

    func stopMotionUpdates() {
        self.motionManager = nil
        self.displayLink?.remove(from: RunLoop.current, forMode: RunLoop.Mode.common)
        self.displayLink = nil
    }

    var shimmerAnimation: Animation?

    public func startAutoShimmer() {
        shimmerAnimation = Animation(
            startTime: CACurrentMediaTime(),
            duration: config.shimmerDuration,
            startValue: 0.0,
            endValue: CGFloat.pi * 2 * config.shimmerRotations,
            interpolation: BasicInterpolation.linear
        )
    }

    var displayLink: CADisplayLink?

    @objc func displayLinkFired() {
        if let gravity = motionManager?.deviceMotion?.gravity {
            var changed = true
            if let oldGravity = self.gravity {
                if oldGravity.absoluteDifference(gravity) < 0.05 {
                    changed = false
                }
            }
            if changed {
                self.gravity = gravity
                displayOnNextFrame = true
            }
        }
        if let shimmerAnimation = self.shimmerAnimation, !shimmerAnimation.isFinished {
            displayOnNextFrame = true
        }
        if displayOnNextFrame {
            displayOnNextFrame = false
            draw()
        }
    }

    public override func layoutSubviews() {
        // We use this to find out when the frame changed. For some reason, overriding bounds doesn't get the didSet notification
        super.layoutSubviews()
        displayOnNextFrame = true
        _glitterRenderPassDescriptor = nil
    }

    public override func draw(_ rect: CGRect) {
        autoreleasepool {
            guard
                let screenRenderPassDescriptor = currentRenderPassDescriptor,
                let commandBuffer = commandQueue.makeCommandBuffer(),
                let drawable = currentDrawable
            else { return }

            // offline descriptor
            guard
                let glitterDescriptor = glitterRenderPassDescriptor(),
                let glitterEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: glitterDescriptor)
            else { return }

            // we first want to draw the glitter offline
            glitterEncoder.setRenderPipelineState(self.glitterPipelineState)
            drawGlitter(encoder: glitterEncoder)

            glitterEncoder.endEncoding()

            screenRenderPassDescriptor.colorAttachments[0].loadAction = .load // Don't clear
            guard let screenRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: screenRenderPassDescriptor) else {
                return
            }

            screenRenderEncoder.setRenderPipelineState(compositePipelineState)
            var fragmentUniform = BlurCompositeFragmentUniform(radius: 8)
            screenRenderEncoder.setFragmentBytes(&fragmentUniform,
                                           length: MemoryLayout.size(ofValue: fragmentUniform),
                                           index: 0)

            let blurTexture = glitterDescriptor.colorAttachments[1]!.texture!
            screenRenderEncoder.setFragmentTexture(blurTexture, index: 0)

            screenRenderEncoder.setVertexBuffer(fullScreenTexturedVertices, offset: 0, index: 0)
            screenRenderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

            screenRenderEncoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }

    private func drawGlitter(encoder: MTLRenderCommandEncoder) {
        var xTilt: Double
        var yTilt: Double
        let zTilt: Double = 0.15 // Lower this to make the tilt have more of an effect
        if let tilt = motionTilt {
            xTilt = Double(tilt.horizontal)
            yTilt = Double(tilt.vertical)

            if let gravity = self.gravity {
                let gravityEffect: Double = 0.3
                // This just incorporates gravity into a small effect so that we get some shimmer even when UIMotionEffect is maxed out
                xTilt += sin(gravity.x + gravity.z / 2.0) * gravityEffect
                yTilt += sin(gravity.y + gravity.z / 2.0) * gravityEffect
            }
        } else {
            xTilt = (sin(startTime.timeIntervalSinceNow * 0.9) + 1.0) / 2.0
            yTilt = (cos(startTime.timeIntervalSinceNow * 0.8) + 1.0) / 2.0
        }

        if let shimmerAnimation = shimmerAnimation {
            shimmerAnimation.currentTime = CACurrentMediaTime()
            let amount = ImpulsePulse().apply(shimmerAnimation.percent) * config.shimmerStrength
            xTilt += Double(sin(shimmerAnimation.currentValue) * amount)
            yTilt += Double(cos(shimmerAnimation.currentValue) * amount * 0.5)
        }

        // Normalize the tilt
        let tiltLength = sqrt(
            xTilt * xTilt +
                yTilt * yTilt +
                zTilt * zTilt)

        var fragmentUniform = GlitterFragmentUniforms(
            displayWidth: Float(self.bounds.width * self.contentScaleFactor),
            displayHeight: Float(self.bounds.height * self.contentScaleFactor),
            displayScale: Float(self.contentScaleFactor),
            tiltX: Float(xTilt / tiltLength),
            tiltY: Float(yTilt / tiltLength),
            tiltZ: Float(zTilt / tiltLength),
            cellSize: Float(10.0 - config.glitterSize) / 10.0,
            whiteness: Float(config.glitterWhiteness),
            darkness: Float(config.glitterDarkness),
            backgroundLight: Float(config.glitterBackgroundVariance),
            hueVariance: Float(config.glitterHueVariance) / 10,
            useWideColor: Self.pixelFormat == .bgra8Unorm ? 0 : 1
        )

        encoder.setFragmentBytes(&fragmentUniform, length: MemoryLayout.size(ofValue: fragmentUniform), index: 1)

        encoder.setVertexBuffer(fullScreenColorVertices, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension GlitterView {
    private func glitterRenderPassDescriptor() -> MTLRenderPassDescriptor? {
        guard
            let screenPassDescriptor = currentRenderPassDescriptor,
            let screenTexture = screenPassDescriptor.colorAttachments[0].texture else {
            return nil
        }

        if let cached = _glitterRenderPassDescriptor {
            cached.colorAttachments[0].texture = screenTexture
            return cached
        }

        _glitterRenderPassDescriptor = glitterDescriptor(screenTexture: screenTexture)
        return _glitterRenderPassDescriptor
    }

    private func glitterDescriptor(screenTexture: MTLTexture) -> MTLRenderPassDescriptor {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = screenTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare

        // The bright fragments will be drawn to this texture, then blurred and overlayed
        let blurTextureDescriptor = MTLTextureDescriptor()
        blurTextureDescriptor.sampleCount = 1 // We don't multisample
        blurTextureDescriptor.textureType = .type2D

        // TODO: Using a smaller texture here, like screenTexture.width / 2 could improve performance
        blurTextureDescriptor.width = screenTexture.width
        blurTextureDescriptor.height = screenTexture.height
        blurTextureDescriptor.pixelFormat = screenTexture.pixelFormat
        blurTextureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]

        renderPassDescriptor.colorAttachments[1].texture = device?.makeTexture(descriptor: blurTextureDescriptor)
        renderPassDescriptor.colorAttachments[1].loadAction = .dontCare

        return renderPassDescriptor
    }
}
