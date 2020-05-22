//
//  MotionEffect.swift
//  Glitter
//
//  Created by Raheel Ahmad on 5/15/20.
//  Copyright © 2020 Raheel Ahmad. All rights reserved.
//

import UIKit
import CoreMotion

class GlitterMotionEffect: UIMotionEffect {

    typealias offsetCallback = (UIOffset) -> Void

    let callback: offsetCallback
    init(callback: @escaping offsetCallback) {
        self.callback = callback
        super.init()
    }

    override func keyPathsAndRelativeValues(forViewerOffset viewerOffset: UIOffset) -> [String : Any]? {
        callback(viewerOffset)
        return nil
    }

    override func copy(with zone: NSZone? = nil) -> Any {
        return GlitterMotionEffect(callback: self.callback)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension CMAcceleration {
    func absoluteDifference(_ other: CMAcceleration) -> Double {
        // This function kept being expensive to typecheck so this way of writing is mostly to avoid that
        let xDiff: Double = abs(self.x - other.x)
        let yDiff: Double = abs(self.y - other.y)
        let zDiff: Double = abs(self.z - other.z)
        return xDiff + yDiff + zDiff
    }
}
