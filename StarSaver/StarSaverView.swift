//  StarSaverView.swift
//  StarSaver
//
//  Commander Starry Night Screen Saver
//  A clone of the old Norton Commander 4 Saver
//
//  ©️ 2024 Silvino Rodrigues
//
//  @see: https://developer.apple.com/documentation/screensaver

import Cocoa
import ScreenSaver

// Size of stars as in resource files
private let starCellWidth: CGFloat = 14
private let starCellHeight: CGFloat = 14

enum StarState {
  case gone
  case normal
  case exploding
  case novaState1
  case novaState2
  case novaState3
}

final class Star: NSObject {
  var state: StarState = .gone
  var position: NSPoint = .zero
  var offset: NSPoint = .zero
}

@objc(StarSaverView)
final class StarSaverView: ScreenSaverView {

  private var starImages: [NSImage] = []      // star1.png to star5.png
  private var stars: [Star] = []
  private var starHead: Int = 0                // Current star being processed
  private var isRunning = false                // Controls animation

  // Private vars
  private var width: CGFloat = 1               // Width of screen at `init`
  private var height: CGFloat = 1              // Height of screen at `init`
  private var cols: Int = 1                    // Width / {star resources width}
  private var rows: Int = 1                    // Height / {star resources height}
  private var doOffsets = false                // To offset or not

  private var configureSheetController: ConfigureSheetController?

  private var numberOfStars: Int = 0           // Number of stars
  private var novaProbability: Int = 25        // Probability for Nova (1 in X chance)
  private var animationTiming: Int = 250       // Animation timing in milliseconds

  // Unique per-instance ID, and stop/teardown bookkeeping.
  // Works around macOS (Sonoma+) bugs where `stopAnimation` is not
  // reliably called, and where stale/duplicate instances or the host
  // process are not reliably torn down.
  private var instanceID = UUID().uuidString
  private var lameDuck = false
  private var forceExitTimer: Timer?

  // ==================================================
  // MARK: - Init Methods
  // ==================================================

  /* ------------------------------
   * Initializer for normal and preview mode
   * ------------------------------ */
  override init?(frame: NSRect, isPreview: Bool) {
    super.init(frame: frame, isPreview: isPreview)
    #if DEBUG
    NSLog("StarSaverView initWithFrame:isPreview:%@", isPreview ? "YES" : "NO")
    #endif
    internalInit()
  }

  /* ------------------------------
   * Initializer for coder-based initialization
   * ------------------------------ */
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    #if DEBUG
    NSLog("StarSaverView initWithCoder:")
    #endif
    internalInit()
  }

  /* ------------------------------
   * Consolidated initialisation method
   * ------------------------------ */
  private func internalInit() {
    #if DEBUG
    NSLog("StarSaverView internalInit")
    #endif
    isRunning = false
    instanceID = UUID().uuidString
    lameDuck = false
    registerForLifecycleNotifications()

    // ----- Get the size of the screen -----

    width = bounds.size.width > 0 ? bounds.size.width : 1
    height = bounds.size.height > 0 ? bounds.size.height : 1
    cols = max(1, Int(floor(width / starCellWidth)))
    rows = max(1, Int(floor(height / starCellHeight)))
    #if DEBUG
    NSLog("StarSaverView internalInit self.width = %f, self.height = %f", width, height)
    NSLog("StarSaverView internalInit self.cols = %ld, self.rows = %ld", cols, rows)
    #endif

    // ----- Preferences -----

    // Default to 1% of the cell count
    // On Legacy iMac 27" that's `((2560/14)*(1440/14))*0.01` = `188`
    // Have not tested this on a Retina display :(
    let fallbackNumberOfStars = Int(floor(Double(rows * cols) * 0.01))
    // Default Nova probability to 1 in 25
    let fallbackNovaProbability = 25
    // Default animation timing set so that each star lives for aprox. 1 m
    let fallbackAnimationTiming: Int
    if numberOfStars > 0 {
      fallbackAnimationTiming = Int(floor((1000 * 60) / (Double(fallbackNumberOfStars) / 2.0)))
    } else {
      fallbackAnimationTiming = 250
    }

    let defaults = ScreenSaverDefaults(forModuleWithName: kModuleName)!

    // Register default preferences
    defaults.register(defaults: [
      kNumberOfStars: fallbackNumberOfStars,
      kNovaProbability: fallbackNovaProbability,
      kAnimationTiming: fallbackAnimationTiming
    ])

    // ----- Set up self vars -----

    // Load user configuration
    loadPreferences()

    if !isMiniPreview {
      starHead = numberOfStars / 4
    } else {
      starHead = numberOfStars - 1  // Set to end of star array
    }

    #if DEBUG
    NSLog("StarSaverView internalInit self. .. numberOfStars = %ld, novaProbability = %ld, animationTiming = %ld, starHead = %ld",
          numberOfStars, novaProbability, animationTiming, starHead)
    #endif

    // ----- Load Images -----

    // Load all the star images (`star1.png` to `star5.png`)
    let bundle = Bundle(for: type(of: self))
    var loadedImages: [NSImage] = []
    for i in 1...5 {
      if let imagePath = bundle.path(forResource: "star\(i)", ofType: "png"),
         let image = NSImage(contentsOfFile: imagePath) {
        loadedImages.append(image)
      }
    }
    starImages = loadedImages

    // ----- Initialise the Stars -----

    // Build the star array with initial random positions
    var newStars: [Star] = []
    for i in 0..<numberOfStars {
      let star = Star()
      if i >= starHead {
        star.state = .gone
      } else {
        star.state = .normal
        star.position = randomPosition()
        star.offset = doOffsets ? randomOffset() : NSPoint(x: 0, y: 0)
      }
      newStars.append(star)
    }
    stars = newStars

    // ----- Set up timer -----

    // Needs `animateOneFrame`
    animationTimeInterval = TimeInterval(animationTiming) / 1000.0  // settings is in ms
  }

  // ==================================================
  // MARK: - Preference Methods
  // ==================================================

  /* ------------------------------
   * Load the screen saver settings
   * ------------------------------ */
  private func loadPreferences() {
    #if DEBUG
    NSLog("StarSaverView loadPreferences")
    #endif

    if !isMiniPreview {
      let defaults = ScreenSaverDefaults(forModuleWithName: kModuleName)!

      numberOfStars = defaults.integer(forKey: kNumberOfStars)
      novaProbability = defaults.integer(forKey: kNovaProbability)
      animationTiming = defaults.integer(forKey: kAnimationTiming)
    } else {
      numberOfStars = 10     // Set to 5 stars for smaller screens
      novaProbability = 25   // 1 in 25 probability
      animationTiming = 2000 // Set to 2 seconds for smaller screens
    }
  }

  // ==================================================
  // MARK: - Private Helper Methods
  // ==================================================

  /* ------------------------------
   * Assess if in System Preferences mini view
   * ------------------------------ */
  private var isMiniPreview: Bool {
    return isPreview && bounds.size.width < 640
  }

  /* ------------------------------
   * Generate random co-ordinates
   * ------------------------------ */
  private func randomPosition() -> NSPoint {
    return NSPoint(x: CGFloat(randomInt(0, cols)), y: CGFloat(randomInt(0, rows)))
  }

  /* ------------------------------
   * Generate random offsets
   * ------------------------------ */
  private func randomOffset() -> NSPoint {
    return NSPoint(x: CGFloat(randomInt(0, Int(starCellWidth))), y: CGFloat(randomInt(0, Int(starCellHeight))))
  }

  /* ------------------------------
   * Get the Rect that the star lives in
   * ------------------------------ */
  private func starRect(for star: Star) -> NSRect {
    var ox = Int(star.offset.x)
    var oy = Int(star.offset.y)

    // adjust so that it's not off screen
    while (star.position.x * starCellWidth) + CGFloat(ox) > width {
      ox -= 1
    }
    while (star.position.y * starCellHeight) + CGFloat(oy) > height {
      oy -= 1
    }

    return NSRect(x: (star.position.x * starCellWidth) + CGFloat(ox),
                  y: (star.position.y * starCellHeight) + CGFloat(oy),
                  width: starCellWidth,
                  height: starCellHeight)
  }

  /* ------------------------------
   * Draw star at n-th position
   * ------------------------------ */
  private func drawStar(at index: Int) {
    #if DEBUG
    NSLog("StarSaverView drawStarAt:%ld", index)
    #endif

    let star = stars[index]  // Get the star at the head position

    // Select the appropriate star image based on Nova stage
    let starImage: NSImage?
    switch star.state {
    case .normal:
      starImage = starImages[0]
    case .exploding:
      starImage = starImages[1]
    case .novaState1:
      starImage = starImages[2]
    case .novaState2:
      starImage = starImages[3]
    case .novaState3:
      starImage = starImages[4]
    default:
      starImage = nil
    }

    // Draw the star
    starImage?.draw(in: starRect(for: star))
  }

  // ==================================================
  // MARK: - Key Screen Saver Methods
  // ==================================================

  override func startAnimation() {
    #if DEBUG
    NSLog("StarSaverView startAnimation")
    #endif
    super.startAnimation()

    loadPreferences()

    // A fresh start means the host process is alive and reusing this view;
    // cancel any pending safety-net exit from a previous stop.
    forceExitTimer?.invalidate()
    forceExitTimer = nil
    lameDuck = false

    isRunning = true
    needsDisplay = true  // redraw the whole screen
  }

  override func stopAnimation() {
    #if DEBUG
    NSLog("StarSaverView stopAnimation")
    #endif
    super.stopAnimation()

    deactivate()
    scheduleForceExit()
  }

  /* ------------------------------
   * Draw area needed
   * ------------------------------ */
  override func draw(_ rect: NSRect) {
    super.draw(rect)

    #if DEBUG
    NSLog("StarSaverView drawRect (%f, %f, %f, %f)",
          rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)
    #endif

    // Fill the background with black
    NSColor.black.setFill()
    rect.fill()

    // Draw the stars if needed
    for i in 0..<numberOfStars {
      let star = stars[i]
      if rect.contains(starRect(for: star)) {
        drawStar(at: i)
      }
    }
  }

  /* ------------------------------
   * Gets called repeatedly to draw states on timer ticks
   * when used with `animationTimeInterval`
   * ------------------------------ */
  override func animateOneFrame() {
    super.animateOneFrame()

    #if DEBUG
    NSLog("StarSaverView animateOneFrame")
    #endif

    if isRunning {
      timerTick()
    }
  }

  /* ---------------------------------
   * Abstracting Timer Ticks here
   * --------------------------------- */
  private func timerTick() {
    #if DEBUG
    NSLog("StarSaverView timerTick (%ld)", starHead)
    #endif

    let index = starHead
    let star = stars[index]  // Get the star at the head position
    var newState: StarState = .normal

    switch star.state {
    case .normal:
      newState = .exploding
    case .exploding:
      newState = randomInt(0, novaProbability) == 0 ? .novaState1 : .gone
    case .novaState1:
      newState = .novaState2
    case .novaState2:
      newState = .novaState3
    case .novaState3:
      newState = .gone
    case .gone:
      // Invalidate old position
      setNeedsDisplay(starRect(for: star))

      // New position
      star.position = randomPosition()  // new position
      if doOffsets {
        star.offset = randomOffset()  // new offset
      }

      // inc the header, i.e. move on to the next star
      starHead += 1
      if starHead >= numberOfStars {
        starHead = 0  // restart
      }
    }

    star.state = newState

    // Force the star area to redraw
    setNeedsDisplay(starRect(for: star))
  }

  // ==================================================
  // MARK: - Lifecycle Workarounds
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
  private func registerForLifecycleNotifications() {
    let nc = NotificationCenter.default

    nc.addObserver(self,
                   selector: #selector(handleInstanceDidStart(_:)),
                   name: kStarSaverInstanceDidStartNotification,
                   object: nil)

    // Sonoma+ sometimes fails to call `stopAnimation`; this notification is
    // the more reliable signal that the screen saver is actually stopping.
    nc.addObserver(self,
                   selector: #selector(handleScreenSaverWillStop(_:)),
                   name: NSNotification.Name("com.apple.screensaver.willstop"),
                   object: nil)

    // Any instance already alive will see this and deactivate itself, since
    // it's necessarily older than whichever instance is announcing itself now.
    nc.post(name: kStarSaverInstanceDidStartNotification, object: instanceID)
  }

  /* ------------------------------
   * A newer sibling instance has just started; this one has been superseded.
   * ------------------------------ */
  @objc private func handleInstanceDidStart(_ notification: Notification) {
    if let startedInstanceID = notification.object as? String, startedInstanceID != instanceID {
      #if DEBUG
      NSLog("StarSaverView superseded by instance %@, deactivating", startedInstanceID)
      #endif
      deactivate()
    }
  }

  /* ------------------------------
   * ------------------------------ */
  @objc private func handleScreenSaverWillStop(_ notification: Notification) {
    #if DEBUG
    NSLog("StarSaverView handleScreenSaverWillStop")
    #endif
    deactivate()
    scheduleForceExit()
  }

  /* ------------------------------
   * Stop animating/drawing and stop listening for further start
   * announcements. Idempotent.
   * ------------------------------ */
  private func deactivate() {
    if lameDuck {
      return
    }
    lameDuck = true
    isRunning = false
    NotificationCenter.default.removeObserver(self, name: kStarSaverInstanceDidStartNotification, object: nil)
  }

  /* ------------------------------
   * Safety net: if the host process fails to terminate on its own after
   * this view has stopped, exit directly rather than leaking a zombie
   * process that wastes CPU/memory.
   * ------------------------------ */
  private func scheduleForceExit() {
    if forceExitTimer != nil {
      return
    }
    forceExitTimer = Timer.scheduledTimer(timeInterval: 65.0,
                                           target: self,
                                           selector: #selector(forceExit),
                                           userInfo: nil,
                                           repeats: false)
  }

  /* ------------------------------
   * ------------------------------ */
  @objc private func forceExit() {
    #if DEBUG
    NSLog("StarSaverView forceExit: host process did not terminate in time, exiting directly")
    #endif
    // `exit(0)` rather than `NSApplication.terminate(_:)` to avoid black-screen
    // races during teardown.
    exit(0)
  }

  deinit {
    forceExitTimer?.invalidate()
    NotificationCenter.default.removeObserver(self)
  }

  // ==================================================
  // MARK: - Configuration Sheet Methods
  // ==================================================

  override var hasConfigureSheet: Bool {
    #if DEBUG
    NSLog("StarSaverView hasConfigureSheet")
    #endif
    return true
  }

  override var configureSheet: NSWindow? {
    #if DEBUG
    NSLog("StarSaverView configureSheet")
    #endif

    if configureSheetController == nil {
      configureSheetController = ConfigureSheetController()
    }
    #if DEBUG
    if configureSheetController?.window == nil {
      NSLog("Error: configureSheetController.window is nil")
    } else {
      NSLog("Returning configureSheetController.window: %@", String(describing: configureSheetController?.window))
    }
    #endif
    return configureSheetController?.window
  }
}

/* ------------------------------
 * Random int in `[min, max]`, matching the range semantics of the
 * Objective-C `SSRandomIntBetween` this ported from.
 * ------------------------------ */
private func randomInt(_ minValue: Int, _ maxValue: Int) -> Int {
  return Int(SSRandomIntBetween(Int32(minValue), Int32(maxValue)))
}
