//
//  Login.swift
//  Chat_AC_VC
//
//  Created by Satyam Sharma Chingari on 14/02/26.
//

import Foundation
import SwiftUI

struct Login: View {
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var appState: AppState

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    private func login() {
//        guard !name.isEmpty, !email.isEmpty, !password.isEmpty else { return }

        userStore.users = UserModel(
            name: name,
            email: email,
            password: password
        )

        appState.isLoggedIn = true
    }

    var body: some View {
        ZStack {
            Image("back1")
                .resizable()
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Image("logo")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .cornerRadius(50)

                Form {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                    SecureField("Password", text: $password)

                    Button("Login") {
                        login()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(height: 300)
                .scrollContentBackground(.hidden)
                .background(Color.black.opacity(0.4))
                .cornerRadius(10)
            }
            .padding()
        }
    }
}
#Preview {
    Login().environmentObject(UserStore())
        .environmentObject(RoomId())
        .environmentObject(AppState())

}

