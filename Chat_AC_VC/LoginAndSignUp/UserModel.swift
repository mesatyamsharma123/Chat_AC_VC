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

struct  Sender: Codable ,Identifiable{
    var id:UUID = UUID()
    let name:String
    let senderId:String
    var content:String
    let isHost:Bool
    let roomId:String
    
}
