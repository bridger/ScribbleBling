//
//  Pipeline.swift
//  Glitter
//
//  Created by Raheel Ahmad on 5/15/20.
//  Copyright © 2020 Raheel Ahmad. All rights reserved.
//

import Foundation
import Metal

final class Pipeline {
    // TODO: remove this and its shader
    static func buildComputeComposite(device: MTLDevice, pixelFormat: MTLPixelFormat) -> MTLComputePipelineState? {
        guard
            let library = try? device.makeDefaultLibrary(bundle: Bundle(for: Pipeline.self)),
            let computeFunction = library.makeFunction(name: "computeShader"),
            let pipeline = try? device.makeComputePipelineState(function: computeFunction)
            else { return nil }
        
        return pipeline
    }

    static func buildComposite(device: MTLDevice, pixelFormat: MTLPixelFormat) -> MTLRenderPipelineState? {
        guard
            let library = try? device.makeDefaultLibrary(bundle: Bundle(for: Pipeline.self)),
            let textureVertexProgram = library.makeFunction(name: "textured_vertex"),
            let blurCompositeFragment = library.makeFunction(name: "blur_composite_fragment")
            else { return nil }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = textureVertexProgram
        descriptor.fragmentFunction = blurCompositeFragment
        descriptor.sampleCount = 1
        descriptor.stencilAttachmentPixelFormat = .invalid

        guard let colorAttachmentDescriptor = descriptor.colorAttachments[0] else  {
            return nil
        }

        colorAttachmentDescriptor.pixelFormat = pixelFormat
        colorAttachmentDescriptor.isBlendingEnabled = true
       //Cf = (source_color * source_alpha) + (destination_color * oneMinusSourceAlpha)

        colorAttachmentDescriptor.sourceRGBBlendFactor = .sourceAlpha
        colorAttachmentDescriptor.rgbBlendOperation = .add
        colorAttachmentDescriptor.destinationRGBBlendFactor = .oneMinusSourceAlpha

        colorAttachmentDescriptor.sourceAlphaBlendFactor = .one
        colorAttachmentDescriptor.alphaBlendOperation = .add
        colorAttachmentDescriptor.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        let pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor)

        return pipelineState
    }

    static func build(device: MTLDevice, pixelFormat: MTLPixelFormat) -> MTLRenderPipelineState? {
        guard
            let library = try? device.makeDefaultLibrary(bundle: Bundle(for: Pipeline.self)),
            let glitterVertex = library.makeFunction(name: "glitter_vertex"),
            let glitterFragment = library.makeFunction(name: "glitter_fragment")
            else { return nil }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = glitterVertex
        descriptor.fragmentFunction = glitterFragment
        descriptor.sampleCount = 1
        descriptor.stencilAttachmentPixelFormat = .invalid

        descriptor.colorAttachments[0]?.pixelFormat = pixelFormat
        descriptor.colorAttachments[1]?.pixelFormat = pixelFormat

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
}
