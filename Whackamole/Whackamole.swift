//
//  Whackamole.swift
//  Whackamole
//
//  Created by Diego Martinez on 9/25/24.
//

import Foundation
import Combine
import RealityKit
import ARKit

class WhacAMoleGame: ObservableObject {
    var arView: ARView?
    var moles: [ModelEntity] = []
    var holes: [ModelEntity] = []
    var moleSpawnTimer: Timer?
    var sceneView: ARSCNView?
    var cancellables = Set<AnyCancellable>() // To store cancellable subscriptions
    var audioPlayer: AVAudioPlayer?
    var hitSoundPlayer: AVAudioPlayer?
    var startButton: ModelEntity?
    var gameTimer: Timer?
    let finalScale: SIMD3<Float> = SIMD3<Float>(0.003, 0.003, 0.003)  // The final scale for all entities
    let holeFinalScale: SIMD3<Float> = SIMD3<Float>(1.0, 1.0, 1.0)    // Final scale for holes
    let batFinalScale: SIMD3<Float> = SIMD3<Float>(0.0002, 0.0002, 0.0002)  // Final scale for bats
    let startButtonFinalScale: SIMD3<Float> = SIMD3<Float>(1.0, 1.0, 1.0)   // Final scale for start button
    
    let maxYPosition: Float = 0.1  // Fixed maximum Y position for all moles

    var availableHoles: Set<Int> = []
    var occupiedHoles: Set<Int> = []
    var moleStateMap: [ModelEntity: MoleState] = [:]
    var moleToHoleMap: [ModelEntity: Int] = [:]

    
    @Published var isGameBoardPlaced: Bool = false
    @Published var remainingTime: Int = 30  // Start with 30 seconds
    @Published var isGameStarted = false
    @Published var score: Int = 0


    enum MoleState {
        case active
        case movingDown
        case removed
    }

    // Define predefined hole positions
    let holePositions: [SIMD3<Float>] = [
        SIMD3<Float>(-0.3, 0, -0.3),   // Increased x and z separation
        SIMD3<Float>(0, 0, -0.33),     // Centered hole, further away
        SIMD3<Float>(0.3, 0, -0.27),   // Increased spacing
        SIMD3<Float>(-0.33, 0, 0),     // Farther to the left
        SIMD3<Float>(-0.12, 0, 0),     // Small shift left
        SIMD3<Float>(0.12, 0, 0),      // Small shift right
        SIMD3<Float>(0.33, 0, 0),      // Further to the right
        SIMD3<Float>(-0.27, 0, 0.33),  // More spacing in the bottom left
        SIMD3<Float>(0, 0, 0.36),      // Centered bottom hole with more spacing
        SIMD3<Float>(0.3, 0, 0.3)      // Farther right bottom corner
    ]
    
    // Define predefined fence positions for fences behind the game
    let fencePositions: [SIMD3<Float>] = [
        SIMD3<Float>(-0.4, 0, -0.8),  // First fence position (behind the game)
        SIMD3<Float>(0.0, 0, -0.8),  // Gate position (behind the game)
        SIMD3<Float>(0.4, 0, -0.8),     // Second fence position (behind the game)
    ]

    // Define predefined coffin positions for coffins near the fences
    let coffinPositions: [SIMD3<Float>] = [
        SIMD3<Float>(-0.5, 0, -0.5),  // First coffin position
        SIMD3<Float>(0.4, 0, -0.5),   // Second coffin position
    ]


    init(arView: ARView) {
        self.arView = arView
        playBackgroundMusic() // Play music when game starts
    }
 
    // Function to display the countdown


    func placeGameBoard(at position: SIMD3<Float>) {
        guard let arView = arView else { return }

        // Clear any previous anchors
        arView.scene.anchors.removeAll()

        // Get the current camera transform to orient the game board towards the camera
        let cameraTransform = arView.cameraTransform

        // Extract the forward direction of the camera in the XZ plane (ignoring Y for tilt)
        var forwardDirection = cameraTransform.matrix.columns.2
        forwardDirection.y = 0 // Ignore the Y component to keep the game board flat
        forwardDirection = normalize(forwardDirection)

        // Calculate the rotation to align with the camera's forward direction (in the XZ plane)
        let angle = atan2(forwardDirection.x, forwardDirection.z)
        let rotation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0)) // Rotate only around the Y axis

        // Create an anchor at the tapped position
        let anchor = AnchorEntity(world: position)
        anchor.orientation = rotation // Apply the rotation to the anchor
        arView.scene.anchors.append(anchor)

        // Load the floor entity asynchronously
        var cancellable: AnyCancellable? = nil
        cancellable = ModelEntity.loadModelAsync(named: "Halloween_Set_Reload")
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    print("Error loading model: \(error)")
                }
                cancellable?.cancel()
            }, receiveValue: { [weak self] entity in
                guard let self = self else { return }
                // Cast entity to ModelEntity
                 let floorModel = entity

                // Set scale and position
                floorModel.transform.scale = SIMD3<Float>(0.003, 0.003, 0.0035)
                floorModel.transform.translation = SIMD3<Float>(0.0, -0.08, -0.3)

                // Add the floor model to the anchor
                anchor.addChild(floorModel)

                // Animate the appearance of the entity
                self.animateEntityAppearance(entity: floorModel, finalScale: SIMD3<Float>(0.003, 0.003, 0.0035), duration: 0.5)
                self.animateHolesAndFences(anchor: anchor)
                
                DispatchQueue.main.async{
                    self.isGameBoardPlaced = true
                }
                // Cancel the subscription
                cancellable?.cancel()
            })
    }

    func createStartButton(at position: SIMD3<Float>) {
        guard let arView = arView else { return }
        print("creating start button ")

        // Create the text mesh for the start button with no background
        let textMesh = MeshResource.generateText("START",
                                                 extrusionDepth: 0.02,  // Adjust extrusion for thickness
                                                 font: .boldSystemFont(ofSize: 0.15),  // Large, bold font
                                                 containerFrame: CGRect(x: -0.5, y: -0.1, width: 1, height: 0.2),  // Increase frame size
                                                 alignment: .center)

        // Create a material with a yellow color for the text
        let textMaterial = SimpleMaterial(color: .yellow, isMetallic: false)

        // Create the text entity with the mesh and material
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])

        // Position the text slightly above the game board's position
        let textPosition = position + SIMD3<Float>(0, 0.5, 0)  // Adjust height above the game board
        textEntity.transform.translation = textPosition
        
        // Set a name for the text entity for identification during interaction
        textEntity.name = "StartButton"
        textEntity.generateCollisionShapes(recursive: true)

        // Add the start button to the game anchor and animate its appearance
        if let gameAnchor = arView.scene.anchors.first {
            gameAnchor.addChild(textEntity)
            print("text placed at \(textPosition)")
            // Animate the start button's appearance
            self.animateEntityAppearance(entity: textEntity, finalScale: startButtonFinalScale, duration: 0.5)
        } else {
            print("No anchor found to add the start button to.")
        }
        
        // Store reference to the start button entity
        self.startButton = textEntity
    }

    // Function for animating appearance of general Entity
   
    func animateEntityAppearance(entity: Entity, finalScale: SIMD3<Float>, duration: TimeInterval) {
        entity.transform.scale = SIMD3<Float>(0.0, 0.0, 0.0)  // Start small (hidden)
        
        // Animate the scale to its final value
        entity.move(
            to: Transform(scale: finalScale, rotation: entity.transform.rotation, translation: entity.transform.translation),
            relativeTo: entity.parent,
            duration: duration,
            timingFunction: .easeInOut  // Smooth transition
        )
    }

    func createFloor(at position: SIMD3<Float>) -> ModelEntity {
        guard let floorModel = try? Entity.loadModel(named: "Halloween_Set_Reload") else {
            fatalError("Unable to load floor model")
        }

        // Scale and position the floor model
        floorModel.transform.scale = SIMD3<Float>(0.003, 0.003, 0.0035)  // Adjust scale as needed
        floorModel.transform.translation = position // Set the floor model at the specified position

        return floorModel
    }
    func animateHolesAndFences(anchor: AnchorEntity) {
        // Create and animate holes
        for (index, position) in self.holePositions.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) { [weak self] in
                guard let self = self else { return }

                // Create hole programmatically
                let hole = self.createHole(at: position)
                self.holes.append(hole)
                self.availableHoles.insert(index)
                anchor.addChild(hole)

                // Animate the hole's appearance
                self.animateEntityAppearance(entity: hole, finalScale: SIMD3<Float>(1.0, 1.0, 1.0), duration: 0.5)
            }
        }

        // Load and animate coffins asynchronously after holes
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(holePositions.count) * 0.2) {
            var cancellable: AnyCancellable? = nil

            // Load the coffin model once
            cancellable = ModelEntity.loadModelAsync(named: "tomb3")
                .sink(receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        print("Error loading coffin model: \(error)")
                    }
                    cancellable?.cancel()
                }, receiveValue: { [weak self] entity in
                    guard let self = self else { return }
                    let coffinModel = entity

                    // Loop through coffin positions and set unique transformations
                    for (index, coffinPosition) in self.coffinPositions.enumerated() {
                        let coffin = coffinModel.clone(recursive: true) // Clone the coffin model for each position

                        // Apply scaling to adjust the coffin's size
                        coffin.transform.scale = SIMD3<Float>(0.001, 0.001, 0.001)

                        // Apply the rotation based on which coffin it is
                        let yRotation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))  // 180 degrees around Y-axis
                        let rotationAngle: Float = index == 0 ? .pi / -12 : .pi / 12  // Tilt direction based on coffin
                        let rotationAxis = SIMD3<Float>(0, 0, 1) // Tilt around the X-axis
                        let tiltRotation = simd_quatf(angle: rotationAngle, axis: rotationAxis)

                        // Combine rotations
                        coffin.transform.rotation = simd_mul(yRotation, tiltRotation)

                        // Set position and add coffin to the anchor
                        coffin.transform.translation = coffinPosition
                        anchor.addChild(coffin)

                        // Animate the coffin's appearance
                        self.animateEntityAppearance(entity: coffin, finalScale: SIMD3<Float>(0.03, 0.02, 0.02), duration: 0.5)
                    }

                    // Cancel the subscription after use
                    cancellable?.cancel()

                    // Calculate the total delay based on the number of coffins and animation duration
                    let totalDelay = Double(self.coffinPositions.count) * 0.5 + 0.5 // Adding extra 0.5 for the animation time

                    // After all coffins have appeared, add flying bats and start button
                    DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
                        self.addFlyingBats(to: anchor)
                        self.createStartButton(at: SIMD3<Float>(0, 0, 0))

                    }
                })
        }
    }

    func animateEntityAppearance(entity: ModelEntity, finalScale: SIMD3<Float>, duration: TimeInterval) {
        entity.transform.scale = SIMD3<Float>(0.0, 0.0, 0.0)  // Start small (hidden)
        
        // Animate the scale to its final value
        entity.move(
            to: Transform(scale: finalScale, rotation: entity.transform.rotation, translation: entity.transform.translation),
            relativeTo: entity.parent,
            duration: duration,
            timingFunction: .easeInOut  // Smooth transition
        )
    }

    func createHole(at position: SIMD3<Float>) -> ModelEntity {
        // Create a circular mesh to represent the hole
        let circleMesh = MeshResource.generatePlane(width: 0.1, depth: 0.1, cornerRadius: 0.05) // Circle-like shape with rounded corners

        // Create a simple black material
        let blackMaterial = SimpleMaterial(color: .gray, isMetallic: false)

        // Create the hole entity with the mesh and material
        let hole = ModelEntity(mesh: circleMesh, materials: [blackMaterial])

        // Apply scaling and translation to match your scene
        hole.transform.scale = SIMD3<Float>(1.0, 1.0, 1.0) // Adjust scale if necessary
        hole.transform.translation = position

        return hole
    }

    func addFlyingBats(to anchor: AnchorEntity) {
        // Define positions and initial angles for the bats to start from
        let batData: [(position: SIMD3<Float>, initialAngle: Float)] = [
            (SIMD3<Float>(-0.5, 0.8, 0.5), 0.0),    // Left-top corner, starting angle 0
            (SIMD3<Float>(0.5, 0.8, 0.5), .pi / 2), // Right-top corner, starting angle 90 degrees
            (SIMD3<Float>(0.0, 0.8, -0.5), .pi),    // Center-top, starting angle 180 degrees
            (SIMD3<Float>(0.0, 0.8, 0.7), -.pi / 2) // Bottom-middle, starting angle -90 degrees
        ]

        // Load the bat model once asynchronously
        guard let batModel = try? Entity.load(contentsOf: Bundle.main.url(forResource: "Toon-Bat", withExtension: "usdz")!) else {
            fatalError("Unable to load bat model")
        }

        var bats: [Entity] = []  // Store the cloned bats

        // Step 1: Clone all bats and set their initial position, rotation, and hidden scale
        for (position, initialAngle) in batData {
            // Clone the bat model for each position
            let bat = batModel.clone(recursive: true)
            bats.append(bat)  // Keep track of each bat

            // Calculate the direction the bat will face initially (based on flight)
            let forward = SIMD3<Float>(0, 0, 1)  // Bat's default forward direction
            let targetDirection = SIMD3<Float>(cos(initialAngle), 0, sin(initialAngle))
            var initialRotation = simd_quatf(from: forward, to: targetDirection)
            
            // Apply a 180-degree rotation around the Y-axis to make the bat face forward
            let yAxis = SIMD3<Float>(0, 1, 0)
            let rotate180 = simd_quatf(angle: .pi, axis: yAxis)
            initialRotation = simd_mul(initialRotation, rotate180) // Combine with 180-degree rotation

            // Set the initial position, scale, and orientation of the bat
            bat.transform.translation = position
            bat.transform.scale = SIMD3<Float>(0.000, 0.000, 0.000)  // Start hidden (scale 0)
            bat.transform.rotation = initialRotation
            anchor.addChild(bat)

            print("Bat added at position: \(position), with initial angle: \(initialAngle)")
        }

        // Step 2: Animate all bats to grow at the same time
        for bat in bats {
            bat.move(
                to: Transform(scale: SIMD3<Float>(0.0003, 0.0003, 0.0003), rotation: bat.transform.rotation, translation: bat.transform.translation),
                relativeTo: bat.parent,
                duration: 0.5,
                timingFunction: .easeInOut  // Smooth transition
            )
        }

        // Step 3: After all bats have scaled up, play animations and start flying simultaneously
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            for (index, (_, initialAngle)) in batData.enumerated() {
                let bat = bats[index]

                // Play bat animation after scaling
                for animation in bat.availableAnimations {
                    bat.playAnimation(animation.repeat()) // Repeat the animation in a loop
                }

                // Start the bat flight for each bat
                self.animateBatFlight(bat: bat, radius: 0.6, height: 0.8, duration: 5.0, initialAngle: initialAngle)
            }
        }
    }

    func animateBatFlight(bat: Entity, radius: Float, height: Float, duration: TimeInterval, initialAngle: Float) {
        // Create an animation for the bat to fly in a circular motion with a unique starting angle
        var angle: Float = initialAngle
        var lastPosition = SIMD3<Float>(radius * cos(angle), height, radius * sin(angle)) // Initial position

        var currentTime: TimeInterval = 0.0  // Track the current time
        let maxTime: TimeInterval = 2.0  // Set time for ease-in effect

        let easeIn: (TimeInterval) -> Float = { t in
            let progress = min(t / maxTime, 1.0) // Clamp progress to [0, 1]
            return Float(progress * progress * progress) // Cubic ease-in (start slow, accelerate smoothly)
        }

        // Start the flight animation immediately using the timer
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            // Calculate progress based on current time for easing
            currentTime += 0.05
            let easingFactor = easeIn(currentTime)

            // Increment the angle with the easing factor to control speed for ease-in
            angle += easingFactor * 0.05
            let x = radius * cos(angle)
            let z = radius * sin(angle)
            let newPosition = SIMD3<Float>(x, height, z)

            // Calculate the direction of movement (from last position to new position)
            let direction = normalize(newPosition - lastPosition)

            // Calculate the rotation to make the bat face the direction of movement
            let forward = SIMD3<Float>(0, 0, 1) // Assuming the bat's forward direction is along the positive Z-axis
            var rotation = simd_quatf(from: forward, to: direction)

            // Apply a 180-degree rotation around the Y-axis to make the bat face forward
            let yAxis = SIMD3<Float>(0, 1, 0)
            let rotate180 = simd_quatf(angle: .pi, axis: yAxis)
            rotation = simd_mul(rotation, rotate180) // Combine the rotation with the 180-degree rotation

            // Apply the rotation to the bat
            bat.setOrientation(rotation, relativeTo: bat.parent)

            // Move the bat to the new position
            bat.setPosition(newPosition, relativeTo: bat.parent)

            // Update the last position to the current one for the next iteration
            lastPosition = newPosition

            // Reset angle after completing a full circle
            if angle >= 2 * .pi {
                angle = 0.0
            }
        }

        RunLoop.current.add(timer, forMode: .default)
    }


}
extension WhacAMoleGame{
    
    func handleTap(at location: CGPoint) {
        guard let arView = arView else {
            print("No ARView available")
            return
        }

        let hits = arView.hitTest(location, query: .nearest, mask: .all)
        if let firstHit = hits.first {
            handleEntityHit(entity: firstHit.entity)
        } else {
            print("No entities hit")
        }
    }

    func handleEntityHit(entity: Entity) {
        // Check if the hit entity is the start button
        if let startEntity = entity as? ModelEntity, startEntity.name == "StartButton" {
            startGame()
        }
        // Otherwise, check if it's a mole
        else if let moleEntity = entity as? ModelEntity, let index = moles.firstIndex(of: moleEntity) {
            playHitSound()
            if let holeIndex = moleToHoleMap[moleEntity] {
                let holePosition = holePositions[holeIndex]

                // Check if it's a special mole or trap
                let points: Int
                if moleEntity.name == "Fastghost" {
                    points = 5  // Special mole gives 5 points
                    score += 5  // Add 5 points to the score
                } else if moleEntity.name == "trap" {
                    points = -3  // Trap decreases score by 3 points
                    score -= 3   // Subtract 3 points from the score
                } else {
                    points = 1  // Regular mole gives 1 point
                    score += 1  // Add 1 point to the score
                }

                // Show +1, +5, or -3 based on the mole hit
                showScorePopup(at: holePosition, score: points)
            }

            shrinkAndRemoveMole(mole: moleEntity, index: index)
        }
    }

    func startGame() {
        guard !isGameStarted else { return }
        isGameStarted = true
        print("Game started!")

        // Remove the start button from the scene
        if let startButton = startButton {
            startButton.removeFromParent()
            print("Start button removed from scene")
        }

        // Display countdown (3, 2, 1, Go!)
        displayCountdown(at: startButton?.transform.translation ?? SIMD3<Float>(0, 0.5, 0)) // Using the same position as the start button

        // Start a 30-second timer after countdown
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { // 4 seconds for the countdown
            self.startGameTimer()
        }
    }

    // Function to start the 30-second game timer
    func startGameTimer() {
        // Timer for 30 seconds countdown
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if self.remainingTime > 0 {
                self.remainingTime -= 1  // Decrease the time
            } else {
                self.endGame()  // End the game when time reaches zero
            }
        }

        // Start spawning moles
        startMoleSpawnTimer()
    }

    // Function to display the countdown
    func displayCountdown(at position: SIMD3<Float>) {
        let countdownSequence = ["3", "2", "1", "Go!"]

        var delay: TimeInterval = 0
        for count in countdownSequence {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.showCountdownText(count, at: position)
            }
            delay += 1.0  // Show each number with a delay of 1 second
        }
    }

    // Function to display a single countdown number
    func showCountdownText(_ text: String, at position: SIMD3<Float>) {
        guard let arView = arView else { return }

        // Create text mesh for the countdown
        let textMesh = MeshResource.generateText(text,
                                                 extrusionDepth: 0.02,
                                                 font: .boldSystemFont(ofSize: 0.15),
                                                 containerFrame: CGRect(x: -0.5, y: -0.1, width: 1, height: 0.2),
                                                 alignment: .center)

        let textMaterial = SimpleMaterial(color: .yellow, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])

        // Set the position of the text
        textEntity.transform.translation = position

        // Add text to the scene
        if let gameAnchor = arView.scene.anchors.first {
            gameAnchor.addChild(textEntity)

            // Remove text after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                textEntity.removeFromParent()
            }
        }
    }

    // Function to end the game
    func endGame() {
        guard let arView = arView else { return }

        // Stop any ongoing mole spawning
        gameTimer?.invalidate()
              moleSpawnTimer?.invalidate()
        // Display "Game Over" text
        let gameOverText = "Game Over\nScore: \(score)"

        // Create text mesh for "Game Over"
        let textMesh = MeshResource.generateText(gameOverText,
                                                 extrusionDepth: 0.02,
                                                 font: .boldSystemFont(ofSize: 0.1),
                                                 containerFrame: CGRect(x: -0.5, y: -0.2, width: 1, height: 0.4),
                                                 alignment: .center)

        let textMaterial = SimpleMaterial(color: .red, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])

        // Position the text slightly above the game board's position
        let textPosition = SIMD3<Float>(0, 0.5, 0)  // Adjust height above the game board
        textEntity.transform.translation = textPosition

        // Add the "Game Over" text to the scene
        if let gameAnchor = arView.scene.anchors.first {
            gameAnchor.addChild(textEntity)
            print("Game Over text placed at \(textPosition)")
        }
    }

}
extension WhacAMoleGame{
    func spawnMole() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Ensure that there are available holes to spawn moles into
            guard self.moles.count < 5, !self.availableHoles.isEmpty, let arView = self.arView else { return }

            // Pick a random available hole
            if let randomHoleIndex = self.availableHoles.randomElement() {
                let mole: ModelEntity
                
                // Determine whether to spawn a regular mole or the special mole (1/10 chance)
                if Int.random(in: 1...10) == 1 {
                      if Bool.random() {
                          mole = self.createSpecialMole()  // 50% chance of special mole
                      } else {
                          mole = self.createTrapEntity()  // 50% chance of trap
                      }
                  } else {
                      mole = self.createMole()  // Regular mole
                  }
                var molePosition = self.holes[randomHoleIndex].transform.translation
                molePosition.y -= 0.1  // Start the mole below ground
                mole.transform.translation = molePosition

                // Add the mole to the game
                self.moles.append(mole)
                arView.scene.anchors.first?.addChild(mole)

                // Associate the mole with the hole
                self.moleToHoleMap[mole] = randomHoleIndex
                self.moleStateMap[mole] = .active // Mark mole as active

                // Mark the hole as occupied
                self.availableHoles.remove(randomHoleIndex)
                self.occupiedHoles.insert(randomHoleIndex)

                // Move the mole up (animate)
                self.moveMoleUp(mole: mole)

                // Start a timer to make the mole go down if not hit
                Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    self?.moveMoleDown(mole: mole)
                }
            }
        }
    }
    
    func createMole() -> ModelEntity {
        guard let moleModel = try? Entity.loadModel(named: "ghost1") else {
            fatalError("Unable to load 3D model")
        }

        // Scale and lock position so it doesn't move or rotate unexpectedly
        moleModel.setScale([1, 1, 1] * 0.05, relativeTo: nil)  // Scaling down 100x
        moleModel.setPosition(SIMD3<Float>(0, 0, 0), relativeTo: nil)
        moleModel.generateCollisionShapes(recursive: true)

        return moleModel
    }
 

    func startMoleSpawnTimer() {
        moleSpawnTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            
            // Spawn a random number of moles (1 to 3) in this iteration
            let numberOfMolesToSpawn = Int.random(in: 1...3)
            for _ in 0..<numberOfMolesToSpawn {
                self.spawnMole()  // Call spawnMole for each mole to spawn
            }
        }
    }

    func createSpecialMole() -> ModelEntity {
        guard let moleModel = try? Entity.loadModel(named: "Fastghost") else {
            fatalError("Unable to load 3D model")
        }

        // Scale and position the special mole
        moleModel.setScale([1, 1, 1] * 0.50, relativeTo: nil)  // Slightly larger than regular moles
        moleModel.setPosition(SIMD3<Float>(0, 0, 0), relativeTo: nil)
        moleModel.generateCollisionShapes(recursive: true)
        moleModel.name = "Fastghost"

        return moleModel
    }

    func createTrapEntity() -> ModelEntity {
        guard let trapModel = try? Entity.loadModel(named: "Spike_Trap_01") else {
            fatalError("Unable to load 3D model for the trap")
        }

        // Scale and position the trap
        trapModel.setScale([1, 1, 1] * 0.002, relativeTo: nil)  // Slightly larger or the same size as the special mole
        trapModel.setPosition(SIMD3<Float>(0, 0, 0), relativeTo: nil)
        trapModel.generateCollisionShapes(recursive: true)
        trapModel.name = "trap"  // Set the name to identify this as a trap

        return trapModel
    }

    func moveMoleUp(mole: ModelEntity) {
        guard let parent = mole.parent else { return }
        let currentPosition = mole.transform.translation

        // Move higher for special moles, lower for traps
        let finalPosition: SIMD3<Float>
        if mole.name == "Fastghost" {
            finalPosition = SIMD3<Float>(currentPosition.x, 0.5, currentPosition.z)  // Higher for special moles
        } else if mole.name == "trap" {
            finalPosition = SIMD3<Float>(currentPosition.x, 0.02, currentPosition.z)  // Lower height for traps
        } else {
            finalPosition = SIMD3<Float>(currentPosition.x, maxYPosition, currentPosition.z)  // Regular height for normal moles
        }

        let targetTransform = Transform(scale: mole.transform.scale, rotation: mole.transform.rotation, translation: finalPosition)

        // Re-enable collision before moving up (to allow clicking)
        mole.generateCollisionShapes(recursive: true)

        mole.move(to: targetTransform, relativeTo: parent, duration: 0.5)
    }


    func moveMoleDown(mole: ModelEntity) {
        // Check if mole is still active before moving it down
        guard moleStateMap[mole] == .active else { return }
        moleStateMap[mole] = .movingDown // Update state to "moving down"
        
        guard let parent = mole.parent else { return }
        let currentPosition = mole.transform.translation

        // Move the mole back down (disappear into the hole)
        let finalPosition = SIMD3<Float>(currentPosition.x, currentPosition.y - 0.2, currentPosition.z)
        let targetTransform = Transform(scale: mole.transform.scale, rotation: mole.transform.rotation, translation: finalPosition)

        // Disable collision while moving down
        mole.components[CollisionComponent.self] = nil

        // Move down the mole
        mole.move(to: targetTransform, relativeTo: parent, duration: 0.5)

        // Schedule a timer to remove the mole after it has moved down
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.removeMole(mole: mole)
        }
    }
    func removeMole(mole: ModelEntity) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Avoid removing the same mole twice
            guard let state = self.moleStateMap[mole], state != .removed else {
                print("Mole is already being removed.")
                return
            }
            
            // Mark this mole as removed
            self.moleStateMap[mole] = .removed

            // Prevent duplicate removal by ensuring mole is still part of the array
            guard let validIndex = self.moles.firstIndex(of: mole) else {
                print("Mole already removed or not found.")
                return
            }

            // Get the hole index from the map
            guard let holeIndex = self.moleToHoleMap[mole] else {
                print("No associated hole found for this mole")
                return
            }

            // Remove mole from parent and array
            mole.removeFromParent()
            self.moles.remove(at: validIndex)

            // Mark the hole as available again
            self.availableHoles.insert(holeIndex)
            self.occupiedHoles.remove(holeIndex)

            // Remove from moleToHoleMap and moleStateMap
            self.moleToHoleMap.removeValue(forKey: mole)
            self.moleStateMap.removeValue(forKey: mole)

            print("\(holeIndex) is now available")
        }
    }

    func showScorePopup(at position: SIMD3<Float>, score: Int) {
        guard let arView = arView else { return }

        // Determine the text to display
        let scoreText: String
        let textColor: UIColor
        
        // If the score is positive, display "+" and yellow; if negative, display the number directly and use red
        if score > 0 {
            scoreText = "+\(score)"
            textColor = .yellow
        } else {
            scoreText = "\(score)"  // Negative score, no "+" sign
            textColor = .red
        }

        // Create the text mesh for the score
        let containerFrame = CGRect(x: -0.15, y: -0.075, width: 0.3, height: 0.15)
        let textMesh = MeshResource.generateText(scoreText,
                                                 extrusionDepth: 0.01,
                                                 font: .systemFont(ofSize: 0.06),
                                                 containerFrame: containerFrame,
                                                 alignment: .center,
                                                 lineBreakMode: .byTruncatingTail)

        // Create a material for the text, using yellow or red based on score
        let material = SimpleMaterial(color: textColor, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [material])

        // Position the text slightly above the mole's position
        textEntity.transform.translation = position + SIMD3<Float>(0, 0.2, 0)

        // Add the text entity to the first anchor in the scene
        if let gameAnchor = arView.scene.anchors.first {
            gameAnchor.addChild(textEntity)
        } else {
            print("No anchor found to add the text entity to.")
        }

        // Animate the text to move up and fade out
        let finalPosition = position + SIMD3<Float>(0, 0.1, 0)
        let moveTransform = Transform(translation: finalPosition)
        textEntity.move(to: moveTransform, relativeTo: textEntity, duration: 1.5, timingFunction: .easeOut)

        // Remove the text after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            textEntity.removeFromParent()
            print("\(scoreText) text removed from the scene")
        }
    }


    func shrinkAndRemoveMole(mole: ModelEntity, index: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Ensure the mole is still active before shrinking it
            guard self.moleStateMap[mole] == .active else { return }

            // Update the mole state to prevent further actions
            self.moleStateMap[mole] = .movingDown

            // Get the hole index from the map
            guard self.moleToHoleMap[mole] != nil else {
                print("No associated hole found for this mole")
                return
            }

            // Set initial scale
            var scale: SIMD3<Float> = mole.transform.scale

            // Timer to reduce the scale faster
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                // Decrease scale more aggressively
                scale *= 0.7

                // Apply the new scale to the mole
                mole.transform.scale = scale

                // Once the scale is very small, remove the mole
                if scale.x <= 0.01 {
                    timer.invalidate()

                    // Safely remove mole by calling the removeMole function
                    self.removeMole(mole: mole)
                }
            }
        }
    }
}

