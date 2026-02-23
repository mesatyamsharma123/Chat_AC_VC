//
//  PeerModel.swift
//  Chat_AC_VC
//
//  Created by Satyam Sharma Chingari on 22/02/26.
//

import Foundation
import Foundation

struct PeerModel: Identifiable, Codable, Equatable {
    var id: String { senderId }
    let name: String
    let senderId: String
    var isHost: Bool
    var roomId: String
    var content : String
    var isMuted: Bool = false
    var isVideoOff: Bool = false
    
    
    static func == (lhs: PeerModel, rhs: PeerModel) -> Bool {
        return lhs.senderId == rhs.senderId
    }
}
