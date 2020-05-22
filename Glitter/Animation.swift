//
//  Animation.swift
//  Glitter
//
//  Created by Raheel Ahmad on 5/15/20.
//  Copyright © 2020 Raheel Ahmad. All rights reserved.
//

import Foundation
import UIKit

public extension Comparable {
    func clamp(lower: Self, upper: Self) -> Self {
        return min(max(self, lower), upper)
    }
}

protocol InterpolationFunction {
    /**
     Applies interpolation function to a given progress value.

     - parameter progress: Actual progress value. CGFloat

     - returns: Adjusted progress value. CGFloat.
     */
    func apply(_ progress: CGFloat) -> CGFloat
}

// This comes from https://github.com/marmelroy/Interpolate/blob/018a6438feb9761e2931833979c492065cbb8b8b/Interpolate/BasicInterpolation.swift
enum BasicInterpolation: InterpolationFunction {
    /// Linear interpolation.
    case linear
    /// Ease in interpolation.
    case easeIn
    /// Ease out interpolation.
    case easeOut
    /// Ease in out interpolation.
    case easeInOut

    /**
     Apply interpolation function

     - parameter progress: Input progress value

     - returns: Adjusted progress value with interpolation function.
     */
    public func apply(_ progress: CGFloat) -> CGFloat {
        switch self {
        case .linear:
            return progress
        case .easeIn:
            return progress*progress*progress
        case .easeOut:
            return (progress - 1)*(progress - 1)*(progress - 1) + 1.0
        case .easeInOut:
            if progress < 0.5 {
                return 4.0*progress*progress*progress
            } else {
                let adjustment = (2*progress - 2)
                return 0.5 * adjustment * adjustment * adjustment + 1.0
            }
        }
    }
}

// This one spikes quickly and then tapers off
class ImpulsePulse: InterpolationFunction {
    func apply(_ progress: CGFloat) -> CGFloat {
        let decayFactor: CGFloat = 8 // This means it reaches max at 1/8 and at 1.0 the value is almost 0
        let h = progress * decayFactor
        return h * exp(1.0 - h)
    }
}


class Animation {

    let startTime: TimeInterval
    let duration: TimeInterval
    let startValue: CGFloat
    let range: CGFloat
    let interpolation: InterpolationFunction

    var currentValue: CGFloat
    var percent: CGFloat
    var isFinished: Bool = false

    convenience init(startTime: TimeInterval, duration: TimeInterval, startValue: CGFloat, endValue: CGFloat, interpolation: InterpolationFunction = BasicInterpolation.easeInOut) {
        self.init(startTime: startTime, duration: duration, startValue: startValue, range: endValue - startValue, interpolation: interpolation)
    }

    init(startTime: TimeInterval, duration: TimeInterval, startValue: CGFloat, range: CGFloat, interpolation: InterpolationFunction = BasicInterpolation.easeInOut) {
        self.startTime = startTime
        self.duration = duration
        self.startValue = startValue
        self.range = range
        self.currentValue = startValue
        self.currentTime = startTime
        self.percent = 0
        self.interpolation = interpolation
    }

    var currentTime: TimeInterval {
        didSet {
            let elapsed = currentTime - self.startTime
            self.percent = CGFloat((elapsed / self.duration).clamp(lower: 0, upper: 1))

            let interpolated = interpolation.apply(percent)

            self.currentValue = startValue + range * interpolated
            self.isFinished = percent == 1.0
        }
    }
}
