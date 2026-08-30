/*
 * Commander Starry Night Screen Saver
 * A clone of the old Norton Commander 4 Saver
 *
 * ©️ 2024 Silvino Rodrigues
 *
 * @see: https://developer.apple.com/documentation/screensaver?language=objc
 */

#import "StarSaverView.h"
#import "ConfigureSheetController.h"
#import "Constants.h"
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <math.h>

@implementation Star
@end

@interface StarSaverView ()
  // Private vars
  @property (nonatomic, assign) CGFloat width;   // Width of screen at `init`
  @property (nonatomic, assign) CGFloat height;  // Height of screen at `init`
  @property (nonatomic, assign) NSInteger cols;  // Width / {star resources width}
  @property (nonatomic, assign) NSInteger rows;  // Height / {star resources height}
  @property (nonatomic, assign) BOOL doOffsets;  // To offset or not

  @property (strong) ConfigureSheetController *configureSheetController;

  @property (assign) NSInteger numberOfStars;    // Number of stars
  @property (assign) NSInteger novaProbability;  // Probability for Nova (1 in X chance)
  @property (assign) NSInteger animationTiming;  // Animation timing in milliseconds

  // Unique per-instance ID, and stop/teardown bookkeeping.
  // Works around macOS (Sonoma+) bugs where `stopAnimation` is not
  // reliably called, and where stale/duplicate instances or the host
  // process are not reliably torn down.
  @property (nonatomic, copy) NSString *instanceID;
  @property (nonatomic, assign, getter=isLameDuck) BOOL lameDuck;
  @property (nonatomic, strong) NSTimer *forceExitTimer;

  // Private methods
  - (NSPoint)randomPosition;
  - (NSPoint)randomOffset;
  - (NSRect)getStarRect:(Star*)star;
  - (void)internalInit;
  - (BOOL)isMiniPreview;
  - (void)registerForLifecycleNotifications;
  - (void)handleInstanceDidStart:(NSNotification *)notification;
  - (void)handleScreenSaverWillStop:(NSNotification *)notification;
  - (void)deactivate;
  - (void)scheduleForceExit;
  - (void)forceExit;
@end

@implementation StarSaverView

// ==================================================
#pragma mark - Init Methods
// ==================================================

/* ------------------------------
 * Initializer for normal and preview mode
 * ------------------------------ */
- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
  self = [super initWithFrame:frame isPreview:isPreview];
  #ifdef DEBUG
  NSLog(@"StarSaverView initWithFrame:isPreview:%@", isPreview ? @"YES" : @"NO");
  #endif
  if (self) {
    [self internalInit];
  }
  return self;
}

/* ------------------------------
 * Initializer for coder-based initialization
 * ------------------------------ */
- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  #ifdef DEBUG
  NSLog(@"StarSaverView initWithCoder:");
  #endif
  if (self) {
    [self internalInit];
  }
  return self;
}

/* ------------------------------
 * Consolidated initialisation method
 * ------------------------------ */
- (void)internalInit {
  #ifdef DEBUG
  NSLog(@"StarSaverView internalInit");
  #endif
  self.isRunning = false;
  self.instanceID = [[NSUUID UUID] UUIDString];
  self.lameDuck = NO;
  [self registerForLifecycleNotifications];

  // ----- Initialize RandomSeed -----

  #ifdef DEBUG
  NSLog(@"StarSaverView internalInit A");
  #endif
  // Use the current time to set a unique seed
  srand((unsigned int)time(NULL));  // used by `rand()`
  srandom((unsigned int)time(NULL));  // used by `random()`

  // ----- Get the size of the screen -----

  #ifdef DEBUG
  NSLog(@"StarSaverView internalInit B");
  #endif
  self.width = self.bounds.size.width; if (self.width <= 0) { self.width = 1; }
  self.height = self.bounds.size.height; if (self.height <= 0) { self.width = 1; }
  self.cols = floor( self.width / STAR_CELL_WIDTH ); if (self.cols <= 0) { self.cols = 1; }
  self.rows = floor( self.height / STAR_CELL_HEIGHT ); if (self.rows <= 0) { self.rows = 1; }
  #ifdef DEBUG
  NSLog(@"StarSaverView internalInit self.width = %ld, self.height = %ld", (long)self.width, (long)self.height);
  NSLog(@"StarSaverView internalInit self.cols = %ld, self.rows = %ld", (long)self.cols, (long)self.rows);
  #endif
  
  // ----- Preferences -----

  #ifdef DEBUG
  NSLog(@"StarSaverView internalInit C");
  #endif
  NSNumber *fallbackNumberOfStars;
  NSNumber *fallbackNovaProbability;
  NSNumber *fallbackAnimationTiming;

  // Default to 1% of the cell count
  // On Legacy iMac 27" that's `((2560/14)*(1440/14))*0.01` = `188`
  // Have not tested this on a Retina display :(
  fallbackNumberOfStars = @(floor((self.rows * self.cols) * 0.01));
  // Default Nova probability to 1 in 25
  fallbackNovaProbability = @(25);
  // Default animation timing set so that each star lives for aprox. 1 m
  if (self.numberOfStars > 0) {
    fallbackAnimationTiming = @(floor((1000 * 60) / ([fallbackNumberOfStars intValue] / 2.0)));
    // fallbackAnimationTiming = @(floor((1000 * 60) / ((int)fallbackNumberOfStars / 2)));
  } else {
    fallbackAnimationTiming = @(250);
  }

  #ifdef DEBUG
  NSLog(@"StarSaverView internalInit 1");
  #endif
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:kModuleName];

  #ifdef DEBUG
  NSLog(@"StarSaverView internalInit D");
  #endif
  // Register default preferences
  [defaults registerDefaults:@{
    kNumberOfStars: fallbackNumberOfStars,
    kNovaProbability: fallbackNovaProbability,
    kAnimationTiming: fallbackAnimationTiming
    }];

  // ----- Set up self vars -----

  // Load user configuration
  #ifdef DEBUG
  NSLog(@"StarSaverView internalInit E");
  #endif
  [self loadPreferences];

  if (!self.isMiniPreview) {
    #ifdef DEBUG
    NSLog(@"StarSaverView internalInit E.1");
    #endif
    self.starHead = floor( self.numberOfStars / 4);
  } else {
    #ifdef DEBUG
    NSLog(@"StarSaverView internalInit E.2");
    #endif
    self.starHead = self.numberOfStars - 1; // Set to end of star array
  }
  
  #ifdef DEBUG
  NSLog(@"StarSaverView internalInit self. .. numberOfStars = %ld, novaProbability = %ld, animationTiming = %ld, starHead = %ld",
        (long)self.numberOfStars,
        (long)self.novaProbability,
        (long)self.animationTiming,
        (long)self.starHead );
  #endif
  
  // ----- Load Images -----
  
  #ifdef DEBUG
  NSLog(@"StarSaverView internalInit F");
  #endif
  // Load all the star images (`star1.png` to `star5.png`)
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSMutableArray *loadedImages = [NSMutableArray array];
  for (int i = 1; i <= 5; i++) {
    NSString *imagePath = [bundle pathForResource:[NSString stringWithFormat:@"star%d", i] ofType:@"png"];
    if (imagePath) {
      NSImage *image = [[NSImage alloc] initWithContentsOfFile:imagePath];
      if (image) {
        [loadedImages addObject:image];
      }
    }
  }
  self.starImages = [loadedImages copy];
  
  // ----- Initialise the Stars -----
 
  #ifdef DEBUG
  NSLog(@"StarSaverView internalInit G");
  #endif
  // Initialize the stars array
  self.stars = [NSMutableArray array];

  // Build the star array with initial random positions
  for (NSInteger i = 0; i < self.numberOfStars; i++) {
    Star *star = [[Star alloc] init];
    if (i >= self.starHead) {
      star.state = StarStateGone;
    } else {
      star.state = StarStateNormal;
      star.position = self.randomPosition;
      if (self.doOffsets) {
        star.offset = self.randomOffset;
      } else {
        star.offset = NSMakePoint(0, 0);
      }
    }
    [self.stars addObject:star];
  }

  // ----- Set up timer -----
  
  #ifdef DEBUG
  NSLog(@"StarSaverView internalInit H");
  #endif
  // Needs `animateOneFrame`
  NSTimeInterval interval = self.animationTiming / 1000.0;  // settings is in ms
  [self setAnimationTimeInterval:interval];
}

// ==================================================
#pragma mark - Preference Methods
// ==================================================

/* ------------------------------
 * Load the screen saver settings
 * ------------------------------ */
- (void)loadPreferences {
  #ifdef DEBUG
  NSLog(@"StarSaverView loadPreferences");
  #endif
  
  if (!self.isMiniPreview) {
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:kModuleName];

    self.numberOfStars = [defaults integerForKey:kNumberOfStars];
    self.novaProbability = [defaults integerForKey:kNovaProbability];
    self.animationTiming = [defaults integerForKey:kAnimationTiming];
  } else {
    self.numberOfStars = 10;     // Set to 5 stars for smaller screens
    self.novaProbability = 25;   // 1 in 25 probability
    self.animationTiming = 2000; // Set to 2 seconds for smaller screens
  }
}

// ==================================================
#pragma mark - Private Helper Methods
// ==================================================

/* ------------------------------
 * Assess if in System Preferences mini view
 * ------------------------------ */
- (BOOL)isMiniPreview {
  return self.isPreview && (self.bounds.size.width < 640);
}

/* ------------------------------
 * Generate random co-ordinates
 * ------------------------------ */
- (NSPoint)randomPosition {
  return NSMakePoint( SSRandomIntBetween(0, (int)self.cols),
                      SSRandomIntBetween(0, (int)self.rows) );
}

/* ------------------------------
 * Generate random offsets
 * ------------------------------ */
- (NSPoint)randomOffset {
  return NSMakePoint( SSRandomIntBetween(0, (int)STAR_CELL_WIDTH),
                      SSRandomIntBetween(0, (int)STAR_CELL_HEIGHT) );
}

/* ------------------------------
 * Get the Rect that the star lives in
 * ------------------------------ */
- (NSRect)getStarRect:(Star *)star {
  NSInteger ox = star.offset.x;
  NSInteger oy = star.offset.y;

  // adjust so that it's not off screen
  while (((star.position.x * STAR_CELL_WIDTH) + ox) > self.width) {
    ox--;
  }
  while (((star.position.y * STAR_CELL_HEIGHT) + oy) > self.height) {
    oy--;
  }
  
  return NSMakeRect( (star.position.x * STAR_CELL_WIDTH) + ox,
                    (star.position.y * STAR_CELL_HEIGHT) + oy,
                    STAR_CELL_WIDTH,
                    STAR_CELL_HEIGHT );
}

/* ------------------------------
 * Draw star at n-th position
 * ------------------------------ */
- (void)drawStarAt:(NSInteger)index {
  #ifdef DEBUG
  NSLog(@"StarSaverView drawStarAt:%ld", (long)index);
  #endif

  NSImage *starImage;
  Star *star = [self.stars objectAtIndex:(index)];  // Get the start at the head position

  // Select the appropriate star image based on Nova stage
  switch (star.state) {
    case StarStateNormal:
      starImage = self.starImages[0];
      break;
    case StarStateExploding:
      starImage = self.starImages[1];
      break;
    case StarStateNovaState1:
      starImage = self.starImages[2];
      break;
    case StarStateNovaState2:
      starImage = self.starImages[3];
      break;
    case StarStateNovaState3:
      starImage = self.starImages[4];
      break;
    default:
      starImage = nil;
      break;
  }

  // Draw the star
  if (starImage != nil) {
    [starImage drawInRect:[self getStarRect:star]];
  }
}

// ==================================================
#pragma mark - Key Screen Saver Methods
// ==================================================

/* ------------------------------ */
- (void)startAnimation {
  #ifdef DEBUG
  NSLog(@"StarSaverView startAnimation");
  #endif
  [super startAnimation];

  [self loadPreferences];

  // A fresh start means the host process is alive and reusing this view;
  // cancel any pending safety-net exit from a previous stop.
  [self.forceExitTimer invalidate];
  self.forceExitTimer = nil;
  self.lameDuck = NO;

  self.isRunning = YES;
  [self setNeedsDisplay:YES];  // redraw the whole screen
}

/* ------------------------------ */
- (void)stopAnimation {
  #ifdef DEBUG
  NSLog(@"StarSaverView stopAnimation");
  #endif
  [super stopAnimation];

  [self deactivate];
  [self scheduleForceExit];
}

/* ------------------------------
 * Draw area needed
 * ------------------------------ */
- (void)drawRect:(NSRect)rect {
  [super drawRect:rect];
  
  #ifdef DEBUG
  NSLog(@"StarSaverView drawRect (%ld, %ld, %ld, %ld)",
    (long)rect.origin.x,
    (long)rect.origin.y,
    (long)rect.size.width,
    (long)rect.size.height );
  #endif
  
  // Fill the background with black
  [[NSColor blackColor] setFill];
  NSRectFill(rect);  // Fill the rect with black

  // Draw the stars if needed
  for (NSInteger i = 0; i < self.numberOfStars; i++) {
    Star *star = [self.stars objectAtIndex:(i)];
    if (NSContainsRect( rect, [self getStarRect:star] )) {
      [self drawStarAt:i];
    }
  }
}

/* ------------------------------
 * Gets called repeatedly to draw states on timer ticks
 * when used with `setAnimationTimeInterval`
 * ------------------------------ */
- (void)animateOneFrame {
  [super animateOneFrame];
  
  #ifdef DEBUG
  NSLog(@"StarSaverView animateOneFrame");
  #endif
  
  if (self.isRunning) {
    [self timerTick];
  }
  return;
}

/* ---------------------------------
 * Abstracting Timer Ticks here
 * --------------------------------- */
- (void)timerTick {
  #ifdef DEBUG
  NSLog(@"StarSaverView timerTick (%ld)", (long)self.starHead);
  #endif
  
  NSInteger index = self.starHead;
  
  Star *star = [self.stars objectAtIndex:(index)];  // Get the start at the head position
  StarState newState = StarStateNormal;

  switch (star.state) {
    case StarStateNormal:
      newState = StarStateExploding;
      break;
    case StarStateExploding:
      if (SSRandomIntBetween(0, (int)self.novaProbability) == 0) {
        newState = StarStateNovaState1;
      } else {
        newState = StarStateGone;
      }
      break;
    case StarStateNovaState1:
      newState = StarStateNovaState2;
      break;
    case StarStateNovaState2:
      newState = StarStateNovaState3;
      break;
    case StarStateNovaState3:
      newState = StarStateGone;
      break;
    default: // StarSateGone
      
      // Invalidate old position
      [self setNeedsDisplayInRect:[self getStarRect:star]];

      // New position
      star.position = self.randomPosition;  // new position
      if (self.doOffsets) {
        star.offset = self.randomOffset;  // new offset
      }
  
      // inc the header, i.e. move on to the next star
      self.starHead++;
      if (self.starHead >= self.numberOfStars) {
        self.starHead = 0;  // restart
      }
      break;
  }

  star.state = newState;

  // Force the star area to redraw
  [self setNeedsDisplayInRect:[self getStarRect:star]];
}

// ==================================================
#pragma mark - Lifecycle Workarounds
//
// macOS Sonoma+ has known bugs where `stopAnimation` is not reliably
// called, duplicate instances can be spawned without the old ones being
// torn down, and the host `legacyScreenSaver` process can fail to
// terminate after all views have stopped. The methods below are
// self-contained workarounds for those cases.
// ==================================================

/* ------------------------------
 * Subscribe to the notifications needed to detect a real stop, and
 * announce this instance so any older sibling instance can deactivate.
 * ------------------------------ */
- (void)registerForLifecycleNotifications {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

  [nc addObserver:self
         selector:@selector(handleInstanceDidStart:)
             name:kStarSaverInstanceDidStartNotification
           object:nil];

  // Sonoma+ sometimes fails to call `stopAnimation`; this notification is
  // the more reliable signal that the screen saver is actually stopping.
  [nc addObserver:self
         selector:@selector(handleScreenSaverWillStop:)
             name:@"com.apple.screensaver.willstop"
           object:nil];

  // Any instance already alive will see this and deactivate itself, since
  // it's necessarily older than whichever instance is announcing itself now.
  [nc postNotificationName:kStarSaverInstanceDidStartNotification object:self.instanceID];
}

/* ------------------------------
 * A newer sibling instance has just started; this one has been superseded.
 * ------------------------------ */
- (void)handleInstanceDidStart:(NSNotification *)notification {
  NSString *startedInstanceID = notification.object;
  if (startedInstanceID != nil && ![startedInstanceID isEqualToString:self.instanceID]) {
    #ifdef DEBUG
    NSLog(@"StarSaverView superseded by instance %@, deactivating", startedInstanceID);
    #endif
    [self deactivate];
  }
}

/* ------------------------------
 * ------------------------------ */
- (void)handleScreenSaverWillStop:(NSNotification *)notification {
  #ifdef DEBUG
  NSLog(@"StarSaverView handleScreenSaverWillStop");
  #endif
  [self deactivate];
  [self scheduleForceExit];
}

/* ------------------------------
 * Stop animating/drawing and stop listening for further start
 * announcements. Idempotent.
 * ------------------------------ */
- (void)deactivate {
  if (self.lameDuck) {
    return;
  }
  self.lameDuck = YES;
  self.isRunning = NO;
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                   name:kStarSaverInstanceDidStartNotification
                                                 object:nil];
}

/* ------------------------------
 * Safety net: if the host process fails to terminate on its own after
 * this view has stopped, exit directly rather than leaking a zombie
 * process that wastes CPU/memory.
 * ------------------------------ */
- (void)scheduleForceExit {
  if (self.forceExitTimer != nil) {
    return;
  }
  self.forceExitTimer = [NSTimer scheduledTimerWithTimeInterval:65.0
                                                           target:self
                                                         selector:@selector(forceExit)
                                                         userInfo:nil
                                                          repeats:NO];
}

/* ------------------------------
 * ------------------------------ */
- (void)forceExit {
  #ifdef DEBUG
  NSLog(@"StarSaverView forceExit: host process did not terminate in time, exiting directly");
  #endif
  // `exit(0)` rather than `[NSApplication terminate:]` to avoid black-screen
  // races during teardown.
  exit(0);
}

/* ------------------------------ */
- (void)dealloc {
  [self.forceExitTimer invalidate];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// ==================================================
#pragma mark - Configuration Sheet Methods
// ==================================================

/* ------------------------------
 * ------------------------------ */
- (BOOL)hasConfigureSheet {
  #ifdef DEBUG
  NSLog(@"StarSaverView hasConfigureSheet");
  #endif
  return YES;
}

/* ------------------------------
 * ------------------------------ */
- (NSWindow*)configureSheet {
  #ifdef DEBUG
  NSLog(@"StarSaverView configureSheet");
  #endif
  
  if (!self.configureSheetController) {
    self.configureSheetController = [[ConfigureSheetController alloc] init];
  }
  #ifdef DEBUG
  if (self.configureSheetController.window == nil) {
    NSLog(@"Error: configureSheetController.window is nil");
  } else {
    NSLog(@"Returning configureSheetController.window: %@", self.configureSheetController.window);
  }
  #endif
  return self.configureSheetController.window;
}

@end
