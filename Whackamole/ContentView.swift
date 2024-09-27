import SwiftUI
import RealityKit
import ARKit
import Combine

struct ContentView: View {
    @StateObject var game = WhacAMoleGame(arView: ARView(frame: .zero))
    @State private var showInstructions = true // State to show/hide instructions
    @State private var showConfirmButton = false

    var body: some View {
        ZStack {
            ARViewContainer(game: game)
                .edgesIgnoringSafeArea(.all)

            if showInstructions {
                // Instruction Overlay
                VStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Text("Welcome to Whac-A-Mole!")
                            .font(.title)
                            .foregroundColor(.yellow)
                            .padding(.bottom, 20)
                        
                        Text("Instructions:")
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading) // Left alignment
                        
                        Text("1. Place the game board in your environment by tapping on a flat surface.")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading) // Left alignment

                        Text("2. Tap the START button to begin.")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading) // Left alignment

                        Text("3. Whack the ghosts as they pop up to score points.")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading) // Left alignment

                        Text("4. Avoid hitting traps! They decrease your score.")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading) // Left alignment

                        Text("5. You have 30 seconds to get the highest score.")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading) // Left alignment
                            
                        Button(action: {
                            showInstructions.toggle() // Dismiss instructions
                        }) {
                            Text("Got it!")
                                .font(.title2)
                                .padding()
                                .background(Color.yellow)
                                .foregroundColor(.black)
                                .cornerRadius(10)
                        }
                        .padding(.top, 20)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(15)
                    Spacer()
                }
            } else {
                // Game Score and Time Display
                VStack {
                    HStack {
                        Text("SCORE: \(game.score)")
                            .foregroundColor(.yellow)
                            .font(.title)
                            .padding()
                        Spacer()
                        Text("TIME: \(game.remainingTime)")
                            .foregroundColor(.red)
                            .font(.title)
                            .padding()
                    }
                    Spacer()
                }
            }
        }
    }
}
