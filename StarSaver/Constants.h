//  Constants.h
//  StarSaver

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kModuleName;

extern NSString * const  kNumberOfStars;
extern NSString * const  kNovaProbability;
extern NSString * const  kAnimationTiming;

// Posted (via the default NSNotificationCenter) each time a StarSaverView
// instance starts, so older instances in the same process can detect that
// they've been superseded and deactivate themselves. Works around macOS
// (Sonoma+) sometimes leaving stale instances running instead of tearing
// them down.
extern NSString * const kStarSaverInstanceDidStartNotification;

NS_ASSUME_NONNULL_END
