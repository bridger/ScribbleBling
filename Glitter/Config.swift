//
//  Config.swift
//  Glitter
//
//  Created by Raheel Ahmad on 5/15/20.
//  Copyright © 2020 Raheel Ahmad. All rights reserved.
//

import Foundation
import CoreGraphics

public struct GlitterConfig {
    let fullScreenColorVertices: FullScreenVertices
    let shimmerDuration: TimeInterval
    let shimmerRotations: CGFloat
    let shimmerStrength: CGFloat

    let glitterSize: Double
    let glitterWhiteness: Double
    let glitterDarkness: Double
    let glitterBackgroundVariance: Double
    let glitterHueVariance: Double

    public static var `default`: GlitterConfig {
        let brightPink = Color(red:255/255.0, green:0/255.0, blue:194/255.0)
        let brightPurple = Color(red:140/255.0, green:0/255.0, blue:255/255.0)

        let vertices = FullScreenVertices(
            topLeft: brightPurple,
            bottomLeft: brightPink,
            topRight: brightPurple,
            bottomRight: brightPink
        )

        return .init(
            fullScreenColorVertices: vertices,
            shimmerDuration: 3,
            shimmerRotations: 2,
            shimmerStrength: 0.3,
            glitterSize: 5.4,
            glitterWhiteness: 0.75,
            glitterDarkness: 0.15,
            glitterBackgroundVariance: 0.25,
            glitterHueVariance: 0.1
        )
    }
}
