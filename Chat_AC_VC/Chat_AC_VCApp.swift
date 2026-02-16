//
//  Chat_AC_VCApp.swift
//  Chat_AC_VC
//
//  Created by Satyam Sharma Chingari on 14/02/26.
//

import SwiftUI
@main
struct Chat_AC_VCApp: App {
    @StateObject private var userStore = UserStore()
    @StateObject private var roomId = RoomId()
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            // ZStack ko hata kar Group use karein aur transition logic ko simplified rakhein
            Group {
                if appState.showSplash {
                    SplashScreen()
                } else {
                    // Screen switching logic
                    if appState.isLoggedIn {
                        NavigationStack {
                            ConnectPage()
                        }
                    } else {
                        NavigationStack {
                            Login()
                        }
                    }
                }
            }
            .environmentObject(appState)
            .environmentObject(roomId)
            .environmentObject(userStore)
        }
    }

}
