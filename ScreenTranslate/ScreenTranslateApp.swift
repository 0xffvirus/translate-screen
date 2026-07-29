//
//  ScreenTranslateApp.swift
//  ScreenTranslate
//
//  Created by Bahaa on 15/02/1448 AH.
//

import SwiftUI

@main
struct ScreenTranslateApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var history: HistoryStore
    @StateObject private var appState: AppState

    init() {
        let settings = AppSettings()
        let history = HistoryStore()
        _settings = StateObject(wrappedValue: settings)
        _history = StateObject(wrappedValue: history)
        _appState = StateObject(wrappedValue: AppState(settings: settings, history: history))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(history)
                .environmentObject(appState)
        }
    }
}
