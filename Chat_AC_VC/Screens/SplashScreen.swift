import SwiftUI



import SwiftUI
struct SplashScreen: View {
    @EnvironmentObject var appState: AppState
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Image("back1")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 24) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(30)
                        .frame(width: 120, height: 120)

                    Button {
                        print("Button Tapped")
                        
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                appState.showSplash = false
                            }
                        }
                    } label: {
                        Text("Get Started")
                            // ... (rest of your styling)
                    }
                }
                .scaleEffect(isAnimating ? 1 : 0.8)
                .opacity(isAnimating ? 1 : 0)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.0)) {
                        isAnimating = true
                    }
                }

                Spacer()
            }
        }
    }
}
#Preview {
    SplashScreen()
        .environmentObject(AppState())
}
