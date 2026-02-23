import Foundation
import WebRTC
import Combine
import SocketIO
import AVFoundation
class VConnectRTC: NSObject, ObservableObject, RTCAudioSessionDelegate {
    static let shared = VConnectRTC()
    @Published var currentPeer: Sender?
    private var iceCandidateQueue: [String: [RTCIceCandidate]] = [:]    // WebRTC Objects
    private let factory: RTCPeerConnectionFactory
    var clients: [String: RTCPeerConnection] = [:]
    var videoCapturer: RTCCameraVideoCapturer? // ✅ Camera handle karne ke liye
    
    @Published var localVideoTrack: RTCVideoTrack?
    @Published var remoteTracks: [String: RTCVideoTrack] = [:]
    @Published var isMuted = false
    @Published var isVideoOff = false
    @Published var localAudioTrack: RTCAudioTrack?
    @Published var isSpeakerOn = true // Default speaker on rakhenge


    override init() {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        self.factory = RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
        super.init()
      
    }
   
    
    func handleRemoteOffer(sdp: String, from sId: String, completion: @escaping (RTCSessionDescription) -> Void) {
        print("📩 [SIGNALING] Received Offer from: \(sId)") // LOG
        let pc = createPeerConnection(for: sId)
        let remoteDescription = RTCSessionDescription(type: .offer, sdp: sdp)
        
        pc.setRemoteDescription(remoteDescription) { error in
            if let error = error { print("❌ Remote Offer SDP Error: \(error)"); return }
            
            let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
            pc.answer(for: constraints) { sdp, error in
                guard let sdp = sdp else {
                    print("❌ Failed to create Answer")
                    return
                }
                pc.setLocalDescription(sdp) { _ in
                    print("📤 [SIGNALING] Sending Answer to: \(sId)") // LOG
                    completion(sdp)
                }
            }
        }
    }
    func handleRemoteAnswer(sdp: String, from sId: String) {
        print("📩 [SIGNALING] Received Answer from: \(sId)")
        guard let pc = clients[sId] else { return }
        let remoteDescription = RTCSessionDescription(type: .answer, sdp: sdp)
        
        pc.setRemoteDescription(remoteDescription) { error in
            if let error = error {
                print("❌ Remote Answer Error: \(error)")
            } else {
                print("✅ [SUCCESS] Remote Description Set. Processing Queued ICE.")
                // ✅ Ab queued candidates ko add karo
                self.processQueuedCandidates(for: sId)
            }
        }
    }
    private func processQueuedCandidates(for sId: String) {
        guard let pc = clients[sId], let queue = iceCandidateQueue[sId] else { return }
        for candidate in queue {
            pc.add(candidate) { error in
                if let error = error { print("❌ Queued ICE Error: \(error)") }
            }
        }
        iceCandidateQueue[sId]?.removeAll()
    }
    
    func handleIceCandidate(dict: [String: Any], from sId: String) {
        guard let pc = clients[sId] else { return }
        
        let candidate = RTCIceCandidate(
            sdp: dict["candidate"] as? String ?? "", // ✅ Make sure key matches server ('candidate' not 'sdp')
            sdpMLineIndex: Int32(dict["sdpMLineIndex"] as? Int ?? 0),
            sdpMid: dict["sdpMid"] as? String
        )
        
        // Check karo ki Remote Description set hai ya nahi
        if pc.remoteDescription != nil {
            pc.add(candidate) { error in
                if let error = error { print("❌ ICE Error: \(error)") }
            }
        } else {
     
            print("📥 [ICE] Queuing candidate for \(sId)")
            if iceCandidateQueue[sId] == nil { iceCandidateQueue[sId] = [] }
            iceCandidateQueue[sId]?.append(candidate)
        }
    }
    
    func initiateInternalConnection(to peer: PeerModel) {
        print("🚀 [SIGNALING] Initiating Connection (Offer) to: \(peer.name) (\(peer.senderId))")
        let pc = createPeerConnection(for: peer.senderId)
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        pc.offer(for: constraints) { sdp, error in
            guard let sdp = sdp else {
                print("❌ Failed to create Offer")
                return
            }
            pc.setLocalDescription(sdp) { _ in
                print("📤 [SIGNALING] Sending Offer to: \(peer.senderId)") // LOG
                VConnectSocket.shared.socket.emit("sendOffer", [
                    "sdp": sdp.sdp,
                    "targetId": peer.senderId,
                    "senderId": VConnectSocket.shared.currentPeer?.senderId ?? ""
                ])
            }
        }
    }
    
  
    
    func prepareLocalMedia() {
        setupAudioSession()
        let videoSource = factory.videoSource()
  
        self.videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        
      
        guard let device = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == .front }),
              let format = RTCCameraVideoCapturer.supportedFormats(for: device).last,
              let fps = format.videoSupportedFrameRateRanges.first?.maxFrameRate else { return }
        
        videoCapturer?.startCapture(with: device, format: format, fps: Int(fps))
        
      
        localVideoTrack = factory.videoTrack(with: videoSource, trackId: "video0")
        
        let audioSource = factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
            localAudioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
            localAudioTrack?.isEnabled = true
            
            print("🎙️ Audio and 📸 Video tracks prepared")
    }
    
  
    
    private func createPeerConnection(for sId: String) -> RTCPeerConnection {
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        
        guard let pc = factory.peerConnection(with: config, constraints: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil), delegate: self) else {
            fatalError("❌ Connection failed")
        }
        
        
        if let localTrack = localVideoTrack {
            pc.add(localTrack, streamIds: ["stream0"])
        }
        
        if let audioTrack = localAudioTrack {
            pc.add(audioTrack, streamIds: ["stream0"])
        }
        

        let initOptions = RTCRtpTransceiverInit()
        initOptions.direction = .sendRecv
        pc.addTransceiver(of: .video, init: initOptions)
        pc.addTransceiver(of: .audio, init: initOptions)
        
        clients[sId] = pc
        return pc
    }
    private func setupAudioSession() {
        let session = RTCAudioSession.sharedInstance()
        // WebRTC ko batane ke liye ki hum handle kar rahe hain
        session.add(self)
        
        session.lockForConfiguration()
        do {
            try session.setCategory(AVAudioSession.Category.playAndRecord.rawValue,
                                   with: [.defaultToSpeaker, .allowBluetooth])
            try session.setMode(AVAudioSession.Mode.videoChat.rawValue)
            try session.setActive(true)
            
            // Manual override
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
            print("✅ Speaker forced via AVAudioSession")
        } catch {
            print("❌ Audio Error: \(error)")
        }
        session.unlockForConfiguration()
    }
    
    func toggleSpeaker() {
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        do {
            isSpeakerOn.toggle()
            if isSpeakerOn {
                try session.overrideOutputAudioPort(.speaker)
            } else {
                try session.overrideOutputAudioPort(.none) // Earpiece par chala jayega
            }
            print(isSpeakerOn ? "🔊 Speaker On" : "👂 Earpiece On")
        } catch {
            print("❌ Error toggling speaker: \(error)")
        }
        session.unlockForConfiguration()
    }
    func toggleMute(completion: @escaping (Bool) -> Void) {
        isMuted.toggle()
        
        // WebRTC track ko enable/disable karna
        localAudioTrack?.isEnabled = !isMuted
        
        print(isMuted ? "🔇 Mic Muted" : "🎙️ Mic Unmuted")
        
        // UI ya Socket ko batane ke liye completion callback
        completion(isMuted)
    }
    // VConnectRTC.swift ke andar
    func closeAllConnections() {
        // Mic aur Video tracks band karein
        localAudioTrack?.isEnabled = false
        localVideoTrack?.isEnabled = false
        
        // Camera capture bhi stop karein
        videoCapturer?.stopCapture()
        
        // Saari peer connections close karein
        for (_, connection) in clients {
            connection.close() // ✅ Correct: connection khud peerConnection hai
        }
        
        // Cleanup dictionaries
        clients.removeAll()
        remoteTracks.removeAll()
        iceCandidateQueue.removeAll()
        
        print("🧹 All WebRTC connections cleaned up")
    }
    
    
}

extension VConnectRTC: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {

    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        
    }
    
    
    // Jab remote stream se naya track (video) aaye
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("✅ WebRTC: Remote stream added from a peer")
        if let videoTrack = stream.videoTracks.first {
            if let sId = clients.first(where: { $0.value == peerConnection })?.key {
                DispatchQueue.main.async {
                    // Dictionary update hone par SwiftUI View refresh hoga
                    self.remoteTracks[sId] = videoTrack
                    print("✅ Track assigned to sId: \(sId)")
                }
            }
        }
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd receiver: RTCRtpReceiver, streams: [RTCMediaStream]) {
            print("✅ WebRTC: Receiver added for a track")
            
            // Check karo ki track video hai ya nahi
            if let videoTrack = receiver.track as? RTCVideoTrack {
                // Peer ID dhoondo dictionary se
                if let sId = clients.first(where: { $0.value == peerConnection })?.key {
                    DispatchQueue.main.async {
                        self.remoteTracks[sId] = videoTrack
                        print("✅ Remote Video Track Assigned to sId: \(sId)")
                    }
                }
            }
        }
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        if let sId = clients.first(where: { $0.value == peerConnection })?.key {
            print("❄️ [ICE] Candidate Generated for: \(sId)") // LOG
            let dict: [String: Any] = [
                "candidate": candidate.sdp,
                "sdpMLineIndex": candidate.sdpMLineIndex,
                "sdpMid": candidate.sdpMid ?? ""
            ]
            VConnectSocket.shared.socket.emit("sendIceCandidate", [
                "candidate": dict,
                "targetId": sId,
                "senderId": VConnectSocket.shared.currentPeer?.senderId ?? ""
            ])
        }
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("🌐 [NETWORK] ICE Connection State Changed: \(newState.rawValue)")
        
        if newState == .connected || newState == .completed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.forceSpeaker()
            }
        }
    }

    private func forceSpeaker() {
        do {
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
            print("📢 Forced Speaker after connection established")
        } catch {
            print("❌ Failed to force speaker: \(error)")
        }
    }
   
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
 
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
  
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
