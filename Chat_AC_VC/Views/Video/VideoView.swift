import Foundation
import SwiftUI
import WebRTC

import Foundation
import SwiftUI
import WebRTC
import Foundation
import SwiftUI
import WebRTC

struct VideoView: View {
    @StateObject var socketManager = AppSocketManager.shared
    @EnvironmentObject var roomId: RoomId
    
    // Grid layout: 2 columns
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            // 🌌 Background: Aapka "back1" image ya black color
         // Video clear dikhne ke liye thoda dark overlay
            
            VStack(spacing: 0) {
                // --- 🛰️ HEADER ---
                headerView
                
                // --- 📺 VIDEO GRID ---
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        // 1. Local Preview (Self)
                        VideoTileView(
                            track: WebRTCManager.shared.localVideoTrack,
                            name: "You (Host)",
                            isLocal: true
                        )
                        
                        // 2. Remote Participants
                        ForEach(socketManager.videoUsers.filter { $0.senderId != socketManager.currentSender?.senderId }, id: \.senderId) { user in
                            VideoTileView(
                                track: WebRTCManager.shared.remoteTracks[user.senderId],
                                name: user.name,
                                isLocal: false
                            )
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                // --- 🎮 CONTROL BAR ---
                controlBar
            }
        }
        .navigationBarHidden(true) // Full screen experience
        .onAppear {
            WebRTCManager.shared.setupLocalStream()
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Video Conference")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Room ID: \(roomId.roomID ?? "---")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            // Active status indicator
            Circle()
                .fill(socketManager.isVideoActive ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            Text(socketManager.isVideoActive ? "LIVE" : "OFFLINE")
                .font(.caption2.bold())
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.black.opacity(0.3))
    }
    
    private var controlBar: some View {
        VStack {
            if socketManager.currentSender?.isHost == true {
                // --- HOST CONTROLS ---
                if !socketManager.isVideoActive {
                    Button(action: { socketManager.joinVideo(roomId: roomId.roomID ?? "", asHost: true) }) {
                        Label("START MEETING", systemImage: "video.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                    .padding(.horizontal, 40)
                } else {
                    HStack(spacing: 30) {
                        controlButton(icon: "video.slash.fill", color: .gray) { /* Toggle Video */ }
                        controlButton(icon: "phone.down.fill", color: .red) {
                            socketManager.leaveCall(roomId: roomId.roomID ?? "")
                        }
                        controlButton(icon: "mic.slash.fill", color: .gray) { /* Toggle Mic */ }
                    }
                }
            } else {
                // --- PARTICIPANT CONTROLS ---
                if socketManager.isVideoActive {
                    if !socketManager.isInVideo {
                        Button(action: { socketManager.joinVideo(roomId: roomId.roomID ?? "", asHost: false) }) {
                            Label("JOIN MEETING", systemImage: "person.badge.plus.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                        }
                        .padding(.horizontal, 40)
                    } else {
                        controlButton(icon: "phone.down.fill", color: .red) {
                            socketManager.leaveCall(roomId: roomId.roomID ?? "")
                        }
                    }
                } else {
                    Text("Waiting for host to start...")
                        .foregroundColor(.white.opacity(0.7))
                        .italic()
                }
            }
        }
        .padding(.vertical, 25)
        .padding(.horizontal)
        .background(
            Color.black.opacity(0.8)
                .clipShape(RoundedCorner(radius: 30, corners: [.topLeft, .topRight]))
        )
    }
    
    func controlButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .padding()
                .background(color)
                .clipShape(Circle())
                .foregroundColor(.white)
        }
    }
}

// MARK: - Individual Video Tile
struct VideoTileView: View {
    var track: RTCVideoTrack?
    var name: String
    var isLocal: Bool
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let track = track {
                VideoRendererView(track: track)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .cornerRadius(15)
                VStack {
                    Image(systemName: "video.slash.fill")
                        .foregroundColor(.gray)
                    Text("Camera Off")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Text(name)
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .foregroundColor(.white)
                .cornerRadius(5)
                .padding(8)
        }
        .frame(height: 180)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(isLocal ? Color.blue.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 2)
        )
    }
}

// Helper for top rounded corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct VideoRendererView: UIViewRepresentable {
    var track: RTCVideoTrack?
    
    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView()
        view.videoContentMode = .scaleAspectFill
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        if let track = track {
            track.add(uiView)
        }
    }
    
    // Optional: Safayi ke liye
    static func dismantleUIView(_ uiView: RTCMTLVideoView, coordinator: ()) {
        // Track ko yahan se remove karne ka logic
    }
}
