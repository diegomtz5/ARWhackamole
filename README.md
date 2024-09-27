# Whac-A-Mole AR Game

Welcome to **Whac-A-Mole AR**, a fun augmented reality (AR) game where players can whack moles as they pop up in the real world! This project uses **ARKit**, **RealityKit**, and **SwiftUI** to bring the classic Whac-A-Mole game to life, leveraging augmented reality to create an immersive experience.

## Features

- **AR Game Board Placement**: Users can place the game board on a flat surface in their environment.
- **Interactive Moles**: Tap on the moles as they pop up to score points.
- **Countdown Timer**: Players have 30 seconds to achieve the highest score.
- **Special Moles and Traps**: Hit special moles for bonus points, but avoid traps that reduce your score.
- **Animated Entities**: Moles and other objects are animated with smooth transitions.
- **In-game Sound Effects**: Audio feedback for hits, including background music.

## Getting Started

### Prerequisites

- **Xcode 12** or later
- An iOS device with **ARKit** support (iPhone 6S or later).
- **Swift 5** and **iOS 14** or later.
- **Note**: This project **requires a real device** to run ARKit (it will not work on the simulator).

### Installation

1. **Clone the repository**:

2. **Open the project in Xcode**:
    - Open the `WhacAMole.xcodeproj` file.

3. **Build and run** the project on a real device (ARKit does not work on the simulator).

### How to Play

1. **Launch the app**.
2. **Place the game board** by tapping on a flat surface in your environment.
3. Once the game board is placed, tap the **START** button to begin the game.
4. **Whack the moles** by tapping them as they appear.
5. **Special moles** give you bonus points, while traps decrease your score. Be cautious!
6. You have **30 seconds** to score as many points as possible.

### Controls
- Tap on moles to score points.
- Special moles give you bonus points.
- Traps decrease your score, so be cautious!

# Demo Video

[![Watch the video](https://img.youtube.com/vi/vPeDQkK7g3E/maxresdefault.jpg)](https://youtu.be/vPeDQkK7g3E)

Click on the image to watch the demo video!


## Project Structure

- **ContentView.swift**: The main SwiftUI view containing the AR view and game score display.
- **WhacAMoleGame.swift**: The core game logic, including mole spawning, interactions, and timers.
- **ARViewContainer.swift**: SwiftUI container for the ARView.
- **Assets**: Contains the 3D models and textures for moles, traps, and other game objects.

## Technologies Used

- **SwiftUI**: For the user interface and game overlay.
- **ARKit**: For the augmented reality interactions.
- **RealityKit**: For rendering 3D objects and animations.
- **Combine**: For handling asynchronous events and state changes.
- **AVFoundation**: For background music and sound effects.

## Future Improvements

- Add more animations and mole variations.
- Implement difficulty levels (easy, medium, hard).
- High-score tracking with Firebase or Core Data.
- Multiplayer mode using GameKit.

## Contributing

If you'd like to contribute to the project, feel free to fork the repository and submit a pull request!

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
