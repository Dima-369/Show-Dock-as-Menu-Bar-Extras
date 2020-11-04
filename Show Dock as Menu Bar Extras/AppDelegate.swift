//
//  AppDelegate.swift
//  Show Dock as Menu Bar Extras
//
//  Created by Gira on 11/3/20.
//  Copyright © 2020 Gira. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var statusBarItems: [NSStatusItem] = []
    
    let iconSize = 18
    let itemSlotWidth = 30
    let menuBarHeight = 22
    
    // todo display warning in menu when emacs is not running?
    
    public var runningApps: [NSRunningApplication] {
        return NSWorkspace.shared.runningApplications.filter{
            // these applications are filtered out because I always launch
            // them via Hammerspoon bindings
            $0.activationPolicy == .regular &&
                $0.localizedName! != "Telegram" &&
                $0.localizedName! != "Emacs" &&
                $0.localizedName! != "iTerm2" &&
                $0.localizedName! != "Finder"
        }
    }
    
    // this only works when the dark menu bar is used in macOS
    func imageForBlackMenuBar(_ image: NSImage) -> NSImage {
        guard let tinted = image.copy() as? NSImage else { return image }
        tinted.lockFocus()
        
        NSColor.init(white: 0.0, alpha: 0.98).set()
        
        let imageRect = NSRect(origin: NSZeroPoint, size: image.size)
        imageRect.fill(using: NSCompositingOperation.hue)
        
        tinted.unlockFocus()
        return tinted
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        trackAppsBeingActivated()
        trackAppsBeingQuit()
        
        updateMenuBar()
    }
    
    func isShowingApp(bundleId: String) -> Bool {
        for item in statusBarItems {
            if item.button!.accessibilityLabel() == bundleId {
                return true
            }
        }
        
        return false
    }
    
    func updateMenuBar() {
        let apps = runningApps
        
        for item in statusBarItems {
            let itemBundleId = item.button!.accessibilityLabel()!
            var isAppStillRunning = false
            
            for app in apps {
                if itemBundleId == app.bundleIdentifier! {
                    isAppStillRunning = true
                    break
                }
            }
            
            if !isAppStillRunning {
                statusBarItems = statusBarItems.filter({ $0 != item })
                NSStatusBar.system.removeStatusItem(item)
            }
        }
        
        for app in apps {
            if isShowingApp(bundleId: app.bundleIdentifier!) {
                continue
            }
            createNewMenuItem(app)
        }
    }
    
    func createNewMenuItem(_ app: NSRunningApplication) {
        let statusBar = NSStatusBar.system
        let statusBarItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        let statusBarItemIconBase = imageForBlackMenuBar(app.icon!)
        
        let view = NSImageView(frame: NSRect(
            x: (itemSlotWidth - iconSize) / 2,
            y: -(iconSize - menuBarHeight) / 2,
            width: iconSize, height: iconSize))
        
        view.image = statusBarItemIconBase
        view.wantsLayer = true
        if let existingSubview = statusBarItem.button?.subviews.first as? NSImageView {
            statusBarItem.button!.replaceSubview(existingSubview, with: view)
        } else {
            statusBarItem.button!.addSubview(view)
        }
        
        statusBarItem.button!.setAccessibilityLabel(app.bundleIdentifier)
        statusBarItem.button!.action = #selector(launchClicked)
        statusBarItem.button!.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusBarItem.button!.target = self
        
        statusBarItems.append(statusBarItem)
    }
    
    @objc func launchClicked(button: NSStatusBarButton) {
        let bundleId = button.accessibilityLabel()!
        let event = NSApp.currentEvent!
        
        if event.type == NSEvent.EventType.rightMouseUp {
            for app in self.runningApps {
                if app.bundleIdentifier! == bundleId {
                    app.terminate()
                    break
                }
            }
        } else {
            openApp(withBundleId: bundleId)
        }
    }
    
    @objc func terminateApp() {
        NSApplication.shared.terminate(self)
    }
    
    func openApp(withBundleId bundleId: String) {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["open", "-b", bundleId]
        task.launch()
        task.waitUntilExit()
    }
    
    func trackAppsBeingActivated() {
        NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { (notification) in
            
            self.updateMenuBar()
        }
    }
    
    func trackAppsBeingQuit() {
        NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { (notification) in
            
            self.updateMenuBar()
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        
    }
}

