//import SwiftUI
//
//enum LoadingState  {
//    case idle
//    case loading
//    case success
//    case failure
//}
//
//
//struct ConnectPage: View {
//    @EnvironmentObject var userStore: UserStore
//    @EnvironmentObject var roomId: RoomId
//    @EnvironmentObject var senders: Senders
//    
//    @State var isConnected: Bool = false
//    
//    @State var isCreate : Bool = false
//    @State var isJoin : Bool = false
//    
//    
//    @State var roomCode: String = ""
//    let senderId: String = UUID().uuidString
//    
//    private var name: String { userStore.users?.name ?? "No Name" }
//    private var stateOfConnect: String { isConnected ? "Connected" : "Disconnected plz connect " }
//    
//    @State var loadingState: LoadingState = .idle
//    
//    @State var isJoinRoom: Bool = false
//    var body: some View {
//        
//            
//            
//            ZStack {
//                Image("back1")
//                    .resizable()
//                
//                
//                VStack(spacing: 16) {
//                    Spacer()
//                    
//                    Text("Welcome \(name) you are \(stateOfConnect)")
//                        .multilineTextAlignment(.center)
//                    
//                    Button(isConnected ? "Disconnect" : "Connect") {
//                        withAnimation(.easeInOut) {
//                            if !isConnected {
//                                loadingState = .loading
//                            }
//                            if isConnected {
//                                
//                                loadingState = .loading
//                            }
//                            
//                            
//                            
//                            
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//                                loadingState = .success
//                                isConnected.toggle()
//                                
//                                
//                                
//                                
//                            }
//                            
//                            
//                            
//                            
//                        }
//                        
//                    }
//                    .buttonStyle(.borderedProminent)
//                    .tint(isConnected ? .red : .green)
//                    
//                    Spacer()
//                    
//                    
//                    if loadingState == .loading {
//                        VStack {
//                            ProgressView()
//                                .font(Font.largeTitle.bold())
//                            
//                        }
//                        .frame(width: 200, height: 200)
//                        .background(.ultraThinMaterial)
//                        .cornerRadius(10)
//                      
//                        .animation(.easeInOut, value: isConnected)
//                        Spacer()
//                    }
//                    else if loadingState == .success && isConnected {
//                        VStack(spacing: 16) {
//                            Button ("Create room"){
//                                roomId.roomID = "\(Int.random(in : 9999...99999))"
//                                
//                                senders.senders = Sender(
//                                       name: userStore.users?.name ?? "Anonymous",
//                                       senderId: senderId,
//                                       content: "",
//                                       isHost: true,
//                                       roomId: roomId.roomID ?? ""
//                                   )
//
//                                
//                                
//                                isCreate = true
//                                
//                                
//                            }
//                            .buttonStyle(.borderedProminent)
//                            
//                            Button ("Join Room"){
//                                isJoin = true
//                                
//                            }
//                            .buttonStyle(.borderedProminent)
//                        }
//                        .frame(width: 200, height: 200)
//                        .background(.ultraThinMaterial)
//                        .cornerRadius(10)
//                        .opacity(isConnected ? 1 : 0.5)
//                        .scaleEffect(isConnected ? 1 : 0.9)
//                        .animation(.easeInOut, value: isConnected)
//                        .alert("Join Room", isPresented: $isJoin) {
//                            TextField ("Room ID", text: $roomCode)
//                            Button("Join.."){
//                                roomId.roomID = roomCode
//                                senders.senders = Sender(
//                                       name: userStore.users?.name ?? "Anonymous",
//                                       senderId: senderId,
//                                       content: "",
//                                       isHost: false,
//                                       roomId: roomId.roomID ?? ""
//                                   )
//                                
//                                isJoinRoom = true
//                            }
//                        }
//                        .navigationDestination(isPresented: $isCreate) {
//                                TabsView()
//                            }
//                  
//                        .navigationDestination(isPresented: $isJoinRoom) {
//                                TabsView()
//                            }
//         
//                        Spacer()
//                        
//                    }
//                }
//            }
//            .navigationTitle("Connect Room")
//                .navigationBarTitleDisplayMode(.inline)
//            .ignoresSafeArea()
//        }
//    }
//   
//
//
//
//
//
//#Preview {
//    ConnectPage()
//        .environmentObject(UserStore())
//        .environmentObject(RoomId())
//        .environmentObject(Senders())
//}
//
import SwiftUI

struct ConnectPage: View {
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var roomId: RoomId
    @EnvironmentObject var senders: Senders
    
    // 🔌 Socket Manager ko observe karein
    @StateObject var socketManager = AppSocketManager.shared
    
    @State var isCreate : Bool = false
    @State var isJoin : Bool = false
    @State var isJoinRoom: Bool = false
    @State var roomCode: String = ""
    
    let senderId: String = UUID().uuidString
    
    private var name: String { userStore.users?.name ?? "No Name" }
    
    // Status ab socketManager se real-time aayega
    private var stateOfConnect: String {
        socketManager.connectionStatus == "Connected" ? "Connected" : "Disconnected"
    }
    
    var body: some View {
        ZStack {
            Image("back1")
                .resizable()
            
            VStack(spacing: 16) {
                Spacer()
                
                Text("Welcome \(name)\nYou are \(stateOfConnect)")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .font(.headline)
                
                // 🟢 Connect/Disconnect Button
                Button(socketManager.connectionStatus == "Connected" ? "Disconnect" : "Connect Now") {
                    handleSocketConnection()
                }
                .buttonStyle(.borderedProminent)
                .tint(socketManager.connectionStatus == "Connected" ? .red : .green)
                
                Spacer()
                
                // Connection hone par hi Create/Join options dikhao
                if socketManager.connectionStatus == "Connected" {
                    VStack(spacing: 16) {
                        Button ("Create room"){
                            setupSession(asHost: true)
                            isCreate = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button ("Join Room"){
                            isJoin = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(width: 250, height: 180)
                    .background(.ultraThinMaterial)
                    .cornerRadius(15)
                    .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
            }
        }
        .navigationTitle("Connect Room")
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea()
        // Join Dialog
        .alert("Join Room", isPresented: $isJoin) {
            TextField ("Room ID", text: $roomCode)
            Button("Join"){
                roomId.roomID = roomCode
                setupSession(asHost: false)
                isJoinRoom = true
            }
            Button("Cancel", role: .cancel) { }
        }
        // Navigation Logic
        .navigationDestination(isPresented: $isCreate) { TabsView() }
        .navigationDestination(isPresented: $isJoinRoom) { TabsView() }
    }
    
    // MARK: - ⚙️ LOGIC
    
    private func handleSocketConnection() {
        // AppSocketManager already init mein connect karta hai,
        // par aap yahan manully toggle kar sakte hain.
        // manager.socket.connect() ya disconnect() call kar ke.
    }
    
    private func setupSession(asHost: Bool) {
        // 1. Room ID generate ya set karna
        if asHost {
            roomId.roomID = "\(Int.random(in : 9999...99999))"
        }
        
        // 2. Sender Object banana
        let me = Sender(
            name: userStore.users?.name ?? "Anonymous",
            senderId: senderId,
            content: "",
            isHost: asHost,
            roomId: roomId.roomID ?? ""
        )
        
        // 3. Global Store Update karna
        senders.senders = me
        
        // 🔥 CRITICAL: SocketManager ko batana ki "Main" kaun hoon
        socketManager.currentSender = me
        
        print("✅ Session Setup: \(asHost ? "Host" : "Participant") in Room \(me.roomId)")
    }
}
