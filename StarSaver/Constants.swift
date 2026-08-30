//  Constants.swift
//  StarSaver

import Foundation

let kModuleName = "com.silvinor.StarSaver"

let kNumberOfStars = "numberOfStars"
let kNovaProbability = "novaProbability"
let kAnimationTiming = "animationTiming"

// Posted (via the default NotificationCenter) each time a StarSaverView
// instance starts, so older instances in the same process can detect that
// they've been superseded and deactivate themselves. Works around macOS
// (Sonoma+) sometimes leaving stale instances running instead of tearing
// them down.
let kStarSaverInstanceDidStartNotification = Notification.Name("com.silvinor.StarSaver.instanceDidStart")
