//
//  UserStore.swift
//  Chat_AC_VC
//
//  Created by Satyam Sharma Chingari on 14/02/26.
//

import Foundation
import Combine
class UserStore : ObservableObject {
    @Published var users: UserModel? = nil
}
