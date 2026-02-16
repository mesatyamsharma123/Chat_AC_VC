import Foundation
import SwiftUI

struct ChatView: View {
    let a = ["satyam", "sharma", "chingari", "hello"]
    let columns = [
        GridItem(.fixed(150), spacing: 10),
        GridItem(.fixed(150), spacing: 10)
    ]
    @EnvironmentObject var rooID:RoomId
    @EnvironmentObject var senders:Senders
    
    @State var showMessage:Bool = false

    var body: some View {
        NavigationStack {
            ZStack{
                Image("back1")
                    .resizable()
                    .scaledToFill()
                
                
                VStack{
                    
                    VStack (spacing : 20) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 100))
                            .foregroundColor(Color.green)
                        Text("Chit Chat")
                            .font(.system(size: 30))
                        
                    }
                    
                    
                    .padding()
                    VStack{
                        Text("Start a chat with your friends")
                            .font(.system(size: 20))
                        
                        
                        LazyVGrid(columns: columns, spacing: 10) { // 👈 vertical gap control
                            ForEach(a, id: \.self) { item in
                                Text(item)
                                    .font(.system(size: 22))
                                    .frame(width: 150, height: 60)
                                    .background(Color.green.opacity(0.6))
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.vertical, 10)
                        
                        
                        .padding(20)
                        
                        
                        Button ("Start a chat"){
                            senders.senders?.content = "hello"
                            print(senders.senders?.content ?? "no")
                            showMessage = true
                            
                            
                        }
                        .font(.system(size: 35))
                        .buttonStyle(.borderedProminent)
                        
                        
                        
                    }
                }
                .padding(30)
                .navigationTitle("Chat")
                .navigationBarTitleDisplayMode(.automatic)
                .toolbar {
                    ToolbarItem(placement:.navigationBarTrailing ){
                        Text(" Room ID:\( rooID.roomID ?? "NO ROOM")")
                            
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        
                        NavigationLink(destination: Login()) {
                            
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                    
                    
                    
                    
                }
                .navigationDestination(isPresented: $showMessage) {
                    MessageView()
                }
            }
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(RoomId())
        .environmentObject(Senders())
}
