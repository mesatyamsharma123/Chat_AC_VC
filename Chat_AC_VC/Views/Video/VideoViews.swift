import SwiftUI
import SocketIO
import AVFoundation
import SwiftUI
import SocketIO
import AVFoundation

struct VideoViews: View {
    
    @ObservedObject var socketManager = AppSocketManager.shared
    @ObservedObject var webRTC = WebRTCManager.shared
    
    @EnvironmentObject var roomId: RoomId
    @EnvironmentObject var senders: Senders
    
    var body: some View {
        ZStack {
            Image("back1")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                
                VStack(spacing: 15) {
                    
                    Image(systemName: "video.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(socketManager.isVideoActive ? .green : .purple)
                        .shadow(radius: 10)
                    
                    Text("Video Conference")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(socketManager.isVideoActive ?
                         "Room is Active! Join Now." :
                         "Waiting for Host to start...")
                        .font(.headline)
                        .foregroundColor(socketManager.isVideoActive ?
                                         .green :
                                         .white.opacity(0.7))
                }
                .padding(.top, 50)

                Spacer()

                if senders.senders?.isHost == true {
                    
                    Button {
                        socketManager.startVideoCall(
                            roomId: roomId.roomID ?? ""
                        )
                    } label: {
                        Label("START MEETING", systemImage: "video.fill")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    
                } else {
                    
                    Button {
                        socketManager.joinVideoCall(
                            roomId: roomId.roomID ?? ""
                        )
                    } label: {
                        Label("JOIN MEETING",
                              systemImage: "person.badge.plus.fill")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(socketManager.isVideoActive ?
                                        Color.purple :
                                        Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    .disabled(!socketManager.isVideoActive)
                    
                    if !socketManager.isVideoActive {
                        ProgressView()
                            .tint(.white)
                            .padding(.top, 5)
                    }
                }
            }
            .padding(40)
        }
        .onAppear {
            
            webRTC.checkPermissions()
            
            if let me = senders.senders {
                socketManager.currentSender = me
                
                socketManager.socket.emit("join", [
                    "roomId": me.roomId,
                    "senderId": me.senderId,
                    "name": me.name
                ])
            }
        }
        .fullScreenCover(isPresented: $socketManager.isInVideo) {
            VideoGridView()
                .environmentObject(senders)
                .environmentObject(roomId)
        }
    }
}
