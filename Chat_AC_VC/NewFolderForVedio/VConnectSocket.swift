import Foundation
import SocketIO
import Combine
import WebRTC
class VConnectSocket: ObservableObject {
    static let shared = VConnectSocket()
    private var manager: SocketManager!
    var socket: SocketIOClient!
    
    @Published var isConnected = false
    @Published var isInVideo = false
    @Published var isVideoActive = false
    @Published var currentPeer: PeerModel?
    @Published var activePeers: [PeerModel] = []
    @Published var showMeetingEndedAlert = false
    
    private init() {
        
        manager = SocketManager(socketURL: URL(string: "https://d18a-111-92-91-96.ngrok-free.app")!, config: [.log(false), .compress])
        socket = manager.defaultSocket
        setupHandlers()
        socket.connect()
    }
    
    func setupHandlers() {
        socket.on(clientEvent: .connect) { _, _ in self.isConnected = true }
        
        socket.on("videoMembersUpdate") { data, _ in
            guard let members = data[0] as? [[String: Any]] else { return }
            let peers = members.map { dict in
                PeerModel(
                    name: dict["name"] as? String ?? "",
                    senderId: dict["senderId"] as? String ?? "",
                    isHost: dict["isHost"] as? Bool ?? false,
                    roomId: dict["roomId"] as? String ?? "",
                    content: ""
                )
            }
            DispatchQueue.main.async {
                self.activePeers = peers
                self.checkMeshConnections()
            }
        }
        
        socket.on("receiveOffer") { data, _ in
            guard let dict = data[0] as? [String: Any],
                  let sdp = dict["sdp"] as? String,
                  let sId = dict["senderId"] as? String else { return }
            
            VConnectRTC.shared.handleRemoteOffer(sdp: sdp, from: sId) { answerSdp in
                self.socket.emit("sendAnswer", ["sdp": answerSdp.sdp, "targetId": sId, "senderId": self.currentPeer?.senderId ?? ""])
            }
        }
        
        socket.on("receiveAnswer") { data, _ in
            guard let dict = data[0] as? [String: Any],
                  let sdp = dict["sdp"] as? String,
                  let sId = dict["senderId"] as? String else { return }
            VConnectRTC.shared.handleRemoteAnswer(sdp: sdp, from: sId)
        }
        
        
        
        
        socket.on("receiveIceCandidate") { data, _ in
            guard let dict = data[0] as? [String: Any],
                  let candidate = dict["candidate"] as? [String: Any],
                  let sId = dict["senderId"] as? String else { return }
            VConnectRTC.shared.handleIceCandidate(dict: candidate, from: sId)
        }
        socket.on("peerMuteUpdate") { data, _ in
            print("📥 [SOCKET] Received peerMuteUpdate: \(data)")
            guard let dict = data[0] as? [String: Any],
                  let sId = dict["senderId"] as? String,
                  let mutedStatus = dict["isMuted"] as? Bool else { return }
            
            DispatchQueue.main.async {
                // Peer ki list mein index dhoondo aur update karo
                if let index = self.activePeers.firstIndex(where: { $0.senderId == sId }) {
                    self.activePeers[index].isMuted = mutedStatus
                    
              
                    print("👤 Peer \(sId) is now \(mutedStatus ? "Muted" : "Unmuted")")
                }
            }
        }
        socket.on("peerVideoUpdate") { data, _ in
            guard let dict = data[0] as? [String: Any],
                  let sId = dict["senderId"] as? String,
                  let videoStatus = dict["isVideoOff"] as? Bool else { return }
            
            DispatchQueue.main.async {
                if let index = self.activePeers.firstIndex(where: { $0.senderId == sId }) {
                    var newPeers = self.activePeers
                    newPeers[index].isVideoOff = videoStatus // PeerModel mein isVideoOff hona chahiye
                    self.activePeers = newPeers
                }
            }
        }
        socket.on("meetingEnded") { _, _ in
            print("🚨 [SOCKET] Host ended the meeting")
            DispatchQueue.main.async {
                self.showMeetingEndedAlert = true // ✅ Alert dikhao
                // Note: Cleanup hum alert ke button click par karenge
            }
        }
    }
    
    
    private func checkMeshConnections() {
        for peer in activePeers {
            if peer.senderId == currentPeer?.senderId { continue }
            
            // Golden Rule: Choti ID wala Offer bhejega
            if (currentPeer?.senderId ?? "") < peer.senderId {
                if VConnectRTC.shared.clients[peer.senderId] == nil {
                    VConnectRTC.shared.initiateInternalConnection(to: peer)
                }
            }
        }
    }
    
    func startRoom(id: String) {
        currentPeer?.isHost = true
        currentPeer?.roomId = id
        joinRoom(id: id)
    }
    

    
    func joinRoom(id: String) {
     
        self.currentPeer?.roomId = id
        
        guard let peer = currentPeer else { return }
        
       
        print("🚀 Joining Room: \(id) | My ID: \(peer.senderId)")
        
        
        socket.emit("joinVideo", [
            "roomId": id,
            "senderId": peer.senderId,
            "name": peer.name,
            "isHost": peer.isHost
        ])
        
        VConnectRTC.shared.prepareLocalMedia()
        self.isInVideo = true
    }
    
    
    func updateMuteStatus(isMuted: Bool) {
  
        guard let peer = currentPeer else {
            print("❌ Error: Current Peer not found")
            return
        }
        
        let data: [String: Any] = [
            "roomId": peer.roomId, // ✅ Make sure ye wahi room ID hai jo Host ki hai
            "senderId": peer.senderId,
            "isMuted": isMuted
        ]
        
        print("📤 Sending Mute Status for \(peer.senderId): \(isMuted)")
        socket.emit("toggleMute", data)
    }
    
    func updateVideoStatus(isVideoOff: Bool) {
        guard let peer = currentPeer, !peer.roomId.isEmpty else { return }
        
        let data: [String: Any] = [
            "roomId": peer.roomId,
            "senderId": peer.senderId,
            "isVideoOff": isVideoOff
        ]
        socket.emit("toggleVideo", data)
    }
    
    
    func endCall() {
        guard let peer = currentPeer else { return }
        
        let data: [String: Any] = [
            "roomId": peer.roomId,
            "isHost": peer.isHost,
            "senderId": peer.senderId
        ]
        
        socket.emit("endMeeting", data)
        
        // Khud ke liye cleanup
        self.cleanupCall()
    }

  
    func cleanupCall() {
        DispatchQueue.main.async {
            self.isInVideo = false
            self.activePeers.removeAll()
            VConnectRTC.shared.closeAllConnections() // RTC connections close karein
        }
    }
}

