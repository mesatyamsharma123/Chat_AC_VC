

import Foundation
import SocketIO
import Combine
import WebRTC

class AppSocketManager: ObservableObject {
    static let shared = AppSocketManager()
    private var manager: SocketManager!
    var socket: SocketIOClient!
    
    // Sabhi variables jo aapne bataye:
    @Published var allUser: [Sender] = []
    @Published var audioUsers: [Sender] = []
    @Published var videoUsers: [Sender] = []
    @Published var isVideoActive = false
    @Published var isAudioActive = false
    @Published var isInVideo = false
    @Published var shouldExitCall = false
    @Published var connectionStatus: String = "Disconnected"
    
    var currentSender: Sender?
    
    private init() {
        manager = SocketManager(socketURL: URL(string:"https://d62b-2401-4900-8839-5109-8838-8a4c-1601-c582.ngrok-free.app")!, config: [
            .log(false),
            .compress,
            .reconnects(true),
            .reconnectAttempts(10),
            .reconnectWait(3)
        ])
        socket = manager.defaultSocket
        setupHandlers()
        socket.connect()
    }
    
    func setupHandlers() {
        socket.on(clientEvent: .connect) { _, _ in
            self.connectionStatus = "Connected"
            print("✅ Socket Connected")
            self.checkRoomStatus()
        }

        socket.on(clientEvent: .disconnect) { _, _ in
            self.connectionStatus = "Disconnected"
            print("⚠️ Socket Disconnected")
        }

        socket.on("roomMembers") { data, _ in
            guard let dict = data[0] as? [String: Any] else { return }
            DispatchQueue.main.async {
                if let videoStatus = dict["isVideoActive"] as? Bool {
                    self.isVideoActive = videoStatus
                }
            }
        }
        
        socket.on("user-joined") { data, _ in
            print("👤 A user joined the main room.")
        }
        
        socket.on("videoRoomStarted") { _, _ in
            DispatchQueue.main.async { self.isVideoActive = true }
        }

        socket.on("roomStatusUpdate") { data, _ in
            if let dict = data[0] as? [String: Any] {
                DispatchQueue.main.async {
                    self.isVideoActive = dict["isVideoActive"] as? Bool ?? false
                }
            }
        }

        // --- 👥 MESH FIX IN videoMembersUpdate ---
//        socket.on("videoMembersUpdate") { data, _ in
//            guard let dict = data[0] as? [String: Any],
//                  let membersArray = dict["members"] as? [[String: Any]] else { return }
//            
//            let allCurrentUsers = self.parseSenderData(membersArray)
//            
//            DispatchQueue.main.async {
//                // 1. UI update karo
//                self.videoUsers = allCurrentUsers
//                
//                guard let myId = self.currentSender?.senderId else { return }
//
//                // 2. Loop through ALL users in the room
//                for user in allCurrentUsers {
//                    // Khud ko skip karo
//                    if user.senderId == myId { continue }
//
//                    // 3. CHECK: Kya is user ke saath mera connection already hai?
//                    if !WebRTCManager.shared.hasConnection(for: user.senderId) {
//                        
//                        // 4. THE GOLDEN RULE: ID comparison
//                        // "Choti ID wala hamesha Offer bhejega, Badi ID wala Wait karega"
//                        // Isse kabhi bhi double offer ya zero offer nahi hoga.
//                        if myId < user.senderId {
//                            print("🚀 [MESH] I am (\(myId)), sending offer to (\(user.senderId))")
//                            self.connectToNewUser(user)
//                        } else {
//                            print("😴 [MESH] I am (\(myId)), waiting for offer from (\(user.senderId))")
//                        }
//                    }
//                }
//            }
//        }

        socket.on("videoMembersUpdate") { [weak self] data, _ in
            guard let self = self,
                  let dict = data[0] as? [String: Any],
                  let membersArray = dict["members"] as? [[String: Any]] else { return }
            
            // 1. Nayi list parse karo
            let allCurrentUsers = self.parseSenderData(membersArray)
            
            DispatchQueue.main.async {
                // UI Update
                self.videoUsers = allCurrentUsers
                
                guard let myId = self.currentSender?.senderId else {
                    print("❌ My ID not found, skipping negotiation")
                    return
                }

                print("👥 [MESH] Members in room: \(allCurrentUsers.count)")

                for user in allCurrentUsers {
                    let targetId = user.senderId
                    
                    // Apne aap ko skip karein
                    if targetId == myId { continue }

                    // 2. Check: Kya pehle se connection hai?
                    if !WebRTCManager.shared.hasConnection(for: targetId) {
                        
                        // 3. GOLDEN RULE: Chhoti ID wala Offer bhejega
                        // Isse collision nahi hota aur double connection nahi bante
                        if myId < targetId {
                            print("🚀 [OFFERER] I am smaller ID (\(myId)), sending offer to \(targetId)")
                            self.connectToNewUser(user)
                        } else {
                            // Badi ID wala sirf wait karein, use 'receiveOffer' handler handle karega
                            print("😴 [ANSWERER] I am bigger ID (\(myId)), waiting for offer from \(targetId)")
                        }
                    } else {
                        print("✅ [SKIP] Connection already exists for \(targetId)")
                    }
                }
            }
        }
//        socket.on("receiveOffer") { data, _ in
//            guard let dict = data[0] as? [String: Any],
//                  let sdp = dict["sdp"] as? String,
//                  let sId = dict["senderId"] as? String else { return }
//            
//            let myId = self.currentSender?.senderId ?? ""
//            
//            // 1. Pehle check karein ki kya is user ka client pehle se exist karta hai
//            if let client = WebRTCManager.shared.clients[sId] {
//                let pc = client.peerConnection
//                
//                // 2. PERFECT SYNC: Agar Collision hota hai (Dono ne ek saath offer bheja)
//                if pc?.signalingState == .haveLocalOffer {
//                    if myId > sId {
//                        // I am "Polite": Main apna offer ignore hone dunga aur samne wale ka process karunga
//                        print("🤝 [SYNC] Collision: Processing remote offer (Polite) for \(sId)")
//                    } else {
//                        // I am "Impolite": Main samne wale ka offer ignore karunga, mera wala chalne dunga
//                        print("🛡️ [SYNC] Collision: Ignoring remote offer (Impolite) from \(sId)")
//                        return
//                    }
//                }
//            }
//            
//            // 3. Sab theek hai toh handle karein
//            WebRTCManager.shared.handleRemoteOffer(sdp: sdp, from: sId)
//        }
        socket.on("receiveOffer") { [weak self] data, _ in
            guard let self = self,
                  let dict = data[0] as? [String: Any],
                  let sdp = dict["sdp"] as? String,
                  let sId = dict["senderId"] as? String else { return }

            print("📩 [SIGNAL] Received Offer from: \(sId). Processing...")

            // 1. PeerConnection ensure karein (create ya reuse)
            // Hum sirf access kar rahe hain, WebRTCManager isse internally create/manage kar lega
            _ = WebRTCManager.shared.clients[sId]

            // 2. IMPORTANT FIX: Handle Remote Offer with Completion
            // Humne yahan completion block add kiya hai jo WebRTCManager se 'Answer' sdp lega
            WebRTCManager.shared.handleRemoteOffer(sdp: sdp, from: sId) { [weak self] (answerSdp: RTCSessionDescription) in
                guard let self = self else { return }
                
                // 3. Answer tayyar hai, ab socket pe bhejo
                let answerData: [String: Any] = [
                    "targetId": sId,
                    "senderId": self.currentSender?.senderId ?? "",
                    "sdp": answerSdp.sdp,
                    "roomId": self.currentSender?.roomId ?? ""
                ]
                
                self.socket.emit("sendAnswer", answerData)
                print("📤 [SIGNAL] Answer sent back to: \(sId)")
            }
        }
        
        socket.on("receiveAnswer") { data, _ in
            guard let dict = data[0] as? [String: Any],
                  let sdp = dict["sdp"] as? String,
                  let sId = dict["senderId"] as? String else { return }
            
            print("📩 Received Answer from: \(sId)")
            WebRTCManager.shared.handleRemoteAnswer(sdp: sdp, from: sId)
        }
        
        socket.on("receiveIceCandidate") { data, _ in
            guard let dict = data[0] as? [String: Any],
                  let candidate = dict["candidate"] as? [String: Any],
                  let sId = dict["senderId"] as? String else { return }
            
            print("❄️ Received ICE from: \(sId)")
            WebRTCManager.shared.handleRemoteCandidate(dict: candidate, from: sId)
        }
        
        socket.on("videoCallEndedByHost") { _, _ in
            print("🛑 Host ended the call")
            self.exitCallInternally()
        }
        
        socket.on("userLeftVideo") { data, _ in
            if let dict = data[0] as? [String: Any], let userId = dict["senderId"] as? String {
                print("🏃 User \(userId) left the call")
                WebRTCManager.shared.closeConnection(for: userId)
            }
        }
        
        socket.on("errorOccurred") { data, _ in
            if let msg = data[0] as? String { print("❌ Server Error: \(msg)") }
        }
    }

    // MARK: - 🚀 CALL ACTIONS
    
    private func connectToNewUser(_ user: Sender) {
        let client = WebRTCManager.shared.createClient(for: user, isVideoCall: true)
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: [
            kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
            kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
        ], optionalConstraints: nil)
        
        client.peerConnection?.offer(for: constraints) { [weak self] (sdp, error) in
            guard let self = self, let localSdp = sdp else { return }
            
            client.peerConnection?.setLocalDescription(localSdp) { error in
                if let error = error {
                    print("❌ SetLocalDescription Error: \(error.localizedDescription)")
                    return
                }
                self.sendOffer(sdp: localSdp.sdp, targetId: user.senderId, name: user.name)
            }
        }
    }

    func startVideoCall(roomId: String) {
        joinVideo(roomId: roomId, asHost: true)
    }
    
    func joinVideoCall(roomId: String) {
        joinVideo(roomId: roomId, asHost: false)
    }

    func checkRoomStatus() {
        guard let me = currentSender else { return }
        socket.emit("checkRoomStatus", ["roomId": me.roomId])
    }

    func joinVideo(roomId: String, asHost: Bool) {
        guard let me = currentSender else { return }
        
        DispatchQueue.main.async {
            self.isInVideo = true
            self.shouldExitCall = false
        }
        
        let payload: [String: Any] = [
            "roomId": roomId,
            "isHost": asHost,
            "senderId": me.senderId,
            "name": me.name
        ]
        
        socket.emit("joinVideo", payload)
        WebRTCManager.shared.setupLocalStream()
    }

    
    
    func sendOffer(sdp: String, targetId: String, name: String) {
        let data: [String: Any] = [
            "sdp": sdp,
            "targetId": targetId,
            "senderId": currentSender?.senderId ?? "",
            "name": name,
            "roomId": currentSender?.roomId ?? ""
        ]
        socket.emit("sendOffer", data)
    }

    func sendAnswer(sdp: String, targetId: String) {
        guard let me = currentSender else { return }
        socket.emit("sendAnswer", ["roomId": me.roomId, "sdp": sdp, "senderId": me.senderId, "targetId": targetId])
    }

    func sendIce(candidate: [String: Any], targetId: String) {
        guard let me = currentSender else { return }
        socket.emit("sendIceCandidate", ["roomId": me.roomId, "candidate": candidate, "senderId": me.senderId, "targetId": targetId])
    }
    
    func leaveCall(roomId: String) {
        socket.emit("leaveCall", ["roomId": roomId, "senderId": currentSender?.senderId ?? ""])
        exitCallInternally()
    }
    
    func exitCallInternally() {
        DispatchQueue.main.async {
            self.isInVideo = false
            self.shouldExitCall = true
            self.videoUsers.removeAll()
            WebRTCManager.shared.closeAll()
        }
    }

    func parseSenderData(_ data: [[String: Any]]) -> [Sender] {
        return data.compactMap { d in
            return Sender(
                name: d["name"] as? String ?? "Unknown",
                senderId: d["senderId"] as? String ?? "",
                content: d["content"] as? String ?? "",
                isHost: d["isHost"] as? Bool ?? false,
                roomId: d["roomId"] as? String ?? ""
            )
        }
    }
}
