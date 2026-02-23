//import Foundation
//import WebRTC
//import Combine
//import AVFoundation
//
//
//
//class WebRTCManager: NSObject, ObservableObject {
//    static let shared = WebRTCManager()
//    
//    private var pendingIceCandidates: [String: [RTCIceCandidate]] = [:]
//    @Published var peerConnections: [String: WebRTCClient] = [:] // Key: senderId
//    @Published var remoteVideoTracks: [String: RTCVideoTrack] = [:]
//
//    private let factory: RTCPeerConnectionFactory = {
//        RTCInitializeSSL()
//        let videoEncoder = RTCDefaultVideoEncoderFactory()
//        let videoDecoder = RTCDefaultVideoDecoderFactory()
//        return RTCPeerConnectionFactory(encoderFactory: videoEncoder, decoderFactory: videoDecoder)
//    }()
//    
//    @Published var clients: [String: WebRTCClient] = [:]
//    @Published var remoteTracks: [String: RTCVideoTrack] = [:]
//    
//    @Published var localAudioTrack: RTCAudioTrack?
//    @Published var localVideoTrack: RTCVideoTrack?
//    private var capturer: RTCCameraVideoCapturer?
//    
//    private override init() {
//        super.init()
//        setupLocalTracks()
//        configureAudioSession()
//    }
//    
//
//    
//    func setupLocalTracks() {
//        // Audio Track setup
//        let audioSource = factory.audioSource(with: nil)
//        self.localAudioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
//        
//        // Video Track setup
//        let videoSource = factory.videoSource()
//        self.capturer = RTCCameraVideoCapturer(delegate: videoSource)
//        self.localVideoTrack = factory.videoTrack(with: videoSource, trackId: "video0")
//    }
//    
//    func setupLocalStream() {
//  
//        configureAudioSession()
//        startLocalCapture()
//    }
//    
//    func startLocalCapture() {
//        guard let device = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == .front }) else { return }
//        
//        // Find best format
//        let formats = RTCCameraVideoCapturer.supportedFormats(for: device)
//
//        let targetWidth = 640
//        let targetHeight = 480
//        
//        var selectedFormat: AVCaptureDevice.Format? = nil
//        var currentDiff = Int.max
//        
//        for format in formats {
//            let dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
//            let diff = abs(Int(dimension.width) - targetWidth) + abs(Int(dimension.height) - targetHeight)
//            if diff < currentDiff {
//                selectedFormat = format
//                currentDiff = diff
//            }
//        }
//        
//        if let format = selectedFormat {
//            let fps = 30
//            print(" Starting Camera: \(CMVideoFormatDescriptionGetDimensions(format.formatDescription)) at \(fps)fps")
//            self.capturer?.startCapture(with: device, format: format, fps: fps)
//        } else {
//            print(" Could not find a suitable camera format.")
//        }
//
//     
//    }
//
//    private func configureAudioSession() {
//        let session = RTCAudioSession.sharedInstance()
//        session.lockForConfiguration()
//        do {
//            try session.setCategory(AVAudioSession.Category.playAndRecord.rawValue, with: [.defaultToSpeaker, .allowBluetooth])
//            try session.setMode(AVAudioSession.Mode.videoChat.rawValue)
//            try session.setActive(true)
//        } catch {
//            print("❌ Audio session error: \(error)")
//        }
//        session.unlockForConfiguration()
//    }
//
//
//    
// 
//    func peerConnection(for senderId: String) -> RTCPeerConnection? {
//        return peerConnections[senderId]
//    }
//    
//    func createClient(for user: Sender, isVideoCall: Bool) -> WebRTCClient {
//        clients[user.senderId]?.disconnect()
//        
//        let client = WebRTCClient(targetUser: user, factory: factory)
//        client.delegate = self
//        
//        // 🔥 Fix: Agar sidhe access nahi ho raha, toh pehle client ka peerConnection
//        // ek local variable mein le kar phir dictionary mein daalein
//        let pc = client.peerConnection
//        self.peerConnections[user.senderId] = pc
//        
//        if let audio = localAudioTrack { client.addLocalTrack(audio) }
//        if isVideoCall, let video = localVideoTrack { client.addLocalTrack(video) }
//        
//        clients[user.senderId] = client
//        return client
//    }
// 
//
//        func checkPermissions() {
//  
//            AVCaptureDevice.requestAccess(for: .video) { granted in
//                print(granted ? "✅ Camera access granted" : "❌ Camera access denied")
//            }
//            
//
//            AVCaptureDevice.requestAccess(for: .audio) { granted in
//                print(granted ? "✅ Mic access granted" : "❌ Mic access denied")
//            }
//        }
//    
//   
//    func handleRemoteOffer(sdp: String, from sId: String) {
//
//        let client: WebRTCClient
//        if let existingClient = clients[sId] {
//            client = existingClient
//        } else {
//            print("🛠 Creating client for Offer from: \(sId)")
//            let remoteUser = AppSocketManager.shared.videoUsers.first(where: { $0.senderId == sId }) ??
//                             Sender(name: "Remote", senderId: sId, content: "", isHost: false, roomId: "")
//            client = createClient(for: remoteUser, isVideoCall: true)
//        }
//
//        // 2. Set Remote Description using the Client
//        client.setRemote(sdp: sdp, type: .offer) { error in
//            if let error = error {
//                print("❌ Offer Set Error: \(error)")
//                return
//            }
//            
//            // 3. Process queued ICE candidates
//            DispatchQueue.main.async {
//                self.pendingIceCandidates[sId]?.forEach { client.peerConnection.add($0) }
//                self.pendingIceCandidates[sId]?.removeAll()
//                
//                // 4. Create Answer
//                client.makeAnswer { localSdp in
//                    AppSocketManager.shared.sendAnswer(sdp: localSdp.sdp, targetId: sId)
//                }
//            }
//        }
//    }
//    func hasConnection(for senderId: String) -> Bool {
//        guard let client = clients[senderId] else { return false }
//        // Agar connection closed ya failed hai, toh naya connection allow karo
//        let state = client.peerConnection.iceConnectionState
//        return state != .closed && state != .failed && state != .disconnected
//    }
//    
//    func handleRemoteAnswer(sdp: String, from sId: String) {
//        guard let client = clients[sId] else { return }
//        
//        client.setRemote(sdp: sdp, type: .answer) { error in
//            if let error = error {
//                print("❌ Answer Set Error: \(error)")
//            } else {
//                print("✅ Mesh Connected for: \(sId)")
//                // Process queued ICE
//                DispatchQueue.main.async {
//                    self.pendingIceCandidates[sId]?.forEach { client.peerConnection.add($0) }
//                    self.pendingIceCandidates[sId]?.removeAll()
//                }
//            }
//        }
//    }
//    func handleRemoteCandidate(dict: [String: Any], from sId: String) {
//        guard let candidateStr = dict["candidate"] as? String,
//              let sdpMid = dict["sdpMid"] as? String,
//              let sdpMLineIndex = dict["sdpMLineIndex"] as? Int32 else {
//            print("❌ Invalid Candidate Data")
//            return
//        }
//        
//        let candidate = RTCIceCandidate(sdp: candidateStr, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
//        
//        // Ab 'peerConnections' scope mein hai ✅
//        guard let peerConnection = peerConnections[sId] else {
//            print("❌ No PeerConnection found for user: \(sId)")
//            return
//        }
//        
//        // Check for Remote Description
//        if peerConnection.remoteDescription != nil {
//            peerConnection.add(candidate) { error in
//                if let error = error {
//                    print("❌ Error adding ICE: \(error.localizedDescription)")
//                }
//            }
//        } else {
//            // Queue it if SDP isn't set yet
//            if pendingIceCandidates[sId] == nil { pendingIceCandidates[sId] = [] }
//            pendingIceCandidates[sId]?.append(candidate)
//            print("🕒 Candidate queued for: \(sId)")
//        }
//    }
//    
//    // MARK: - 🚪 CLEANUP
//    
//    func closeConnection(for senderId: String) {
//        DispatchQueue.main.async {
//            self.clients[senderId]?.disconnect()
//            self.clients.removeValue(forKey: senderId)
//            self.remoteTracks.removeValue(forKey: senderId)
//            print("🗑️ Cleaned up connection for: \(senderId)")
//        }
//    }
//    
//    func closeAll() {
//        capturer?.stopCapture()
//        clients.values.forEach { $0.disconnect() }
//        
//        DispatchQueue.main.async {
//            self.clients.removeAll()
//            self.remoteTracks.removeAll()
//        }
//    }
//    
//    func getRemoteTrack(for senderId: String) -> RTCVideoTrack? {
//        return remoteTracks[senderId]
//    }
//    
//    func createAnswer(for sId: String) {
//        guard let peerConnection = peerConnections[sId] else {
//            print("❌ createAnswer: PeerConnection not found for \(sId)")
//            return
//        }
//        
//        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
//        
//        peerConnection.answer(for: constraints) { (sdp, error) in
//            if let error = error {
//                print("❌ Error creating local answer: \(error.localizedDescription)")
//                return
//            }
//            
//            guard let localSdp = sdp else { return }
//            
//            // 1. Apne side par Local Description set karo
//            peerConnection.setLocalDescription(localSdp) { error in
//                if let error = error {
//                    print("❌ Error setting local answer: \(error.localizedDescription)")
//                    return
//                }
//                
//                print("📤 Sending Answer to: \(sId)")
//                
//                // 2. Socket ke zariye Answer ko bhej do
//                // Note: AppSocketManager.shared.sendAnswer ka naam check kar lena
//                AppSocketManager.shared.sendAnswer(sdp: localSdp.sdp, targetId: sId)
//            }
//        }
//    }
//}
//
//// MARK: - 🔌 CLIENT DELEGATE
//extension WebRTCManager: WebRTCClientDelegate {
//    
//    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
//        let dict: [String: Any] = [
//            "candidate": candidate.sdp,
//            "sdpMid": candidate.sdpMid ?? "",
//            "sdpMLineIndex": candidate.sdpMLineIndex
//        ]
//        // Send to Socket
//        AppSocketManager.shared.sendIce(candidate: dict, targetId: client.targetUser.senderId)
//    }
//    
//    func webRTCClient(_ client: WebRTCClient, didReceiveRemoteVideoTrack track: RTCVideoTrack) {
//        print("📽️ Got remote track from: \(client.targetUser.senderId)")
//        DispatchQueue.main.async {
//            // Isse UI refresh hoga
//            self.remoteTracks[client.targetUser.senderId] = track
//        }
//    }
//    
//    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
//        print("⚡ Connection State Changed: \(state.rawValue) for \(client.targetUser.name)")
//        
//        if state == .disconnected || state == .failed || state == .closed {
//            self.closeConnection(for: client.targetUser.senderId)
//        }
//    }
//}
import Foundation
import WebRTC
import Combine
import AVFoundation

class WebRTCManager: NSObject, ObservableObject {
    static let shared = WebRTCManager()
    
    // 🔥 PeerConnections (WebRTCClient) aur Tracks ko store karne ke liye
    @Published var clients: [String: WebRTCClient] = [:]
    @Published var remoteTracks: [String: RTCVideoTrack] = [:]
    
    private var pendingIceCandidates: [String: [RTCIceCandidate]] = [:]
    
    private let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoder = RTCDefaultVideoEncoderFactory()
        let videoDecoder = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: videoEncoder, decoderFactory: videoDecoder)
    }()
    
    @Published var localAudioTrack: RTCAudioTrack?
    @Published var localVideoTrack: RTCVideoTrack?
    private var capturer: RTCCameraVideoCapturer?
    
    private override init() {
        super.init()
        setupLocalTracks()
        configureAudioSession()
    }
    
    // MARK: - Local Media Setup
    func setupLocalTracks() {
        let audioSource = factory.audioSource(with: nil)
        self.localAudioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
        
        let videoSource = factory.videoSource()
        self.capturer = RTCCameraVideoCapturer(delegate: videoSource)
        self.localVideoTrack = factory.videoTrack(with: videoSource, trackId: "video0")
    }
    
    func setupLocalStream() {
        configureAudioSession()
        startLocalCapture()
    }
    
    func startLocalCapture() {
        guard let device = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == .front }) else { return }
        let formats = RTCCameraVideoCapturer.supportedFormats(for: device)
        let targetWidth = 640
        let targetHeight = 480
        
        var selectedFormat: AVCaptureDevice.Format? = nil
        var currentDiff = Int.max
        
        for format in formats {
            let dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let diff = abs(Int(dimension.width) - targetWidth) + abs(Int(dimension.height) - targetHeight)
            if diff < currentDiff {
                selectedFormat = format
                currentDiff = diff
            }
        }
        
        if let format = selectedFormat {
            self.capturer?.startCapture(with: device, format: format, fps: 30)
        }
    }

    private func configureAudioSession() {
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        do {
            try session.setCategory(AVAudioSession.Category.playAndRecord.rawValue, with: [.defaultToSpeaker, .allowBluetooth])
            try session.setMode(AVAudioSession.Mode.videoChat.rawValue)
            try session.setActive(true)
        } catch {
            print("❌ Audio session error: \(error)")
        }
        session.unlockForConfiguration()
    }


    func createClient(for user: Sender, isVideoCall: Bool) -> WebRTCClient {
        // Purana connection clean karein
//        clients[user.senderId]?.disconnect()
        
        let client = WebRTCClient(targetUser: user, factory: factory)
        client.delegate = self
        
        // Local tracks add karein
        if let audio = localAudioTrack { client.addLocalTrack(audio) }
        if isVideoCall, let video = localVideoTrack { client.addLocalTrack(video) }
        
        // Dictionary mein store karein
        clients[user.senderId] = client
        return client
    }
    
//    func handleRemoteOffer(sdp: String, from sId: String) {
//        let client: WebRTCClient
//        if let existingClient = clients[sId] {
//            client = existingClient
//        } else {
//            let remoteUser = AppSocketManager.shared.videoUsers.first(where: { $0.senderId == sId }) ??
//                            Sender(name: "Remote", senderId: sId, content: "", isHost: false, roomId: "")
//            client = createClient(for: remoteUser, isVideoCall: true)
//        }
//
//        client.setRemote(sdp: sdp, type: .offer) { error in
//            if let error = error {
//                print("❌ Offer Set Error: \(error)")
//                return
//            }
//            
//            DispatchQueue.main.async {
//                // Pending ICE candidates add karein
//                self.pendingIceCandidates[sId]?.forEach { client.peerConnection.add($0) }
//                self.pendingIceCandidates[sId]?.removeAll()
//                
//                // Answer banayein
//                client.makeAnswer { localSdp in
//                    AppSocketManager.shared.sendAnswer(sdp: localSdp.sdp, targetId: sId)
//                }
//            }
//        }
//    }
    
    
    func handleRemoteOffer(sdp: String, from sId: String, completion: @escaping (RTCSessionDescription) -> Void) {
        let client: WebRTCClient
        
        // 1. Check if client exists, otherwise create it
        if let existingClient = clients[sId] {
            client = existingClient
        } else {
            print("🛠 [WEBRTC] Creating NEW client for Offer from: \(sId)")
            let remoteUser = AppSocketManager.shared.videoUsers.first(where: { $0.senderId == sId }) ??
                             Sender(name: "Remote", senderId: sId, content: "", isHost: false, roomId: "")
            client = createClient(for: remoteUser, isVideoCall: true)
        }

        // 2. Set Remote Description (Offer)
        client.setRemote(sdp: sdp, type: .offer) { error in
            if let error = error {
                print("❌ [WEBRTC] Offer Set Error: \(error.localizedDescription)")
                return
            }
            
            print("✅ [WEBRTC] Remote Offer Set for: \(sId)")

            DispatchQueue.main.async {
                // 3. IMPORTANT: Add any ICE candidates that arrived BEFORE the SDP
                if let pending = self.pendingIceCandidates[sId] {
                    print("❄️ [WEBRTC] Adding \(pending.count) pending ICE candidates for \(sId)")
                    pending.forEach { client.peerConnection.add($0) }
                    self.pendingIceCandidates.removeValue(forKey: sId)
                }
                
                // 4. Create Answer and return it to SocketManager
                client.makeAnswer { localSdp in
                    print("📝 [WEBRTC] Answer Created for: \(sId)")
                    completion(localSdp) // Yeh completion SocketManager ko answer bhejega
                }
            }
        }
    }
    
    func handleRemoteAnswer(sdp: String, from sId: String) {
        guard let client = clients[sId] else { return }
        
        client.setRemote(sdp: sdp, type: .answer) { error in
            if error == nil {
                DispatchQueue.main.async {
                    self.pendingIceCandidates[sId]?.forEach { client.peerConnection.add($0) }
                    self.pendingIceCandidates[sId]?.removeAll()
                }
            }
        }
    }
    
    func handleRemoteCandidate(dict: [String: Any], from sId: String) {
        // 1. Pehle check karo ki kya is user ka 'client' exist karta hai
        guard let client = clients[sId], let pc = client.peerConnection else {
            print("🕒 [ICE] No connection yet for \(sId), queueing candidate...")
            
            // Agar connection abhi nahi bana, toh candidate ko queue mein save karo
            let candidate = parseCandidate(dict: dict)
            if pendingIceCandidates[sId] == nil { pendingIceCandidates[sId] = [] }
            pendingIceCandidates[sId]?.append(candidate)
            return
        }
        
        // 2. Agar Remote Description set ho chuki hai, toh candidate add karo
        if pc.remoteDescription != nil {
            let candidate = parseCandidate(dict: dict)
            pc.add(candidate) { error in
                if let error = error {
                    print("❌ [ICE] Error adding candidate: \(error.localizedDescription)")
                } else {
                    print("❄️ [ICE] Candidate added successfully for \(sId)")
                }
            }
        } else {
            // 3. Agar SDP abhi process ho raha hai, toh queue mein daal do
            let candidate = parseCandidate(dict: dict)
            if pendingIceCandidates[sId] == nil { pendingIceCandidates[sId] = [] }
            pendingIceCandidates[sId]?.append(candidate)
        }
    }

    // Helper function to parse dictionary to RTCIceCandidate
    private func parseCandidate(dict: [String: Any]) -> RTCIceCandidate {
        return RTCIceCandidate(
            sdp: dict["candidate"] as? String ?? "",
            sdpMLineIndex: dict["sdpMLineIndex"] as? Int32 ?? 0,
            sdpMid: dict["sdpMid"] as? String
        )
    }
    // Helper function to create candidate object
    private func createIceCandidate(from dict: [String: Any]) -> RTCIceCandidate {
        return RTCIceCandidate(
            sdp: dict["candidate"] as? String ?? "",
            sdpMLineIndex: dict["sdpMLineIndex"] as? Int32 ?? 0,
            sdpMid: dict["sdpMid"] as? String
        )
    }
    
    // MARK: - Cleanup
    func closeConnection(for senderId: String) {
        DispatchQueue.main.async {
            self.clients[senderId]?.disconnect()
            self.clients.removeValue(forKey: senderId)
            self.remoteTracks.removeValue(forKey: senderId)
            print("🗑️ Cleaned up: \(senderId)")
        }
    }
    
    func closeAll() {
        capturer?.stopCapture()
        clients.values.forEach { $0.disconnect() }
        DispatchQueue.main.async {
            self.clients.removeAll()
            self.remoteTracks.removeAll()
        }
    }
    func hasConnection(for senderId: String) -> Bool {
        return clients[senderId] != nil
    }

    func getPeerConnection(for senderId: String) -> RTCPeerConnection? {
        return clients[senderId]?.peerConnection
    }
    func checkPermissions() {

        AVCaptureDevice.requestAccess(for: .video) { granted in
            print(granted ? "Camera access granted" : " Camera access denied")
        }


        AVCaptureDevice.requestAccess(for: .audio) { granted in
            print(granted ? " Mic access granted" : " Mic access denied")
        }
    }
    
}

// MARK: - 🔌 WebRTCClientDelegate
extension WebRTCManager: WebRTCClientDelegate {
    
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        let dict: [String: Any] = [
            "candidate": candidate.sdp,
            "sdpMid": candidate.sdpMid ?? "",
            "sdpMLineIndex": candidate.sdpMLineIndex
        ]
        AppSocketManager.shared.sendIce(candidate: dict, targetId: client.targetUser.senderId)
    }
    
    // ✅ Protocol fixed: matching WebRTCClient definition
    func webRTCClient(_ client: WebRTCClient, didReceiveRemoteVideoTrack track: RTCVideoTrack, forUser userId: String) {
        print("📽️ Got remote track from: \(userId)")
        DispatchQueue.main.async {
            self.remoteTracks[userId] = track
            print("🫒🫒🫒🫒🫒🫒🫒🫒🫒🫒🫒🫒\(self.remoteTracks.count)")
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        print("⚡ State: \(state.rawValue) for \(client.targetUser.name)")
        
        switch state {
        case .connected:
            print("✅ Connection established!")
        case .failed:
            // Sirf failure par cleanup karein
            self.closeConnection(for: client.targetUser.senderId)
        case .disconnected:
            // Yahan 3-5 second wait kar sakte hain re-connect hone ka
            print("⚠️ Disconnected, waiting for auto-reconnect...")
        default:
            break
        }
    }
}
