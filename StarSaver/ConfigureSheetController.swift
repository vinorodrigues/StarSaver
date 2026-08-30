//  ConfigureSheetController.swift
//  StarSaver

import Cocoa
import ScreenSaver

@objc(ConfigureSheetController)
final class ConfigureSheetController: NSWindowController {

  @IBOutlet weak var numberOfStarsField: NSTextField!
  @IBOutlet weak var novaProbabilityField: NSTextField!
  @IBOutlet weak var animationTimingField: NSTextField!

  convenience init() {
    self.init(windowNibName: "ConfigureSheet")
    #if DEBUG
    NSLog("ConfigureSheetController initialized with window: %@", String(describing: window))
    #endif
  }

  override func windowDidLoad() {
    super.windowDidLoad()

    #if DEBUG
    NSLog("ConfigureSheetController windowDidLoad, window: %@", String(describing: window))
    #endif

    let defaults = ScreenSaverDefaults(forModuleWithName: kModuleName)!

    // Load existing preferences
    let numberOfStars = defaults.integer(forKey: kNumberOfStars)
    let novaProbability = defaults.integer(forKey: kNovaProbability)
    let animationTiming = defaults.integer(forKey: kAnimationTiming)

    // Set UI elements
    numberOfStarsField.integerValue = numberOfStars
    novaProbabilityField.integerValue = novaProbability
    animationTimingField.integerValue = animationTiming
  }

  @IBAction func okButtonPressed(_ sender: Any) {
    #if DEBUG
    NSLog("ConfigureSheetController okButtonPressed")
    #endif

    let defaults = ScreenSaverDefaults(forModuleWithName: kModuleName)!

    var numberOfStars = numberOfStarsField.integerValue
    var novaProbability = novaProbabilityField.integerValue
    var animationTiming = animationTimingField.integerValue

    // Validate numberOfStars
    numberOfStars = min(max(numberOfStars, 1), 1000)

    // Validate novaProbability
    novaProbability = min(max(novaProbability, 1), 1000)

    // Validate animationTiming
    animationTiming = min(max(animationTiming, 60), 10000)

    defaults.set(numberOfStars, forKey: kNumberOfStars)
    defaults.set(novaProbability, forKey: kNovaProbability)
    defaults.set(animationTiming, forKey: kAnimationTiming)
    defaults.synchronize()

    window?.sheetParent?.endSheet(window!)
    window?.orderOut(nil)
  }

  @IBAction func cancelButtonPressed(_ sender: Any) {
    #if DEBUG
    NSLog("ConfigureSheetController cancelButtonPressed")
    #endif

    window?.sheetParent?.endSheet(window!)
    window?.orderOut(nil)
  }
}
