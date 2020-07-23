//
//  StarfieldConfig.swift
//  Glitter
//
//  Created by Raheel Ahmad on 7/22/20.
//  Copyright © 2020 Raheel Ahmad. All rights reserved.
//

import Foundation

import CoreGraphics

public struct StarfieldConfig {
    let fullScreenColorVertices: FullScreenVertices
    let shimmerDuration: TimeInterval
    let shimmerRotations: CGFloat
    let shimmerStrength: CGFloat
    
    public static var `default`: StarfieldConfig {
        let bottomLeft = Color(red:255/255.0, green:0/255.0, blue:194/255.0)
        let topLeft = Color(red:140/255.0, green:0/255.0, blue:255/255.0)
        
        let vertices = FullScreenVertices(
            topLeft: topLeft,
            bottomLeft: bottomLeft,
            topRight: topLeft,
            bottomRight: bottomLeft
        )
        
        return .init(
            fullScreenColorVertices: vertices,
            shimmerDuration: 3,
            shimmerRotations: 2,
            shimmerStrength: 0.3
        )
    }
}
