//
//  App.swift
//  Night-Core-Player
//
//  Created by RyuichiroMizutani on 2025/05/09.
//

import SwiftUI

@main
struct NightcorePlayerApp: App {
    init() {
        #if DEBUG
            #if targetEnvironment(simurlator)
            Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
            #endif
        #endif
    }
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
