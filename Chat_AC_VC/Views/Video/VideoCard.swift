import Foundation
import SwiftUI
import WebRTC

struct VideoCard: View {
    var track: RTCVideoTrack?
    var name: String
    
    var body: some View {
        VStack {
            ZStack(alignment: .bottomLeading) {
                if let track = track {
                    // Actual Camera View
                    RTCVideoView(track: track)
                        .frame(width: 150, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                } else {
                    
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 150, height: 180)
                    
                    Image(systemName: "video.slash.fill")
                        .foregroundColor(.purple)
                        .offset(x: 65, y: -80) // Center mein icon
                }
                
                // Name Tag
                Text(name)
                    .font(.caption.bold())
                    .padding(5)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(5)
                    .padding(8)
            }
        }
    }
}
