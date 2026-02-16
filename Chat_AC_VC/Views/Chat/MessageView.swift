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
    @Environment(\.dismiss) private var dismiss
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
        .navigationTitle(Text("Chat"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading){
                Button{
                    dismiss()
                    
                }label:{
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 35, height: 35)
                        .cornerRadius(50)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Color.green, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        
       
    }
    }
#Preview {
    MessageView()
        
}
