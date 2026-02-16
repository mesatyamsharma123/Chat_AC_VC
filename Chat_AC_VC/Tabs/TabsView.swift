//
//  TabsView.swift
//  Chat_AC_VC
//
//  Created by Satyam Sharma Chingari on 14/02/26.
//

import Foundation
import SwiftUI
struct TabsView: View {
    @State private var selection = 0
    @EnvironmentObject var roomId: RoomId
    @EnvironmentObject var loginState: AppState
    

    var currentTitle: String {
        switch selection {
        case 0: return "Chat Box"
        case 1: return "Audio Call"
        case 2: return "Video Stream"
        default: return "Chit Chat"
        }
    }
    
    var body: some View {
        TabView(selection: $selection) {
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "house")
                }
                .tag(0)
            
            AudioView()
                .tabItem {
                    Label("Audio", systemImage: "mic")
                }
                .tag(1)
            
            VideoView()
                .tabItem {
                    Label("Video", systemImage: "video")
                }
                .tag(2)
        }
    
        .navigationTitle(currentTitle)
        .navigationBarTitleDisplayMode(.inline)
     
        
     
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        
        .toolbar {
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("ID: \(roomId.roomID ?? "N/A")")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
            
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    loginState.isLoggedIn = false
                } label: {
                    Image(systemName: "power") 
                        .foregroundColor(.red)
                }
            }
        }
    }
}
#Preview {
    NavigationStack {
        TabsView()
            .environmentObject(RoomId())
    }
}
