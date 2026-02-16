//
//  AppState.swift
//  Chat_AC_VC
//
//  Created by Satyam Sharma Chingari on 14/02/26.
//

import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
        @Published var showSplash: Bool = true
}
