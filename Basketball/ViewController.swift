//
//  ViewController.swift
//  Basketball
//
//  Created by Denis Bystruev on 29/01/2019.
//  Copyright © 2019 Denis Bystruev. All rights reserved.
//

//import UIKit
//import SceneKit
import ARKit

class ViewController: UIViewController {
    
    // MARK: - ... Properties
    var ballNode: SCNNode?
    
    var hoopAdded = false

    // MARK: - ... @IBOutlet
    @IBOutlet var sceneView: ARSCNView!
    
    // MARK: - ... UIViewController Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Swifch on lighting
        sceneView.autoenablesDefaultLighting = true
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical]

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - ... Custom Methods
    func createBasketball() {
        guard let ballNode = ballNode?.clone() ?? createNode(from: "Ball") else { return }
        
        self.ballNode = ballNode
        
        guard let frame = sceneView.session.currentFrame else { return }
        
        ballNode.simdTransform = frame.camera.transform
        
        let body = SCNPhysicsBody(
            type: .dynamic,
            shape: SCNPhysicsShape(
                node: ballNode,
                options: [SCNPhysicsShape.Option.collisionMargin: 0.01]
            )
        )
        ballNode.physicsBody = body
        
        let power = Float(10)
        
        let transform = SCNMatrix4(frame.camera.transform)
        
        let force = SCNVector3(
            -transform.m31 * power,
            -transform.m32 * power,
            -transform.m33 * power
        )
        
        ballNode.physicsBody?.applyForce(force, asImpulse: true)
        
        sceneView.scene.rootNode.addChildNode(ballNode)
    }
    
    func createHoop(result: ARHitTestResult) {
        guard let hoopNode = createNode(from: "Hoop") else { return }
        
        hoopNode.simdTransform = result.worldTransform
        hoopNode.eulerAngles.x -= .pi / 2
        
        hoopAdded = true
        stopPlaneDetection()
        removeWalls()
        
        let body = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(
                node: hoopNode,
                options: [
                    SCNPhysicsShape.Option.type:
                        SCNPhysicsShape.ShapeType.concavePolyhedron
                ]
            )
        )
        hoopNode.physicsBody = body
        
        sceneView.scene.rootNode.addChildNode(hoopNode)
    }
    
    func createNode(from name: String) -> SCNNode? {
        guard let scene = SCNScene(named: "art.scnassets/\(name).scn") else {
            print(#function, "ERROR: Can't create node from scene \(name).scn")
            
            return nil
        }
        
        let node = scene.rootNode.childNode(withName: name, recursively: false)
        
        return node
    }
    
    func createWall(anchor: ARPlaneAnchor) -> SCNNode {
        
        let extent = anchor.extent
        let width = CGFloat(extent.x)
        let height = CGFloat(extent.z)
        
        let node = SCNNode(geometry: SCNPlane(width: width, height: height))
        
        node.eulerAngles.x -= .pi / 2
        node.geometry?.firstMaterial?.diffuse.contents = #colorLiteral(red: 0.5568627715, green: 0.3529411852, blue: 0.9686274529, alpha: 1)
        node.name = "Wall"
        node.opacity = 0.25
        
        return node
    }
    
    func removeWalls() {
        sceneView.scene.rootNode.enumerateChildNodes { node, _ in
            if node.name == "Wall" {
                node.removeFromParentNode()
            }
        }
    }
    
    func stopPlaneDetection() {
        guard let configuration = sceneView.session.configuration as? ARWorldTrackingConfiguration else { return }
        
        configuration.planeDetection = []
        
        sceneView.session.run(configuration)
    }
    
    // MARK: - ... @IBAction
    @IBAction func screenTapped(_ sender: UITapGestureRecognizer) {
        if !hoopAdded {
            let location = sender.location(in: sceneView)
            
            guard let result = sceneView.hitTest(location, types: [.existingPlaneUsingExtent]).first else { return }
            
            createHoop(result: result)
        } else {
            createBasketball()
        }
    }
    
}

// MARK: - ... ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let anchor = anchor as? ARPlaneAnchor else { return }
        
        let wall = createWall(anchor: anchor)
        
        node.addChildNode(wall)
    }
}
