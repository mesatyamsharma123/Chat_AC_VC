//
//  LoginView.swift
//  Chat_AC_VC
//
//  Created by Satyam Sharma Chingari on 22/02/26.
//

import SwiftUI
import SwiftUI

struct LoginView: View {
    // ✅ 1. Socket instance ko yahan access karo
    @StateObject var socket = VConnectSocket.shared
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var navigateToConnect = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Welcome to V-Chat").font(.largeTitle.bold())
                
                TextField("Name", text: $name).textFieldStyle(.roundedBorder)
                TextField("Email", text: $email).textFieldStyle(.roundedBorder)
                SecureField("Password", text: $password).textFieldStyle(.roundedBorder)
                
                Button("Continue") {
                    // ✅ 2. PeerModel banao
                    let myPeer = PeerModel(
                        name: name,
                        senderId: UUID().uuidString,
                        isHost: false,
                        roomId: "",
                        content: ""
                    )
                    
                    // ✅ 3. Socket mein current user set karo
                    socket.currentPeer = myPeer
                    
                    // ✅ 4. Navigation trigger karo
                    navigateToConnect = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty) // Name ke bina aage mat jaane do
            }
            .padding()
            .navigationDestination(isPresented: $navigateToConnect) {
                RoomSelectionView()
            }
        }
    }
}
import SwiftUI

struct RoomSelectionView: View {
    @StateObject var socket = VConnectSocket.shared
    @State private var roomIDInput: String = ""
    @State private var navigateToVideo = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("V-Connect Meeting")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            
            VStack(spacing: 20) {
                // --- CREATE ROOM SECTION ---
                VStack {
                    Text("Start a new meeting")
                        .font(.headline).foregroundColor(.gray)
                    
                    Button(action: {
                        let randomID = String(Int.random(in: 100...999))
                        socket.startRoom(id: randomID)
                        navigateToVideo = true
                    }) {
                        HStack {
                            Image(systemName: "video.fill")
                            Text("Create Room")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                
                Divider().background(Color.gray)
                
         
                VStack(spacing: 15) {
                    Text("Or join an existing one")
                        .font(.headline).foregroundColor(.gray)
                    
                    TextField("Enter Room ID (e.g. 123)", text: $roomIDInput)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                    
                    Button(action: {
                        if !roomIDInput.isEmpty {
                            socket.joinRoom(id: roomIDInput)
                            navigateToVideo = true
                        }
                    }) {
                        Text("Join Room")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(roomIDInput.isEmpty ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(roomIDInput.isEmpty)
                }
            }
            .padding(25)
            .background(Color.white.opacity(0.05))
            .cornerRadius(20)
            
            Spacer()
        }
        .padding()
        .background(Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea())
        .navigationDestination(isPresented: $navigateToVideo) {
            VideoGridScreen()
        }
    }
}
#Preview {
    LoginView()
}
