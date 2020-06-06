//
//  VertexInfo.swift
//  Glitter
//
//  Created by Raheel Ahmad on 5/15/20.
//  Copyright © 2020 Raheel Ahmad. All rights reserved.
//

import Foundation

public struct Color {
    var red: Float = 0
    var green: Float = 0
    var blue: Float = 0
    var alpha: Float = 1
}

struct ColorVertex {
    let x: Float
    let y: Float

    let red: Float
    let green: Float
    let blue: Float
    let alpha: Float

    init(x: Float, y: Float, color: Color) {
        self.x = x
        self.y = y
        self.red = color.red
        self.green = color.green
        self.blue = color.blue
        self.alpha = color.alpha
    }
}

struct FullScreenVertices {
    let topLeft: Color
    let bottomLeft: Color
    let topRight: Color
    let bottomRight: Color

    var vertices: [ColorVertex] {
        [
            .init(x: -1, y: 1, color: topLeft),
            .init(x: -1, y: -1, color: bottomLeft),
            .init(x: 1, y: 1, color: topRight),
            .init(x: 1, y: -1, color: bottomRight),
        ]
    }
}

struct GlitterFragmentUniforms {
    let displayWidth: Float
    let displayHeight: Float
    let displayScale: Float

    let tiltX: Float
    let tiltY: Float
    let tiltZ: Float

    let cellSize: Float
    let whiteness: Float
    let darkness: Float
    let backgroundLight: Float
    let hueVariance: Float

    let useWideColor: Int32
}

struct TextureFloatPoint {
    public let x: Float
    public let y: Float
    public let texX: Float
    public let texY: Float
}

struct TextureFragmentUniform {
    let red: Float
    let green: Float
    let blue: Float
    let alpha: Float
}
