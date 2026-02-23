import Foundation
import WebRTC
import Combine

protocol WebRTCClientDelegate: AnyObject {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate)
    func webRTCClient(_ client: WebRTCClient, didReceiveRemoteVideoTrack track: RTCVideoTrack, forUser userId: String)
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState)
}

class WebRTCClient: NSObject {
    
    weak var delegate: WebRTCClientDelegate?
    private let factory: RTCPeerConnectionFactory
    var peerConnection: RTCPeerConnection!
    let targetUser: Sender
    
    init(targetUser: Sender, factory: RTCPeerConnectionFactory) {
        self.targetUser = targetUser
        self.factory = factory
        super.init()
        setup()
    }
    
    private func setup() {
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        config.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        ]
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil,
                                              optionalConstraints: nil)
        
        peerConnection = factory.peerConnection(with: config,
                                                constraints: constraints,
                                                delegate: self)
    }
    
    func addLocalTrack(_ track: RTCMediaStreamTrack) {
        let mediaType: RTCRtpMediaType = (track.kind == "video") ? .video : .audio
        
        // 1. Check karein kya is media type ka transceiver pehle se hai?
        if let transceiver = peerConnection.transceivers.first(where: { $0.mediaType == mediaType }) {
            
            // Agar transceiver hai, toh bas track attach karo aur direction set karo
            transceiver.sender.track = track
            
            // Direction ko 'sendRecv' set karna zaroori hai taaki dono side video/audio chale
            if transceiver.direction != .sendRecv {
                transceiver.setDirection(.sendRecv, error: nil)
            }
            print("✅ Attached \(track.kind) track to existing transceiver")
            
        } else {
            // 2. Agar nahi hai (pehle offer/answer exchange nahi hua), toh naya add karein
            let initOptions = RTCRtpTransceiverInit()
            initOptions.direction = .sendRecv
            
            // addTransceiver naya track aur connection create karta hai
            peerConnection.addTransceiver(with: track, init: initOptions)
            print("🚀 Created new transceiver for \(track.kind) track")
        }
    }
    func makeOffer(completion: @escaping (RTCSessionDescription) -> Void) {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
                kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
            ],
            optionalConstraints: nil)
        
        peerConnection.offer(for: constraints) { sdp, _ in
            guard let sdp = sdp else { return }
            self.peerConnection.setLocalDescription(sdp) { _ in
                completion(sdp)
            }
        }
    }
    
    func makeAnswer(completion: @escaping (RTCSessionDescription) -> Void) {
        let constraints = RTCMediaConstraints(mandatoryConstraints: [
            kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
            kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
        ], optionalConstraints: nil)
        
        peerConnection.answer(for: constraints) { [weak self] sdp, error in
            guard let sdp = sdp else { return }
            self?.peerConnection.setLocalDescription(sdp) { error in
                completion(sdp)
            }
        }
    }
    
    func setRemote(sdp: String, type: RTCSdpType, completion: @escaping (Error?) -> Void) {
        let desc = RTCSessionDescription(type: type, sdp: sdp)
        peerConnection.setRemoteDescription(desc) { error in
            completion(error)
        }
    }
    
    func addIceCandidate(dict: [String: Any]) {
        guard let sdp = dict["candidate"] as? String,
              let sdpMid = dict["sdpMid"] as? String,
              let index = dict["sdpMLineIndex"] as? Int32 else { return }
        
        let candidate = RTCIceCandidate(sdp: sdp,
                                        sdpMLineIndex: index,
                                        sdpMid: sdpMid)
        peerConnection.add(candidate)
    }
    
    func disconnect() {
        peerConnection.close()
    }
}

extension WebRTCClient: RTCPeerConnectionDelegate {
    
    func peerConnection(_ pc: RTCPeerConnection,
                        didGenerate candidate: RTCIceCandidate) {
        delegate?.webRTCClient(self,
                               didDiscoverLocalCandidate: candidate)
    }
    
 
    // WebRTCClient.swift mein is delegate function ko check karein
    func peerConnection(_ pc: RTCPeerConnection, didAdd receiver: RTCRtpReceiver, streams: [RTCMediaStream]) {
        if let track = receiver.track as? RTCVideoTrack {
            print("📽️ [UI] Got remote video track for user: \(self.targetUser.senderId)")
            
            DispatchQueue.main.async {
                // Yeh line sabse zaroori hai refresh ke liye
                WebRTCManager.shared.remoteTracks[self.targetUser.senderId] = track
                WebRTCManager.shared.objectWillChange.send() // SwiftUI ko dhakka maro refresh ke liye
            }
        }
    }
    
    func peerConnection(_ pc: RTCPeerConnection,
                        didChange state: RTCIceConnectionState) {
        delegate?.webRTCClient(self,
                               didChangeConnectionState: state)
    }
    
    func peerConnection(_ pc: RTCPeerConnection,
                        didChange state: RTCSignalingState) {}
    func peerConnection(_ pc: RTCPeerConnection,
                        didAdd stream: RTCMediaStream) {}
    func peerConnection(_ pc: RTCPeerConnection,
                        didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ pc: RTCPeerConnection) {}
    func peerConnection(_ pc: RTCPeerConnection,
                        didChange state: RTCIceGatheringState) {}
    func peerConnection(_ pc: RTCPeerConnection,
                        didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ pc: RTCPeerConnection,
                        didOpen dataChannel: RTCDataChannel) {}
}
