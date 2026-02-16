//
//  VideoView.swift
//  Chat_AC_VC
//
//  Created by Satyam Sharma Chingari on 14/02/26.
//

import Foundation
import SwiftUI

struct VideoView: View {
    @EnvironmentObject var roomId: RoomId
    @EnvironmentObject var loginState: AppState

    let a = ["satyam", "sharma", "chingari", "hello"]
    let columns = [
        GridItem(.fixed(150), spacing: 10),
        GridItem(.fixed(150), spacing: 10)
    ]

    var body: some View {
        ZStack {
            Image("back1")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                VStack(spacing: 20) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.yellow)
                    Text("Video Chat")
                        .font(.system(size: 30))
                }
                .padding()

                VStack {
                    Text("Start a video calling with your friends")
                        .font(.system(size: 20))

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(a, id: \.self) { item in
                            Text(item)
                                .font(.system(size: 22))
                                .frame(width: 150, height: 60)
                                .background(Color.red.opacity(0.6))
                                .cornerRadius(10)
                        }
                    }
                    .padding()

                    Button("Video call") { }
                        .font(.system(size: 35))
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(30)
        }
        .navigationTitle("Video Call")
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Text("Room: \(roomId.roomID ?? "NO ROOM")")
                    .font(.caption)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    loginState.isLoggedIn = false
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
            }
        }
    }
}

#Preview {
    VideoView()
        .environmentObject(RoomId())
        .environmentObject(AppState())
}
