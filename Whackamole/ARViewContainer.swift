//
//  ARViewContainer.swift
//  Whackamole
//
//  Created by Diego Martinez on 9/25/24.
//

import Foundation
import SwiftUI
import RealityKit
import ARKit
import Combine // You need to import Combine to use AnyCancellable
import AVFoundation

struct ARViewContainer: UIViewRepresentable {
    @StateObject var game: WhacAMoleGame
    @State private var isGameBoardPlaced = false
    @State private var detectedPlanes: [UUID: AnchorEntity] = [:] // Store detected planes

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure AR Session with plane detection
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        configuration.isLightEstimationEnabled = true
        arView.session.run(configuration)

        // Add a delegate for plane detection updates
        arView.session.delegate = context.coordinator

        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)

        // Coaching overlay to help user detect planes
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coachingOverlay)
        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: arView.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: arView.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: arView.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: arView.heightAnchor)
        ])
        let sceneView = ARSCNView(frame: arView.frame)
           arView.addSubview(sceneView)

        game.arView = arView
        game.sceneView = sceneView

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(game: game, isGameBoardPlaced: $isGameBoardPlaced, detectedPlanes: $detectedPlanes)
    }

    class Coordinator: NSObject, ARSessionDelegate {
        var game: WhacAMoleGame
        @Binding var isGameBoardPlaced: Bool
        @Binding var detectedPlanes: [UUID: AnchorEntity]

        init(game: WhacAMoleGame, isGameBoardPlaced: Binding<Bool>, detectedPlanes: Binding<[UUID: AnchorEntity]>) {
            self.game = game
            self._isGameBoardPlaced = isGameBoardPlaced
            self._detectedPlanes = detectedPlanes
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            // Only process plane updates if the game board hasn't been placed
            if !isGameBoardPlaced {
                for anchor in anchors {
                    if let planeAnchor = anchor as? ARPlaneAnchor {
                        // Check if the plane already exists in detectedPlanes
                        if let existingPlaneEntity = detectedPlanes[planeAnchor.identifier] {
                            // Update the existing plane entity with new information
                            updatePlaneEntity(existingPlaneEntity, with: planeAnchor)
                        } else {
                            // Add a new visual plane for the detected anchor if it doesn't exist
                            let newPlaneEntity = createPlaneEntity(for: planeAnchor)
                            game.arView?.scene.anchors.append(newPlaneEntity)
                            detectedPlanes[planeAnchor.identifier] = newPlaneEntity
                        }
                    }
                }
            }
        }

     
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let tapLocation = gesture.location(in: gesture.view)
            if let arView = game.arView {
                if !isGameBoardPlaced {
                    // Perform a hit test to find planes at the tap location
                    let results = arView.hitTest(tapLocation, types: .existingPlaneUsingExtent)
                    if let firstResult = results.first {
                        // Place the game board at the tap location
                        let position = SIMD3<Float>(
                            firstResult.worldTransform.columns.3.x,
                            firstResult.worldTransform.columns.3.y,
                            firstResult.worldTransform.columns.3.z
                        )
                        game.placeGameBoard(at: position)
                        isGameBoardPlaced = true

                        // Disable plane detection after board placement
                        disablePlaneDetection(in: arView)

                        // Remove all plane visuals after placement
                        removePlaneVisuals()
                    }
                } else {
                    // Handle mole interaction (tap to hit the mole)
                    let hits = arView.hitTest(tapLocation, query: .nearest, mask: .all)
                    if let firstHit = hits.first {
                        game.handleEntityHit(entity: firstHit.entity)
                    }
                }
            }
        }

        // Disable plane detection after the board has been placed
        func disablePlaneDetection(in arView: ARView) {
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [] // Disable plane detection
            arView.session.run(configuration)
        }

        // Remove all visualized planes once the game board is placed
        func removePlaneVisuals() {
            print("Removing plane visuals...") // Debugging statement
            for (uuid, planeEntity) in detectedPlanes {
                print("Removing plane with ID: \(uuid)") // Debugging statement
                planeEntity.removeFromParent() // Remove the visual plane from the scene
            }
            detectedPlanes.removeAll() // Clear the dictionary of stored planes
            print("All plane visuals removed.") // Debugging statement
        }

        func createPlaneEntity(for planeAnchor: ARPlaneAnchor) -> AnchorEntity {
             // Create the main plane entity (grid)
             let mesh = MeshResource.generatePlane(width: planeAnchor.extent.x, depth: planeAnchor.extent.z)
             let material = createGridMaterial()
             let planeModel = ModelEntity(mesh: mesh, materials: [material])

             // Create red border lines around the plane
             let borderEntity = createRedBorder(for: planeAnchor)

             // Create the anchor entity for the detected plane
             let anchor = AnchorEntity(anchor: planeAnchor)
             planeModel.transform.translation = [planeAnchor.center.x, 0.001, planeAnchor.center.z]
             borderEntity.transform.translation = [planeAnchor.center.x, 0.002, planeAnchor.center.z]

             // Add both the grid and border to the anchor
             anchor.addChild(planeModel)
             anchor.addChild(borderEntity)

             return anchor
         }

         // Create a grid material to apply to the plane
        func createGridMaterial() -> UnlitMaterial {
            let texture = try! TextureResource.load(named: "grid.png")
            var material = UnlitMaterial()
            
            // Apply a neon-like tint to make the grid look bright and vivid
            material.baseColor = MaterialColorParameter.texture(texture)
            material.tintColor = UIColor.cyan.withAlphaComponent(1.0) // Neon cyan color with full opacity
            
            // Adjust opacity threshold to ensure the grid is still visible
            material.opacityThreshold = 0.3
            
            return material
        }


         // Create red border lines around the edges of the plane
        func createRedBorder(for planeAnchor: ARPlaneAnchor) -> Entity {
            let edgeThickness: Float = 0.01 // Thickness of the red border lines
            let borderLengthX = planeAnchor.extent.x + edgeThickness // Adjust length for border
            let borderLengthZ = planeAnchor.extent.z + edgeThickness

            let borderMaterial = SimpleMaterial(color: .red, isMetallic: true)

            // Create border lines (top, bottom, left, right)
            let topBorderMesh = MeshResource.generatePlane(width: borderLengthX, depth: edgeThickness)
            let bottomBorderMesh = MeshResource.generatePlane(width: borderLengthX, depth: edgeThickness)
            let leftBorderMesh = MeshResource.generatePlane(width: edgeThickness, depth: borderLengthZ)
            let rightBorderMesh = MeshResource.generatePlane(width: edgeThickness, depth: borderLengthZ)

            let topBorder = ModelEntity(mesh: topBorderMesh, materials: [borderMaterial])
            let bottomBorder = ModelEntity(mesh: bottomBorderMesh, materials: [borderMaterial])
            let leftBorder = ModelEntity(mesh: leftBorderMesh, materials: [borderMaterial])
            let rightBorder = ModelEntity(mesh: rightBorderMesh, materials: [borderMaterial])

            // Position the borders
            topBorder.transform.translation = [0, 0, planeAnchor.extent.z / 2]
            bottomBorder.transform.translation = [0, 0, -planeAnchor.extent.z / 2]
            leftBorder.transform.translation = [-planeAnchor.extent.x / 2, 0, 0]
            rightBorder.transform.translation = [planeAnchor.extent.x / 2, 0, 0]

            // Create a parent entity to hold all borders
            let borderEntity = Entity()
            borderEntity.addChild(topBorder)
            borderEntity.addChild(bottomBorder)
            borderEntity.addChild(leftBorder)
            borderEntity.addChild(rightBorder)

            // Set a name for the border entity to easily find it later
            borderEntity.name = "redBorder"

            return borderEntity
        }

        func updatePlaneEntity(_ planeEntity: AnchorEntity, with planeAnchor: ARPlaneAnchor) {
            if let planeModel = planeEntity.children.first(where: { $0 is ModelEntity }) as? ModelEntity {
                planeModel.model?.mesh = MeshResource.generatePlane(width: planeAnchor.extent.x, depth: planeAnchor.extent.z)
                planeModel.transform.translation = [planeAnchor.center.x, 0.001, planeAnchor.center.z]
            }

            // Update the border lines when the plane size changes
            if let borderEntity = planeEntity.children.first(where: { $0.name == "redBorder" }) {
                updateRedBorder(for: borderEntity, with: planeAnchor)
            }
        }


         // Update red border lines when the plane size changes
         func updateRedBorder(for borderEntity: Entity, with planeAnchor: ARPlaneAnchor) {
             let edgeThickness: Float = 0.01
             let borderLengthX = planeAnchor.extent.x + edgeThickness
             let borderLengthZ = planeAnchor.extent.z + edgeThickness

             if let topBorder = borderEntity.children.first as? ModelEntity {
                 topBorder.model?.mesh = MeshResource.generatePlane(width: borderLengthX, depth: edgeThickness)
                 topBorder.transform.translation = [0, 0, planeAnchor.extent.z / 2]
             }

             if let bottomBorder = borderEntity.children[1] as? ModelEntity {
                 bottomBorder.model?.mesh = MeshResource.generatePlane(width: borderLengthX, depth: edgeThickness)
                 bottomBorder.transform.translation = [0, 0, -planeAnchor.extent.z / 2]
             }

             if let leftBorder = borderEntity.children[2] as? ModelEntity {
                 leftBorder.model?.mesh = MeshResource.generatePlane(width: edgeThickness, depth: borderLengthZ)
                 leftBorder.transform.translation = [-planeAnchor.extent.x / 2, 0, 0]
             }

             if let rightBorder = borderEntity.children[3] as? ModelEntity {
                 rightBorder.model?.mesh = MeshResource.generatePlane(width: edgeThickness, depth: borderLengthZ)
                 rightBorder.transform.translation = [planeAnchor.extent.x / 2, 0, 0]
             }
         }
    }

    typealias UIViewType = ARView
}
