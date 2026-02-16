//
//  ChatBubble.swift
//  Chat_AC_VC
//
//  Created by Satyam Sharma Chingari on 16/02/26.
//

import Foundation
import SwiftUI

struct ChatBubble: View {
 
    let isMe = true
    var body: some View {
       
        HStack{
            if isMe {Spacer()}
            VStack(alignment: isMe ? .trailing : .leading){
                
                if !isMe {
                    Text("satyam")
                        .opacity(0.4)
                    Text("sdsdas")
                        .font(.caption2)
                        .foregroundStyle(Color(.secondaryLabel))
                }
//                Text("satyam")
//                    .opacity(0.4)
                Text("satyama")
                    .padding(10)
                    .background(isMe ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isMe ? .white : .primary)
                    .cornerRadius(12)
                
            }
            if !isMe {Spacer()}
        }
        .padding(.horizontal, 10)
    }
}
#Preview {
    ChatBubble()
}
