

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
        manager = SocketManager(socketURL: URL(string:"https://82ed-2401-4900-9507-5953-ac1c-d803-c17f-25e1.ngrok-free.app")!, config: [
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
        socket.on("videoMembersUpdate") { data, _ in
            guard let dict = data[0] as? [String: Any],
                  let membersArray = dict["members"] as? [[String: Any]] else { return }
            
            let allCurrentUsers = self.parseSenderData(membersArray)
            
            DispatchQueue.main.async {
                // 1. UI update karo
                self.videoUsers = allCurrentUsers
                
                guard let myId = self.currentSender?.senderId else { return }

                // 2. Loop through ALL users in the room
                for user in allCurrentUsers {
                    // Khud ko skip karo
                    if user.senderId == myId { continue }

                    // 3. CHECK: Kya is user ke saath mera connection already hai?
                    if !WebRTCManager.shared.hasConnection(for: user.senderId) {
                        
                        // 4. THE GOLDEN RULE: ID comparison
                        // "Choti ID wala hamesha Offer bhejega, Badi ID wala Wait karega"
                        // Isse kabhi bhi double offer ya zero offer nahi hoga.
                        if myId < user.senderId {
                            print("🚀 [MESH] I am (\(myId)), sending offer to (\(user.senderId))")
                            self.connectToNewUser(user)
                        } else {
                            print("😴 [MESH] I am (\(myId)), waiting for offer from (\(user.senderId))")
                        }
                    }
                }
            }
        }

        // --- 📨 SIGNALING HANDLERS ---
        socket.on("receiveOffer") { data, _ in
            guard let dict = data[0] as? [String: Any],
                  let sdp = dict["sdp"] as? String,
                  let sId = dict["senderId"] as? String else { return }
            
            let pc = WebRTCManager.shared.peerConnection(for: sId)
            let myId = self.currentSender?.senderId ?? ""

            // PERFECT SYNC: Agar maine bhi offer bheja hai aur samne se bhi aa gaya
            if pc?.signalingState == .haveLocalOffer {
                if myId > sId {
                    // I am "Polite": Main apna offer rollback karke samne wale ka accept karunga
                    print("🤝 [SYNC] Collision: Rolling back local offer for \(sId)")
                    // Note: handleRemoteOffer internally handles rollback if state is haveLocalOffer
                } else {
                    // I am "Impolite": Main samne wale ka offer ignore karunga, mera wala jeetega
                    print("🛡️ [SYNC] Collision: Ignoring remote offer from \(sId)")
                    return
                }
            }
            WebRTCManager.shared.handleRemoteOffer(sdp: sdp, from: sId)
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

    // MARK: - 📤 SIGNALING EMITS
    
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

//import Foundation
//import SocketIO
//import Combine
//import WebRTC
//
//class AppSocketManager: ObservableObject {
//    static let shared = AppSocketManager()
//    private var manager: SocketManager!
//    var socket: SocketIOClient!
//    
//    @Published var allUser: [Sender] = []
//    @Published var audioUsers: [Sender] = []
//    @Published var videoUsers: [Sender] = []
//    @Published var isVideoActive = false
//    @Published var isAudioActive = false
//    @Published var isInVideo = false
//    @Published var shouldExitCall = false
//    @Published var connectionStatus: String = "Disconnected"
//    
//    var currentSender: Sender?
//    
//    private init() {
//        manager = SocketManager(socketURL: URL(string:"https://82ed-2401-4900-9507-5953-ac1c-d803-c17f-25e1.ngrok-free.app")!, config: [
//            .log(false),
//            .compress,
//            .reconnects(true),
//            .reconnectAttempts(10),
//            .reconnectWait(3)
//        ])
//        socket = manager.defaultSocket
//        setupHandlers()
//        socket.connect()
//    }
//    
//    func setupHandlers() {
//        socket.on(clientEvent: .connect) { _, _ in
//            self.connectionStatus = "Connected"
//            print("✅ Socket Connected")
//            self.checkRoomStatus()
//        }
//
//        socket.on(clientEvent: .disconnect) { _, _ in
//            self.connectionStatus = "Disconnected"
//            print("⚠️ Socket Disconnected")
//        }
//
//        socket.on("roomMembers") { data, _ in
//            guard let dict = data[0] as? [String: Any] else { return }
//            DispatchQueue.main.async {
//                if let videoStatus = dict["isVideoActive"] as? Bool {
//                    self.isVideoActive = videoStatus
//                }
//            }
//        }
//        
//        // AppSocketManager.swift ke andar
//
//        // Jab koi naya user join kare
//        socket.on("user-joined") { data, _ in
//            // Isko khali kar do ya sirf print rakho.
//            // Handshake sirf "videoMembersUpdate" se manage hona chahiye.
//            print("👤 A user joined the main room.")
//        }
//        
//        socket.on("videoRoomStarted") { _, _ in
//            DispatchQueue.main.async { self.isVideoActive = true }
//        }
//
//        socket.on("roomStatusUpdate") { data, _ in
//            if let dict = data[0] as? [String: Any] {
//                DispatchQueue.main.async {
//                    self.isVideoActive = dict["isVideoActive"] as? Bool ?? false
//                }
//            }
//        }
//        // --- AppSocketManager.swift ke andar update karein ---
//        socket.on("videoMembersUpdate") { data, _ in
//            guard let dict = data[0] as? [String: Any],
//                  let membersArray = dict["members"] as? [[String: Any]] else { return }
//            
//            let allCurrentUsers = self.parseSenderData(membersArray)
//            DispatchQueue.main.async { self.videoUsers = allCurrentUsers }
//
//            for user in allCurrentUsers {
//                guard let myId = self.currentSender?.senderId, user.senderId != myId else { continue }
//
//                // MESH RULE check karein
//                if !WebRTCManager.shared.hasConnection(for: user.senderId) {
//                    // Logic: ID compare karke ek banda initiator banega
//                    if myId < user.senderId {
//                        print("🚀 Offering to: \(user.name)")
//                        self.connectToNewUser(user)
//                    } else {
//                        print("😴 Waiting for offer from: \(user.name)")
//                    }
//                }
//            }
//        }
//
//        // --- 📨 SIGNALING HANDLERS ---
//        socket.on("receiveOffer") { data, _ in
//            guard let dict = data[0] as? [String: Any],
//                  let sdp = dict["sdp"] as? String,
//                  let sId = dict["senderId"] as? String else { return }
//            
//            let pc = WebRTCManager.shared.peerConnection(for: sId)
//            
//            // ⚠️ COLLISION LOGIC
//            if pc?.signalingState == .haveLocalOffer {
//                guard let myId = self.currentSender?.senderId else { return }
//                
//                // Agar meri ID badi hai, main polite hoon. Mujhe apna offer bhool kar samne wale ka accept karna hai.
//                if myId > sId {
//                    print("⚠️ Collision! I am polite, rolling back to accept offer from: \(sId)")
//                    // WebRTC automatic rollback handle karta hai jab hum setRemoteDescription call karte hain
//                    // 'have-local-offer' state mein, lekin clean connectivity ke liye handleRemoteOffer call karein.
//                } else {
//                    print("⚠️ Collision! I have lower ID, ignoring this offer. My offer should win.")
//                    return
//                }
//            }
//
//            WebRTCManager.shared.handleRemoteOffer(sdp: sdp, from: sId)
//        }
//        socket.on("receiveAnswer") { data, _ in
//            guard let dict = data[0] as? [String: Any],
//                  let sdp = dict["sdp"] as? String,
//                  let sId = dict["senderId"] as? String else { return }
//            
//            print("📩 Received Answer from: \(sId)")
//            WebRTCManager.shared.handleRemoteAnswer(sdp: sdp, from: sId)
//        }
//        
//        socket.on("receiveIceCandidate") { data, _ in
//            guard let dict = data[0] as? [String: Any],
//                  let candidate = dict["candidate"] as? [String: Any],
//                  let sId = dict["senderId"] as? String else { return }
//            
//            print("❄️ Received ICE from: \(sId)")
//            WebRTCManager.shared.handleRemoteCandidate(dict: candidate, from: sId)
//        }
//        
//        socket.on("videoCallEndedByHost") { _, _ in
//            print("🛑 Host ended the call")
//            self.exitCallInternally()
//        }
//        
//        socket.on("userLeftVideo") { data, _ in
//            if let dict = data[0] as? [String: Any], let userId = dict["senderId"] as? String {
//                print("🏃 User \(userId) left the call")
//                WebRTCManager.shared.closeConnection(for: userId)
//            }
//        }
//        
//        socket.on("errorOccurred") { data, _ in
//            if let msg = data[0] as? String { print("❌ Server Error: \(msg)") }
//        }
//    }
//
//    // MARK: - 🚀 CALL ACTIONS
//    
//    private func connectToNewUser(_ user: Sender) {
//        // 1. Client create karein (WebRTCManager handles PeerConnection creation)
//        let client = WebRTCManager.shared.createClient(for: user, isVideoCall: true)
//        
//        // 2. Constraints set karein
//        let constraints = RTCMediaConstraints(mandatoryConstraints: [
//            kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
//            kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
//        ], optionalConstraints: nil)
//        
//        // 3. Offer create karein
//        client.peerConnection?.offer(for: constraints) { [weak self] (sdp, error) in
//            guard let self = self, let localSdp = sdp else {
//                print("❌ Offer Creation Error: \(error?.localizedDescription ?? "Unknown")")
//                return
//            }
//            
//            // 4. Local Description set karein
//            client.peerConnection?.setLocalDescription(localSdp) { error in
//                if let error = error {
//                    print("❌ SetLocalDescription Error: \(error.localizedDescription)")
//                    return
//                }
//                // 5. Server ko offer bhejein
//                self.sendOffer(sdp: localSdp.sdp, targetId: user.senderId, name: user.name)
//            }
//        }
//    }
//    private func safeToCreateOffer(for userId: String) -> Bool {
//        guard let pc = WebRTCManager.shared.peerConnection(for: userId) else { return true }
//        
//        return pc.signalingState == .stable
//    }
//
//    func startVideoCall(roomId: String) {
//        joinVideo(roomId: roomId, asHost: true)
//    }
//    
//    func joinVideoCall(roomId: String) {
//        joinVideo(roomId: roomId, asHost: false)
//    }
//
//    func checkRoomStatus() {
//        guard let me = currentSender else { return }
//        socket.emit("checkRoomStatus", ["roomId": me.roomId])
//    }
//
//    func joinVideo(roomId: String, asHost: Bool) {
//        guard let me = currentSender else { return }
//        
//        DispatchQueue.main.async {
//            self.isInVideo = true
//            self.shouldExitCall = false
//        }
//        
//        let payload: [String: Any] = [
//            "roomId": roomId,
//            "isHost": asHost,
//            "senderId": me.senderId,
//            "name": me.name
//        ]
//        
//        socket.emit("joinVideo", payload)
//        WebRTCManager.shared.setupLocalStream()
//        
//        // ❌ YE BLOCK DELETE KARO:
//        // DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { ... }
//    }
//    
//    private func initiateOffersToExistingMembers() {
//        guard let me = currentSender else { return }
//        // videoUsers list se offer initiate karein
//        for user in videoUsers where user.senderId != me.senderId {
//            if !WebRTCManager.shared.hasConnection(for: user.senderId) {
//                print("📡 Joiner: Offering to participant: \(user.name)")
//                self.connectToNewUser(user)
//            }
//        }
//    }
//
//    // MARK: - 📤 SIGNALING EMITS
//    
//    func sendOffer(sdp: String, targetId: String, name: String) {
//        let data: [String: Any] = [
//            "sdp": sdp,
//            "targetId": targetId,
//            "senderId": currentSender?.senderId ?? "",
//            "name": name,
//            "roomId": currentSender?.roomId ?? ""
//        ]
//        socket.emit("sendOffer", data)
//    }
//
//    func sendAnswer(sdp: String, targetId: String) {
//        guard let me = currentSender else { return }
//        socket.emit("sendAnswer", ["roomId": me.roomId, "sdp": sdp, "senderId": me.senderId, "targetId": targetId])
//    }
//
//    func sendIce(candidate: [String: Any], targetId: String) {
//        guard let me = currentSender else { return }
//        socket.emit("sendIceCandidate", ["roomId": me.roomId, "candidate": candidate, "senderId": me.senderId, "targetId": targetId])
//    }
//    
//    func leaveCall(roomId: String) {
//        socket.emit("leaveCall", ["roomId": roomId, "senderId": currentSender?.senderId ?? ""])
//        exitCallInternally()
//    }
//    
//    func exitCallInternally() {
//        DispatchQueue.main.async {
//            self.isInVideo = false
//            self.shouldExitCall = true
//            self.videoUsers.removeAll()
//            WebRTCManager.shared.closeAll()
//        }
//    }
//
//    // 🔥 AAPKA PARSE FUNCTION (As requested)
//    func parseSenderData(_ data: [[String: Any]]) -> [Sender] {
//        return data.compactMap { d in
//            return Sender(
//                name: d["name"] as? String ?? "Unknown",
//                senderId: d["senderId"] as? String ?? "",
//                content: d["content"] as? String ?? "",
//                isHost: d["isHost"] as? Bool ?? false,
//                roomId: d["roomId"] as? String ?? ""
//            )
//        }
//    }
//}
//import Foundation
//import SocketIO
//import Combine
//import WebRTC
//
//class AppSocketManager: ObservableObject {
//    
//    static let shared = AppSocketManager()
//    
//    private var manager: SocketManager!
//    var socket: SocketIOClient!
//    @Published var isVideoActive: Bool = false
//
//    
//    @Published var videoUsers: [Sender] = []
//    @Published var isInVideo = false
//    @Published var shouldExitCall = false
//    @Published var connectionStatus = "Disconnected"
//    
//    var currentSender: Sender?
//    
//    private init() {
//        manager = SocketManager(
//            socketURL: URL(string: "https://82ed-2401-4900-9507-5953-ac1c-d803-c17f-25e1.ngrok-free.app")!,
//            config: [
//                .log(true),
//                .compress,
//                .reconnects(true),
//                .reconnectAttempts(-1),
//                .reconnectWait(3)
//            ]
//        )
//        
//        socket = manager.defaultSocket
//        setupHandlers()
//        socket.connect()
//    }
//    
//    // MARK: - SOCKET HANDLERS
//    
//    private func setupHandlers() {
//        
//        socket.on(clientEvent: .connect) { _, _ in
//            DispatchQueue.main.async {
//                self.connectionStatus = "Connected"
//                print("✅ Connected")
//            }
//        }
//        
//        socket.on(clientEvent: .disconnect) { _, _ in
//            DispatchQueue.main.async {
//                self.connectionStatus = "Disconnected"
//                print("⚠️ Disconnected")
//            }
//        }
//        
//        socket.on("roomStatusUpdate") { data, _ in
//            if let dict = data.first as? [String: Any] {
//                DispatchQueue.main.async {
//                    self.isVideoActive = dict["isVideoActive"] as? Bool ?? false
//                }
//            }
//        }
//        socket.on("videoMembersUpdate") { data, _ in
//            guard let dict = data.first as? [String: Any],
//                  let members = dict["members"] as? [[String: Any]] else { return }
//            
//            let parsedUsers = self.parseSenderData(members)
//            
//            DispatchQueue.main.async {
//                self.videoUsers = parsedUsers
//            }
//            
//            // ONLY HOST CREATES OFFER
//            if self.currentSender?.isHost == true {
//                for user in parsedUsers {
//                    if user.senderId != self.currentSender?.senderId &&
//                       !WebRTCManager.shared.hasConnection(for: user.senderId) {
//                        
//                        print("🚀 Host creating offer to \(user.name)")
//                        self.createOffer(for: user)
//                    }
//                }
//            }
//        }
//        
//        socket.on("receiveOffer") { data, _ in
//            guard let dict = data.first as? [String: Any],
//                  let sdp = dict["sdp"] as? String,
//                  let senderId = dict["senderId"] as? String else { return }
//            
//            print("📩 Offer received from \(senderId)")
//            WebRTCManager.shared.handleRemoteOffer(sdp: sdp, from: senderId)
//        }
//        
//        socket.on("receiveAnswer") { data, _ in
//            guard let dict = data.first as? [String: Any],
//                  let sdp = dict["sdp"] as? String,
//                  let senderId = dict["senderId"] as? String else { return }
//            
//            print("📩 Answer received from \(senderId)")
//            WebRTCManager.shared.handleRemoteAnswer(sdp: sdp, from: senderId)
//        }
//        
//        socket.on("receiveIceCandidate") { data, _ in
//            guard let dict = data.first as? [String: Any],
//                  let candidate = dict["candidate"] as? [String: Any],
//                  let senderId = dict["senderId"] as? String else { return }
//            
//            WebRTCManager.shared.handleRemoteCandidate(dict: candidate, from: senderId)
//        }
//        
//        socket.on("videoCallEndedByHost") { _, _ in
//            self.exitCall()
//        }
//        
//        socket.on("userLeftVideo") { data, _ in
//            if let dict = data.first as? [String: Any],
//               let userId = dict["senderId"] as? String {
//                WebRTCManager.shared.closeConnection(for: userId)
//            }
//        }
//    }
//    
//    // MARK: - CALL ACTIONS
//    
//    func startVideoCall(roomId: String) {
//        joinVideo(roomId: roomId, isHost: true)
//    }
//    
//    func joinVideoCall(roomId: String) {
//        joinVideo(roomId: roomId, isHost: false)
//    }
//    
// func joinVideo(roomId: String, isHost: Bool) {
//        guard let me = currentSender else { return }
//        
//        isInVideo = true
//        shouldExitCall = false
//        
//        let payload: [String: Any] = [
//            "roomId": roomId,
//            "senderId": me.senderId,
//            "name": me.name,
//            "isHost": isHost
//        ]
//        
//        socket.emit("joinVideo", payload)
//        WebRTCManager.shared.setupLocalStream()
//    }
//    
//    private func createOffer(for user: Sender) {
//        
//        let client = WebRTCManager.shared.createClient(for: user)
//        
//        let constraints = RTCMediaConstraints(
//            mandatoryConstraints: [
//                kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
//                kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
//            ],
//            optionalConstraints: nil
//        )
//        
//        client.peerConnection?.offer(for: constraints) { sdp, error in
//            guard let sdp = sdp else { return }
//            
//            client.peerConnection?.setLocalDescription(sdp) { _ in
//                
//                self.socket.emit("sendOffer", [
//                    "roomId": self.currentSender?.roomId ?? "",
//                    "senderId": self.currentSender?.senderId ?? "",
//                    "targetId": user.senderId,
//                    "sdp": sdp.sdp
//                ])
//            }
//        }
//    }
//    
//    func sendAnswer(sdp: String, targetId: String) {
//        guard let me = currentSender else { return }
//        
//        socket.emit("sendAnswer", [
//            "roomId": me.roomId,
//            "senderId": me.senderId,
//            "targetId": targetId,
//            "sdp": sdp
//        ])
//    }
//    
//    func sendIce(candidate: [String: Any], targetId: String) {
//        guard let me = currentSender else { return }
//        
//        socket.emit("sendIceCandidate", [
//            "roomId": me.roomId,
//            "senderId": me.senderId,
//            "targetId": targetId,
//            "candidate": candidate
//        ])
//    }
//    
//    func leaveCall(roomId: String) {
//        socket.emit("leaveCall", [
//            "roomId": roomId,
//            "senderId": currentSender?.senderId ?? ""
//        ])
//        exitCall()
//    }
//    
//    private func exitCall() {
//        DispatchQueue.main.async {
//            self.isInVideo = false
//            self.shouldExitCall = true
//            self.videoUsers.removeAll()
//            WebRTCManager.shared.closeAll()
//        }
//    }
//    
//    private func parseSenderData(_ data: [[String: Any]]) -> [Sender] {
//        return data.compactMap { d in
//            Sender(
//                name: d["name"] as? String ?? "",
//                senderId: d["senderId"] as? String ?? "",
//                content: "",
//                isHost: d["isHost"] as? Bool ?? false,
//                roomId: d["roomId"] as? String ?? ""
//            )
//        }
//    }
//}
//
//
//
//import Foundation
//import SocketIO
//import Combine
//import WebRTC
//
//class AppSocketManager: ObservableObject {
//    static let shared = AppSocketManager()
//    private var manager: SocketManager!
//    var socket: SocketIOClient!
//    
//    @Published var videoUsers: [Sender] = []
//    @Published var isVideoActive = false
//    @Published var isInVideo = false
//    @Published var shouldExitCall = false
//    @Published var connectionStatus: String = "Disconnected"
//    
//    var currentSender: Sender?
//    
//    private init() {
//        manager = SocketManager(socketURL: URL(string:"https://82ed-2401-4900-9507-5953-ac1c-d803-c17f-25e1.ngrok-free.app")!, config: [
//            .log(false),
//            .compress,
//            .reconnects(true),
//            .reconnectAttempts(10),
//            .reconnectWait(3)
//        ])
//        socket = manager.defaultSocket
//        setupHandlers()
//        socket.connect()
//    }
//    
//    func setupHandlers() {
//        socket.on(clientEvent: .connect) { _, _ in
//            DispatchQueue.main.async { self.connectionStatus = "Connected" }
//            self.checkRoomStatus()
//        }
//
//        socket.on(clientEvent: .disconnect) { _, _ in
//            DispatchQueue.main.async { self.connectionStatus = "Disconnected" }
//        }
//
//        // --- 👥 ROOM SYNC ---
//        socket.on("videoMembersUpdate") { data, _ in
//            guard let dict = data[0] as? [String: Any],
//                  let membersArray = dict["members"] as? [[String: Any]] else { return }
//            
//            let allCurrentUsers = self.parseSenderData(membersArray)
//            
//            DispatchQueue.main.async {
//                self.videoUsers = allCurrentUsers
//                self.handleMeshConnections(with: allCurrentUsers)
//            }
//        }
//
//        // --- 📨 SIGNALING HANDLERS ---
//        socket.on("receiveOffer") { data, _ in
//            guard let dict = data[0] as? [String: Any],
//                  let sdp = dict["sdp"] as? String,
//                  let sId = dict["senderId"] as? String else { return }
//            
//            let pc = WebRTCManager.shared.peerConnection(for: sId)
//            let myId = self.currentSender?.senderId ?? ""
//
//            // Collision Handling: If I already sent an offer to this specific person
//            if pc?.signalingState == .haveLocalOffer {
//                if myId > sId { // I am polite, I will rollback
//                    print("🤝 Collision: I am polite, rolling back for \(sId)")
//                    // handleRemoteOffer handles the rollback internally in WebRTC
//                } else {
//                    print("🛡️ Collision: I am impolite, ignoring offer from \(sId)")
//                    return
//                }
//            }
//
//            WebRTCManager.shared.handleRemoteOffer(sdp: sdp, from: sId)
//        }
//
//        socket.on("receiveAnswer") { data, _ in
//            guard let dict = data[0] as? [String: Any],
//                  let sdp = dict["sdp"] as? String,
//                  let sId = dict["senderId"] as? String else { return }
//            
//            WebRTCManager.shared.handleRemoteAnswer(sdp: sdp, from: sId)
//        }
//        
//        socket.on("receiveIceCandidate") { data, _ in
//            guard let dict = data[0] as? [String: Any],
//                  let candidate = dict["candidate"] as? [String: Any],
//                  let sId = dict["senderId"] as? String else { return }
//            
//            WebRTCManager.shared.handleRemoteCandidate(dict: candidate, from: sId)
//        }
//        
//        socket.on("userLeftVideo") { data, _ in
//            if let dict = data[0] as? [String: Any], let userId = dict["senderId"] as? String {
//                WebRTCManager.shared.closeConnection(for: userId)
//            }
//        }
//    }
//
//    // MARK: - 🕸️ MESH LOGIC
//    private func handleMeshConnections(with users: [Sender]) {
//        guard let myId = currentSender?.senderId else { return }
//
//        for user in users {
//            if user.senderId == myId { continue }
//
//            // If no connection exists, decide who initiates
//            if !WebRTCManager.shared.hasConnection(for: user.senderId) {
//                // MESH RULE: Smaller ID initiates the offer
//                if myId < user.senderId {
//                    print("🚀 Initiating offer to: \(user.name)")
//                    self.connectToNewUser(user)
//                }
//            }
//        }
//    }
//
//    private func connectToNewUser(_ user: Sender) {
//        let client = WebRTCManager.shared.createClient(for: user, isVideoCall: true)
//        
//        let constraints = RTCMediaConstraints(mandatoryConstraints: [
//            kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
//            kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
//        ], optionalConstraints: nil)
//        
//        client.peerConnection?.offer(for: constraints) { [weak self] (sdp, error) in
//            guard let self = self, let localSdp = sdp else { return }
//            
//            client.peerConnection?.setLocalDescription(localSdp) { error in
//                if error == nil {
//                    self.sendOffer(sdp: localSdp.sdp, targetId: user.senderId, name: user.name)
//                }
//            }
//        }
//    }
//
//    // MARK: - 📤 EMITS
//    func sendOffer(sdp: String, targetId: String, name: String) {
//        let data: [String: Any] = [
//            "sdp": sdp,
//            "targetId": targetId,
//            "senderId": currentSender?.senderId ?? "",
//            "roomId": currentSender?.roomId ?? ""
//        ]
//        socket.emit("sendOffer", data)
//    }
//
//    func sendAnswer(sdp: String, targetId: String) {
//        guard let me = currentSender else { return }
//        socket.emit("sendAnswer", ["roomId": me.roomId, "sdp": sdp, "senderId": me.senderId, "targetId": targetId])
//    }
//
//    func sendIce(candidate: [String: Any], targetId: String) {
//        guard let me = currentSender else { return }
//        socket.emit("sendIceCandidate", ["roomId": me.roomId, "candidate": candidate, "senderId": me.senderId, "targetId": targetId])
//    }
//
//    func checkRoomStatus() {
//        guard let me = currentSender else { return }
//        socket.emit("checkRoomStatus", ["roomId": me.roomId])
//    }
//    
//    func parseSenderData(_ data: [[String: Any]]) -> [Sender] {
//        return data.compactMap { d in
//            return Sender(
//                name: d["name"] as? String ?? "Unknown",
//                senderId: d["senderId"] as? String ?? "",
//                isHost: d["isHost"] as? Bool ?? false,
//                roomId: d["roomId"] as? String ?? ""
//            )
//        }
//    }
//}
