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
                // 1. Aapki apni video (Local)
                VideoCard(
                    track: WebRTCManager.shared.localVideoTrack,
                    name: "You (Host)"
                )
                
                // 2. Dusre logon ki video (Remote)
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
