//
//  AudioView.swift
//  Chat_AC_VC
//
//  Created by Satyam Sharma Chingari on 14/02/26.
//

import Foundation
import SwiftUI

struct AudioView: View {
    let a = ["satyam", "sharma", "chingari", "hello"]
    let columns = [
        GridItem(.fixed(150), spacing: 10),
        GridItem(.fixed(150), spacing: 10)
    ]
    @EnvironmentObject var roomId : RoomId
    
    var body: some View {
 
            
            
            ZStack{
                Image("back1")
                    .resizable()
                    .scaledToFill()
                
                
                VStack{
                    
                    VStack (spacing : 20) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 100))
                            .foregroundColor(Color.purple)
                        Text("Auido Chat")
                            .font(.system(size: 30))
                        
                        
                    }
                    
                    
                    .padding()
                    VStack{
                        Text("Start a aduio calling with your friends")
                            .font(.system(size: 20))
                        
                        
                        
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(a, id: \.self) { item in
                                Text(item)
                                    .font(.system(size: 22))
                                    .frame(width: 150, height: 60)
                                    .background(Color.purple.opacity(0.3))
                                    .cornerRadius(10)
                                
                            }
                        }
                        .padding(.vertical, 10)
                        
                        
                        .padding(20)
                        
                        
                        Button ("Audio call"){
                            
                        }
                        .font(.system(size: 35))
                        .buttonStyle(.borderedProminent)
                        
                        
                        
                    }
                }
                .padding(30)
            }
            .navigationTitle("Audio Call...")
            .navigationBarTitleDisplayMode(.automatic)
            .toolbar {
                ToolbarItem(placement:.navigationBarTrailing ){
                    Text(" Room ID:\( roomId.roomID ?? "NO ROOM")")
                    
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    
                    NavigationLink(destination: Login()) {
                        
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
    
}
#Preview {
    AudioView()
        .environmentObject(RoomId())
}
