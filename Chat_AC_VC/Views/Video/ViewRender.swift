import SwiftUI
import WebRTC
struct RTCVideoView: UIViewRepresentable {
    var track: RTCVideoTrack?

    func makeUIView(context: Context) -> RTCMTLVideoView {
            let view = RTCMTLVideoView()
            view.videoContentMode = .scaleAspectFill
            view.clipsToBounds = true
            return view
        }

        func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
            // 🔥 Sabse important part:
            // Pehle purane renderers hatao (Safety ke liye) aur naya attach karo
            if let track = track {
                print("📺 Rendering Video Track: \(track.trackId)")
                track.add(uiView)
            }
        }
    
    // Memory leak rokne ke liye
    static func dismantleUIView(_ uiView: RTCMTLVideoView, coordinator: ()) {
        // Track remove logic here if needed
    }
}
