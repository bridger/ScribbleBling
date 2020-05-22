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

        guard let colorAttachmentDescriptor = descriptor.colorAttachments[0] else  {
            return nil
        }

        colorAttachmentDescriptor.pixelFormat = pixelFormat

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
}
