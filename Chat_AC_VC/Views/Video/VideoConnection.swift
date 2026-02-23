import SwiftUI

struct VideoConnection: View {
    @StateObject var socketManager = AppSocketManager.shared
    @EnvironmentObject var senders: Senders
    
    let columns = [
        GridItem(.fixed(150), spacing: 15),
        GridItem(.fixed(150), spacing: 15)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
            
                VideoCard(
                    track: WebRTCManager.shared.localVideoTrack,
                    name: "You (Host)"
                )
                
             
                ForEach(socketManager.videoUsers.filter { $0.senderId != senders.senders?.senderId }, id: \.senderId) { user in
                    VideoCard(
                        track: WebRTCManager.shared.remoteTracks[user.senderId],
                        name: user.name
                    )
                }
            }
            .padding()
        }
    }
}
