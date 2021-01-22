//
//  AppDelegate.swift
//  Pock
//
//  Created by Pierluigi Galdi on 08/09/17.
//  Copyright © 2017 Pierluigi Galdi. All rights reserved.
//

import Cocoa
import Defaults
import Preferences
import AppCenter
import AppCenterAnalytics
import AppCenterCrashes
import Magnet
@_exported import PockKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    static var `default`: AppDelegate {
        return NSApp.delegate as! AppDelegate
    }
    
    /// Core
    public private(set) var alertWindowController: AlertWindowController?
    public private(set) var navController:         PKTouchBarNavigationController?
    
    /// Timer
    fileprivate var automaticUpdatesTimer: Timer?
    
    /// Status bar Pock icon
    fileprivate let pockStatusbarIcon = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    /// Main Pock menu
    private lazy var mainPockMenu: NSMenu = {
        let menu = NSMenu(title: "Pock Options")
		
		/// Version item
		let aboutItem = NSMenuItem(title: "About Pock", action: #selector(openWebsite), keyEquivalent: "")
		
		/// Open Preferences item
		let openPreferencesItem = NSMenuItem(title: "Open Preferences…".localized, action: #selector(openPreferences), keyEquivalent: ",")
		
		/// Open Widgets Manager
		let openWidgestManagerItem = NSMenuItem(title: "Open Widgets Manager…".localized, action: #selector(openWidgetsManager), keyEquivalent: "w")
		
        /// Open Customize window
		let openCustomizeWindowItem = NSMenuItem(title: "Customize Touch Bar…".localized, action: #selector(openCustomization), keyEquivalent: "c")
		
		/// Install new widget
		let openInstallWidgetManagerItem = NSMenuItem(title: "Install Widget…".localized, action: #selector(openInstallWidgetsManager), keyEquivalent: "i")
        
        /// Advanced menu
        let advancedMenuItem = NSMenuItem(title: "Advanced".localized, action: nil, keyEquivalent: "")
        advancedMenuItem.submenu = advancedPockMenu
        
        /// Support item
		let supportItem = NSMenuItem(title: "Support This Project".localized, action: #selector(openDonateURL), keyEquivalent: "s")
        /// Quit item
		let quitItem = NSMenuItem(title: "Quit Pock".localized, action: #selector(NSApp.terminate), keyEquivalent: "q")
		
		let items: [NSMenuItem] = [
			aboutItem,
			openPreferencesItem,
			.separator(),
			openWidgestManagerItem,
			openCustomizeWindowItem,
			openInstallWidgetManagerItem,
			.separator(),
			advancedMenuItem,
			.separator(),
			supportItem,
			quitItem
		]
		items.forEach({ menu.addItem($0) })
		
        return menu
    }()
    
    private lazy var advancedPockMenu: NSMenu = {
        let menu = NSMenu(title: "Advanced".localized)
        let reloadItem = NSMenuItem(title: "Reload Pock".localized, action: #selector(reloadPock), keyEquivalent: "r")
        let relaunchItem = NSMenuItem(title: "Relaunch Pock".localized, action: #selector(relaunchPock), keyEquivalent: "R")
		relaunchItem.isAlternate = true
		let relaunchAgentItem = NSMenuItem(title: "Relaunch Touch Bar Agent".localized, action: #selector(reloadTouchBarAgent), keyEquivalent: "a")
		let relaunchServerItem = NSMenuItem(title: "Relaunch Touch Bar Server".localized, action: #selector(reloadTouchBarServer), keyEquivalent: "A")
		relaunchServerItem.isAlternate = true
        menu.addItem(withTitle: "Re-Install default widgets".localized, action: #selector(installDefaultWidgets), keyEquivalent: "d")
        menu.addItem(NSMenuItem.separator())
		menu.addItem(withTitle: "Show Onboard Screen".localized, action: #selector(showOnboardScreen), keyEquivalent: "o")
		menu.addItem(NSMenuItem.separator())
        menu.addItem(reloadItem)
        menu.addItem(relaunchItem)
		menu.addItem(relaunchAgentItem)
		menu.addItem(relaunchServerItem)
        return menu
    }()
    
    /// Preferences
    private let generalPreferencePane: GeneralPreferencePane = GeneralPreferencePane()
    private lazy var preferencesWindowController: PreferencesWindowController = {
        return PreferencesWindowController(preferencePanes: [generalPreferencePane])
    }()
    
    /// Widgets Manager
    private lazy var widgetsManagerWindowController: PreferencesWindowController = {
        return PreferencesWindowController(
            preferencePanes: [
                WidgetsManagerListPane(),
                WidgetsManagerInstallPane()
            ],
            hidesToolbarForSingleItem: false
        )
    }()
    
    /// Finish launching
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        /// Initialize Crashlytics
        #if !DEBUG
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist") {
            if let secrets = NSDictionary(contentsOfFile: path) as? [String: String], let secret = secrets["AppCenter"] {
                UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
				AppCenter.start(withAppSecret: secret, services: [
					Analytics.self,
					Crashes.self
				])
            }
        }
        #endif
        
        /// Initialise Pock
		self.initialize()
		
		/// Show on board window controller
		if Defaults[.didShowOnboardScreen] == false {
			Defaults[.didShowOnboardScreen] = true
			self.showOnboardScreen()
		}
        
        /// Set Pock inactive
        NSApp.deactivate()

    }
    
    private func initialize() {
        /// Check for accessibility (needed for badges to work)
        self.checkAccessibility()
        
        /// Check for status bar icon
        if let button = pockStatusbarIcon.button {
            button.image = NSImage(named: "pock-inner-icon")
            button.image?.isTemplate = true
            /// Create menu
            pockStatusbarIcon.menu = mainPockMenu
        }
        
        /// Check for updates
        async(after: 1) { [weak self] in
            self?.checkForUpdates()
        }
        
        /// Register for notification
        NSWorkspace.shared.notificationCenter.addObserver(self,
                                                          selector: #selector(toggleAutomaticUpdatesTimer),
                                                          name: .shouldEnableAutomaticUpdates,
                                                          object: nil)
        
        NSWorkspace.shared.notificationCenter.addObserver(self,
                                                          selector: #selector(reloadPock),
                                                          name: .shouldReloadPock,
                                                          object: nil)
        toggleAutomaticUpdatesTimer()
        registerGlobalHotKey()
        
        /// Present Pock
        reloadPock()
    }
    
    @objc func reloadPock() {
        navController?.dismiss()
        navController = nil
        let mainController: PockMainController = PockMainController.load()
        navController = PKTouchBarNavigationController(rootController: mainController)
    }
    
    @objc func relaunchPock() {
        PockHelper.default.relaunchPock()
    }
	
	@objc func reloadTouchBarAgent() {
		TouchBarHelper.reloadTouchBarAgent()
	}
    
    @objc func reloadTouchBarServer() {
        TouchBarHelper.reloadTouchBarServer() { [weak self] success in
            if success {
                self?.reloadPock()
            }
        }
    }
    
    @objc func installDefaultWidgets() {
        PockHelper.default.installDefaultWidgets(nil)
    }
    
    private func registerGlobalHotKey() {
        if let keyCombo = KeyCombo(doubledCocoaModifiers: .control) {
            let hotKey = HotKey(identifier: "TogglePock", keyCombo: keyCombo, target: self, action: #selector(togglePock))
            hotKey.register()
        }
    }
    
    @objc private func togglePock() {
		if navController == nil || NSFunctionRow.activeFunctionRows().count == 1 {
            reloadPock()
        }else {
            navController?.dismiss()
            navController = nil
        }
    }
    
    @objc private func toggleAutomaticUpdatesTimer() {
        if Defaults[.enableAutomaticUpdates] {
            automaticUpdatesTimer = Timer.scheduledTimer(timeInterval: 86400 /*24h*/, target: self, selector: #selector(checkForUpdates), userInfo: nil, repeats: true)
        }else {
            automaticUpdatesTimer?.invalidate()
            automaticUpdatesTimer = nil
        }
    }
    
    /// Will terminate
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        NotificationCenter.default.removeObserver(self)
        navController?.dismiss()
        navController = nil
    }
    
    /// Check for updates
    @objc private func checkForUpdates() {
        generalPreferencePane.hasLatestVersion(completion: { [weak self] latestVersion in
            guard let latestVersion = latestVersion else {
				return
			}
            self?.generalPreferencePane.newVersionAvailable = (latestVersion)
            async { [weak self] in
                self?.openPreferences()
            }
        })
    }
    
    /// Check for accessibility
    @discardableResult
    private func checkAccessibility() -> Bool {
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options = [checkOptPrompt: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary?)
        return accessEnabled
    }
    
    /// Open preferences
    @objc private func openPreferences() {
        preferencesWindowController.show()
    }
    
    /// Open customization
    @objc private func openCustomization() {
        (navController?.rootController as? PockMainController)?.openCustomization()
    }
    
    /// Open widgets manager
    @objc internal func openWidgetsManager() {
		widgetsManagerWindowController.show(preferencePane: .widgets_manager_list)
    }
	
	@objc internal func openInstallWidgetsManager() {
		widgetsManagerWindowController.show(preferencePane: .widgets_manager_install)
	}
    
	/// Open website
	@objc private func openWebsite() {
		guard let url = URL(string: "https://pock.dev") else { return }
		NSWorkspace.shared.open(url)
	}
	
    /// Open donate url
    @objc private func openDonateURL() {
        guard let url = URL(string: "https://paypal.me/pigigaldi") else { return }
        NSWorkspace.shared.open(url)
    }
	
	/// Show On Board screen
	@objc private func showOnboardScreen() {
		let onboardController = OnboardWindowController()
		onboardController.showWindow(self)
	}
    
}
