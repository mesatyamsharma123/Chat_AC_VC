import SwiftUI

enum LoadingState  {
    case idle
    case loading
    case success
    case failure
}


struct ConnectPage: View {
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var roomId: RoomId
    
    @State var isConnected: Bool = false
    
    @State var isCreate : Bool = false
    @State var isJoin : Bool = false
    
    
    @State var roomCode: String = ""
    
    private var name: String { userStore.users?.name ?? "No Name" }
    private var stateOfConnect: String { isConnected ? "Connected" : "Disconnected plz connect " }
    
    @State var loadingState: LoadingState = .idle
    
    @State var isJoinRoom: Bool = false
    var body: some View {
        
            
            
            ZStack {
                Image("back1")
                    .resizable()
                
                
                VStack(spacing: 16) {
                    Spacer()
                    
                    Text("Welcome \(name) you are \(stateOfConnect)")
                        .multilineTextAlignment(.center)
                    
                    Button(isConnected ? "Disconnect" : "Connect") {
                        withAnimation(.easeInOut) {
                            if !isConnected {
                                loadingState = .loading
                            }
                            if isConnected {
                                
                                loadingState = .loading
                            }
                            
                            
                            
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                loadingState = .success
                                isConnected.toggle()
                                
                                
                                
                                
                            }
                            
                            
                            
                            
                        }
                        
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isConnected ? .red : .green)
                    
                    Spacer()
                    
                    
                    if loadingState == .loading {
                        VStack {
                            ProgressView()
                                .font(Font.largeTitle.bold())
                            
                        }
                        .frame(width: 200, height: 200)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        //                    .opacity(isConnected ? 1 : 0)
                        //                    .scaleEffect(isConnected ? 1:0)
                        .animation(.easeInOut, value: isConnected)
                        Spacer()
                    }
                    else if loadingState == .success && isConnected {
                        VStack(spacing: 16) {
                            Button ("Create room"){
                                roomId.roomID = "\(Int.random(in : 9999...99999))"
                                
                                
                                
                                
                                
                                
                                
                                
                                
                                isCreate = true
                                
                                
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button ("Join Room"){
                                isJoin = true
                                
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(width: 200, height: 200)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .opacity(isConnected ? 1 : 0.5)
                        .scaleEffect(isConnected ? 1 : 0.9)
                        .animation(.easeInOut, value: isConnected)
                        .alert("Join Room", isPresented: $isJoin) {
                            TextField ("Room ID", text: $roomCode)
                            Button("Join.."){
                                roomId.roomID = roomCode
                                isJoinRoom = true
                            }
                        }
                        .navigationDestination(isPresented: $isCreate) {
                                TabsView()
                            }
                  
                        .navigationDestination(isPresented: $isJoinRoom) {
                                TabsView()
                            }
         
                        Spacer()
                        
                    }
                }
            }
            .navigationTitle("Connect Room")
                .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea()
        }
    }
   





#Preview {
    ConnectPage()
        .environmentObject(UserStore())
        .environmentObject(RoomId())
}
