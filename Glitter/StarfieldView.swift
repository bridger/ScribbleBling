//
//  StarfieldView.swift
//  Glitter
//
//  Created by Raheel Ahmad on 7/22/20.
//  Copyright © 2020 Raheel Ahmad. All rights reserved.
//

import CoreMotion

import MetalKit
import MetalPerformanceShaders

@available(iOS 10.0, *)
public class StarfieldView: MTKView {
    private let starfieldPipelineState: MTLRenderPipelineState
    private let fullScreenColorVertices: MTLBuffer
    private let fullScreenTexturedVertices: MTLBuffer
    private let commandQueue: MTLCommandQueue
    
    public var config: StarfieldConfig
    
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
    
    public required init?(config: StarfieldConfig) {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let glitterPipelineState = Pipeline.starField(device: device, pixelFormat: Self.pixelFormat),
            let commandQueue = device.makeCommandQueue()
            else { return nil }
        
        self.starfieldPipelineState = glitterPipelineState
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
    }
    
    public override func draw(_ rect: CGRect) {
        autoreleasepool {
            guard
                let screenRenderPassDescriptor = currentRenderPassDescriptor,
                let commandBuffer = commandQueue.makeCommandBuffer(),
                let drawable = currentDrawable,
                let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: screenRenderPassDescriptor)            
                else { return }
            
            screenRenderPassDescriptor.colorAttachments[0].loadAction = .dontCare            
            
            commandEncoder.setRenderPipelineState(self.starfieldPipelineState)
            drawStarField(encoder: commandEncoder)
            
            commandEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
    
    private func drawStarField(encoder: MTLRenderCommandEncoder) {
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
        
        var fragmentUniform = StarFieldFragmentUniforms(
            displayWidth: Float(self.bounds.width * self.contentScaleFactor),
            displayHeight: Float(self.bounds.height * self.contentScaleFactor),
            displayScale: Float(self.contentScaleFactor),
            tiltX: Float(xTilt / tiltLength),
            tiltY: Float(yTilt / tiltLength),
            tiltZ: Float(zTilt / tiltLength)
        )
        
        encoder.setFragmentBytes(&fragmentUniform, length: MemoryLayout.size(ofValue: fragmentUniform), index: 1)
        
        encoder.setVertexBuffer(fullScreenColorVertices, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

