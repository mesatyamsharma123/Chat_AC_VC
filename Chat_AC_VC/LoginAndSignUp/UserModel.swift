//
//  UserModel.swift
//  Chat_AC_VC
//
//  Created by Satyam Sharma Chingari on 14/02/26.
//

import Foundation

struct UserModel : Codable, Identifiable {
    var id:UUID = UUID()
    let name:String
    let email:String
    let password:String

}
struct Sender: Codable, Identifiable {
    var id: UUID = UUID()
    let name: String
    let senderId: String
    var content: String
    let isHost: Bool
    let roomId: String
    
    // 1. Dictionary Initializer (Socket data ke liye)
    init(dict: [String: Any]) {
        self.name = dict["name"] as? String ?? "Unknown"
        self.senderId = dict["senderId"] as? String ?? ""
        self.content = dict["content"] as? String ?? ""
        self.isHost = dict["isHost"] as? Bool ?? false
        self.roomId = dict["roomId"] as? String ?? ""
    }
    
    // 2. Memberwise Initializer (Manual creation aur parseSenderData ke liye)
    init(name: String, senderId: String, content: String, isHost: Bool, roomId: String) {
        self.name = name
        self.senderId = senderId
        self.content = content
        self.isHost = isHost
        self.roomId = roomId
    }
}
