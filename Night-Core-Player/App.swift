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
        Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
        #endif
    }
    var body: some Scene {
        WindowGroup {
            MusicPlayerView()
        }
    }
}
