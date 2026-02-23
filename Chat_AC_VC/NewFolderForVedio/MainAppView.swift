//
//  MainAppView.swift
//  Chat_AC_VC
//
//  Created by Satyam Sharma Chingari on 22/02/26.
//

import Foundation
import SwiftUI
struct MainAppView: View {
    @StateObject var socket = VConnectSocket.shared
    @StateObject var rtc = VConnectRTC.shared
    @State private var name = ""
    @State private var roomInput = ""
    @State private var isProfileSet = false
    
    var body: some View {
        NavigationStack {
            if !isProfileSet {
                VStack(spacing: 20) {
                    Text("V-Connect").font(.system(size: 40, weight: .black))
                    TextField("Enter Your Name", text: $name)
                        .textFieldStyle(.roundedBorder).padding()
                    Button("Get Started") {
                        socket.currentPeer = PeerModel(name: name, senderId: UUID().uuidString, isHost: false, roomId: "", content: "")
                        isProfileSet = true
                    }.buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 30) {
                    HStack {
                        Circle().fill(socket.isConnected ? .green : .red).frame(width: 10, height: 10)
                        Text(socket.isConnected ? "Server Online" : "Connecting...")
                    }
                    
                    Button("CREATE NEW ROOM") {
                        socket.startRoom(id: String(Int.random(in: 1000...9999)))
                    }.font(.headline).frame(maxWidth: .infinity).padding().background(.blue).foregroundColor(.white).cornerRadius(15)
                    
                    Text("OR").foregroundColor(.gray)
                    
                    TextField("Enter Room ID", text: $roomInput).textFieldStyle(.roundedBorder)
                    Button("JOIN ROOM") {
                        socket.joinRoom(id: roomInput)
                        print("sdasdadawdwadwadaw : \(roomInput)")
                    }.disabled(roomInput.isEmpty)
                }
                .padding()
                .fullScreenCover(isPresented: $socket.isInVideo) {
                    VideoGridScreen()
                }
            }
        }
    }
}
