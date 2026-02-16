//
//  MessageView.swift
//  Chat_AC_VC
//
//  Created by Satyam Sharma Chingari on 16/02/26.
//

import Foundation

import SwiftUI

struct MessageView: View {
    let a = [2,3,4]
    
    @State private var messageText: String = ""
    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(a.indices) { msg in
                            ChatBubble()
                               
                        }
                    }
                    .padding()
                }
            
            }

          
            HStack {
                TextField("Message", text: $messageText)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                Button {
                    if !messageText.isEmpty {
                        
                        messageText = ""
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .padding(10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }
            .padding()
        }
    }
    }
#Preview {
    MessageView()
        
}
