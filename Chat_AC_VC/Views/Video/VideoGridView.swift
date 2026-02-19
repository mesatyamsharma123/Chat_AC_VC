import SwiftUI
import WebRTC

struct VideoGridView: View {
    @StateObject var webRTC = WebRTCManager.shared
    @StateObject var socketManager = AppSocketManager.shared
    @EnvironmentObject var roomId: RoomId
    @Environment(\.dismiss) var dismiss // View band karne ke liye
    
    // Grid setup: 2 columns (equally distributed)
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        ZStack {
            // Background color dark rakhte hain professional look ke liye
            Color(white: 0.1).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // --- 🏷️ HEADER ---
                HStack {
                    Text("LIVE CONFERENCE")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                    Spacer()
                    Text("ID: \(roomId.roomID ?? "---")")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding()
                .background(Color.black.opacity(0.5))

                // --- 📽️ VIDEO GRID ---
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        // 1. Local Video (Aapki apni video)
                        if let localTrack = webRTC.localVideoTrack {
                            VideoRendererView(track: localTrack)
                                .frame(height: 200)
                                .cornerRadius(12)
                                .overlay(Text("Me (Local)").padding(5).background(Color.black.opacity(0.5)).foregroundColor(.white), alignment: .bottom)
                        }
                        
                        // 2. Remote Videos (Baki sabki video)
                        // Hum remoteTracks dictionary se loop chalayenge
                        ForEach(webRTC.remoteTracks.keys.sorted(), id: \.self) { senderId in
                            if let track = webRTC.remoteTracks[senderId] {
                                VideoRendererView(track: track)
                                    .frame(height: 200)
                                    .cornerRadius(12)
                                    .overlay(
                                        Text(socketManager.videoUsers.first(where: { $0.senderId == senderId })?.name ?? "Remote")
                                            .padding(5)
                                            .background(Color.black.opacity(0.5))
                                            .foregroundColor(.white),
                                        alignment: .bottom
                                    )
                            }
                        }
                    }
                    .padding()
                }
                // --- 🎙️ CONTROLS ---
                HStack(spacing: 40) {
                    // Mute Button (Optional logic)
                    Button(action: {
                        // toggleAudio() logic yahan aa sakta hai
                    }) {
                        Image(systemName: "mic.fill")
                            .font(.title2)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                            .foregroundColor(.white)
                    }

                    // Hang Up Button
                    Button(action: {
                        print("🔴 Ending call...")
                        socketManager.leaveCall(roomId: roomId.roomID ?? "")
                        webRTC.closeAll()
                        dismiss() // View band karo
                    }) {
                        Image(systemName: "phone.down.fill")
                            .font(.title)
                            .padding(20)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    
                    // Camera Toggle Button (Optional)
                    Button(action: {
                        // toggleCamera() logic
                    }) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.title2)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 30)
                .padding(.top, 10)
            }
        }
        .navigationBarHidden(true)
    }
}
