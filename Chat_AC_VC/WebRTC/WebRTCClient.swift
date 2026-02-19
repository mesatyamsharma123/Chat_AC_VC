//import Foundation
//import WebRTC
//import Combine
//
//protocol WebRTCClientDelegate: AnyObject {
//    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate)
//    func webRTCClient(_ client: WebRTCClient, didReceiveRemoteVideoTrack track: RTCVideoTrack)
//    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState)
//}
//
//class WebRTCClient: NSObject {
//    weak var delegate: WebRTCClientDelegate?
//    private let factory: RTCPeerConnectionFactory
//    var peerConnection: RTCPeerConnection!
//    let targetUser: Sender
//
//    init(targetUser: Sender, factory: RTCPeerConnectionFactory) {
//        self.targetUser = targetUser
//        self.factory = factory
//        super.init()
//        setupPeerConnection()
//    }
//
//    private func setupPeerConnection() {
//        let config = RTCConfiguration()
//        config.iceServers = [
//            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
//            RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"])
//        ]
//        config.sdpSemantics = .unifiedPlan
//        config.continualGatheringPolicy = .gatherContinually
//        
//        // Connectivity settings
//        config.tcpCandidatePolicy = .enabled
//        config.bundlePolicy = .maxBundle
//        config.rtcpMuxPolicy = .require
//        
//        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
//        
//        guard let pc = factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
//            fatalError("❌ Could not create PeerConnection")
//        }
//        self.peerConnection = pc
//    }
//
//    // MARK: - 🎙️ TRACK MANAGEMENT
//    func addLocalTrack(_ track: RTCMediaStreamTrack) {
//        let streamId = "stream0"
//        let mediaType: RTCRtpMediaType = (track.kind == "video") ? .video : .audio
//        
//        // Check karein ki kya pehle se transceiver hai
//        if let transceiver = peerConnection.transceivers.first(where: { $0.mediaType == mediaType }) {
//            transceiver.sender.track = track
//            transceiver.setDirection(.sendRecv, error: nil)
//            print("✅ Transceiver direction set to sendRecv for \(track.kind)")
//        } else {
//            // Naya transceiver banayein with sendRecv direction
//            let initOptions = RTCRtpTransceiverInit()
//            initOptions.direction = .sendRecv
//            initOptions.streamIds = [streamId]
//            peerConnection.addTransceiver(with: track, init: initOptions)
//            print("✅ New transceiver added for \(track.kind)")
//        }
//    }    // MARK: - 📑 SDP NEGOTIATION
//    // WebRTCClient.swift ke andar in dono functions ko update karein
//
//    func makeOffer(completion: @escaping (RTCSessionDescription) -> Void) {
//        // 1. Mandatory constraints ko true rakhein taaki video exchange ho sake
//        let constraints = RTCMediaConstraints(mandatoryConstraints: [
//            kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
//            kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
//        ], optionalConstraints: nil)
//        
//        peerConnection.offer(for: constraints) { [weak self] sdp, error in
//            guard let sdp = sdp else {
//                print("❌ Offer Creation Error: \(error?.localizedDescription ?? "")")
//                return
//            }
//            self?.peerConnection.setLocalDescription(sdp) { error in
//                if let error = error { print("❌ SetLocalDescription Error: \(error)"); return }
//                completion(sdp)
//            }
//        }
//    }
//
//    func makeAnswer(completion: @escaping (RTCSessionDescription) -> Void) {
//        let constraints = RTCMediaConstraints(mandatoryConstraints: [
//            kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
//            kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
//        ], optionalConstraints: nil)
//        
//        peerConnection.answer(for: constraints) { [weak self] sdp, error in
//            guard let sdp = sdp else {
//                print("❌ Answer Creation Error: \(error?.localizedDescription ?? "")")
//                return
//            }
//            self?.peerConnection.setLocalDescription(sdp) { error in
//                if let error = error { print("❌ SetLocalDescription Error: \(error)"); return }
//                completion(sdp)
//            }
//        }
//    }
//
//    func setRemote(sdp: String, type: RTCSdpType) {
//        let sessionDesc = RTCSessionDescription(type: type, sdp: sdp)
//        peerConnection.setRemoteDescription(sessionDesc) { error in
//            if let error = error {
//                print("❌ SetRemoteDescription Error: \(error.localizedDescription)")
//            }
//        }
//    }
//
//    func addIceCandidate(dict: [String: Any]) {
//        guard let sdp = dict["candidate"] as? String,
//              let sdpMid = dict["sdpMid"] as? String,
//              let sdpMLineIndex = dict["sdpMLineIndex"] as? Int32 else { return }
//        
//        let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
//        peerConnection.add(candidate)
//    }
//
//    func disconnect() {
//        peerConnection.close()
//        print("🔌 Disconnected from \(targetUser.name)")
//    }
//}
//
//// MARK: - 🔌 DELEGATE METHODS
//extension WebRTCClient: RTCPeerConnectionDelegate {
//    
//    func peerConnection(_ pc: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
//        delegate?.webRTCClient(self, didDiscoverLocalCandidate: candidate)
//    }
//    
//    // Unified Plan - Receiver method is the most reliable
//    func peerConnection(_ pc: RTCPeerConnection, didAdd receiver: RTCRtpReceiver, streams: [RTCMediaStream]) {
//        // Jab remote video track milta hai
//        if let track = receiver.track as? RTCVideoTrack {
//            print("📽️ Received Remote Video Track for \(targetUser.name)")
//            DispatchQueue.main.async {
//                self.delegate?.webRTCClient(self, didReceiveRemoteVideoTrack: track)
//            }
//        }
//    }
//
//    func peerConnection(_ pc: RTCPeerConnection, didChange state: RTCIceConnectionState) {
//        print("⚡ Connection State with \(targetUser.name): \(state.rawValue)")
//        DispatchQueue.main.async {
//            self.delegate?.webRTCClient(self, didChangeConnectionState: state)
//        }
//    }
//    
//    // Required Protocols
//    func peerConnection(_ pc: RTCPeerConnection, didChange state: RTCSignalingState) {}
//    func peerConnection(_ pc: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
//    func peerConnection(_ pc: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
//    func peerConnectionShouldNegotiate(_ pc: RTCPeerConnection) {}
//    func peerConnection(_ pc: RTCPeerConnection, didChange state: RTCIceGatheringState) {}
//    func peerConnection(_ pc: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
//    func peerConnection(_ pc: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
//}
import Foundation
import WebRTC

protocol WebRTCClientDelegate: AnyObject {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate)
    func webRTCClient(_ client: WebRTCClient, didReceiveRemoteVideoTrack track: RTCVideoTrack)
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
        
        // Check agar pehle se transceiver hai
        if let transceiver = peerConnection.transceivers.first(where: { $0.mediaType == mediaType }) {
            transceiver.sender.track = track
            transceiver.setDirection(.sendRecv, error: nil)
        } else {
            let initOptions = RTCRtpTransceiverInit()
            initOptions.direction = .sendRecv // Dono taraf data flow allow karein
            peerConnection.addTransceiver(with: track, init: initOptions)
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
        // Ye constraints batati hain ki humein remote video/audio chahiye
        let constraints = RTCMediaConstraints(mandatoryConstraints: [
            kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
            kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
        ], optionalConstraints: nil)
        
        peerConnection.answer(for: constraints) { [weak self] sdp, error in
            guard let sdp = sdp else {
                print("❌ Answer Error: \(error?.localizedDescription ?? "")")
                return
            }
            self?.peerConnection.setLocalDescription(sdp) { error in
                if let error = error { print("❌ SetLocalDescription Error: \(error)"); return }
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
    
    func peerConnection(_ pc: RTCPeerConnection,
                        didAdd receiver: RTCRtpReceiver,
                        streams: [RTCMediaStream]) {
        if let track = receiver.track as? RTCVideoTrack {
            delegate?.webRTCClient(self,
                                   didReceiveRemoteVideoTrack: track)
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
