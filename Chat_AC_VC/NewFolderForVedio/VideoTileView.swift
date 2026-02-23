import Foundation
import SwiftUI
import WebRTC

struct VideoGridScreen: View {
    @StateObject var socket = VConnectSocket.shared
    @StateObject var rtc = VConnectRTC.shared
    @Environment(\.dismiss) var dismiss
    
    let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            VStack {

                HStack {
                    VStack(alignment: .leading) {
                        Text("Room ID: \(socket.currentPeer?.roomId ?? "N/A")")
                            .font(.caption).bold().foregroundColor(.gray)
                        Text("Live Meeting").font(.title2.bold()).foregroundColor(.white)
                    }
                    Spacer()
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text("\(socket.activePeers.count)")
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial).cornerRadius(20).foregroundColor(.white)
                }
                .padding()

           
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 15) {
                  
                        VideoTileViews(
                            track: rtc.localVideoTrack,
                            name: "Me (You)",
                            isMuted: rtc.isMuted,
                            isVideoOff: rtc.isVideoOff,
                            isLocal: true
                        )

              
                        ForEach(socket.activePeers.filter { $0.senderId != socket.currentPeer?.senderId }, id: \.senderId) { peer in
                            VideoTileViews(
                                track: rtc.remoteTracks[peer.senderId],
                                name: peer.name,
                                isMuted: peer.isMuted,
                                isVideoOff: peer.isVideoOff,
                                isLocal: false
                            )
                        }             }
                    .padding(.horizontal)
                }

                Spacer()

                
                HStack(spacing: 25) {
                    
                    ControlButton(
                            icon: rtc.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill",
                            color: rtc.isSpeakerOn ? .blue.opacity(0.6) : .white.opacity(0.2)
                        ) {
                            rtc.toggleSpeaker()
                        }
                    
                    
                    ControlButton(icon: rtc.isMuted ? "mic.slash.fill" : "mic.fill",
                                   color: rtc.isMuted ? .red : .white.opacity(0.2)) {
                        
                        rtc.toggleMute { muted in
                        
                            socket.updateMuteStatus(isMuted: muted)
                        }
                    }

                    Button(action: {
                      
                        socket.endCall()
                        dismiss()
                    }) {
                        Image(systemName: "phone.down.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 70, height: 70)
                            .background(Color.red)
                            .clipShape(Circle())
                    }

                    ControlButton(icon: rtc.isVideoOff ? "video.slash.fill" : "video.fill",
                                   color: rtc.isVideoOff ? .red : .white.opacity(0.2)) {
                        
                        rtc.isVideoOff.toggle()
                        rtc.localVideoTrack?.isEnabled = !rtc.isVideoOff // WebRTC track stop/start
                        socket.updateVideoStatus(isVideoOff: rtc.isVideoOff) // Server ko notify karein
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .alert("Meeting Ended", isPresented: $socket.showMeetingEndedAlert) {
            Button("OK", role: .cancel) {
             
                socket.cleanupCall()
                dismiss()
            }
        } message: {
            Text("The host has ended the meeting for everyone.")
        }
    }
}


struct VideoTileViews: View {
    var track: RTCVideoTrack?
    var name: String
    var isMuted: Bool
    var isVideoOff: Bool
    var isLocal: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let track = track, !isVideoOff {
                RTCPeerVideoView(track: track)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .scaleEffect(x: isLocal ? -1 : 1, y: 1)
            } else {
                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        VStack {
                                            Image(systemName: "video.slash.fill")
                                                .font(.system(size: 40))
                                            Text("Camera Off").font(.caption)
                                        }.foregroundColor(.white.opacity(0.6))
                                    )
            }

            HStack {
                Text(name).font(.system(size: 12, weight: .medium))
                if isMuted {
                    Image(systemName: "mic.slash.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .padding(8)
            .background(.ultraThinMaterial).cornerRadius(10).foregroundColor(.white)
            .padding(10)
        }
        .frame(height: 200)
    }
}

struct ControlButton: View {
    var icon: String
    var color: Color
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 55, height: 55)
                .background(color)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}

struct RTCPeerVideoView: UIViewRepresentable {
    let track: RTCVideoTrack?
    func makeUIView(context: Context) -> RTCEAGLVideoView {
        let videoView = RTCEAGLVideoView(frame: .zero)
        videoView.contentMode = .scaleAspectFill
        videoView.clipsToBounds = true
        return videoView
    }
    func updateUIView(_ uiView: RTCEAGLVideoView, context: Context) {
        if let track = track {
            track.add(uiView)
        }
    }
}
