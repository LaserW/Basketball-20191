//
//  ViewController.swift
//  Basketball
//
//  Created by Denis Bystruev on 29/01/2019.
//  Copyright © 2019 Denis Bystruev. All rights reserved.
//

import UIKit
import SceneKit
import ARKit


class ViewController: UIViewController {
    
    enum bodyType: Int {
        case none = 0
        case top = 1
        case bottom = 2
        case ball = 4
        case hoop = 8
    }
    
    // MARK: - ... Properties
    var ballNode: SCNNode?

    
    var hoopAdded = false
    var trueNodeTop = false
    var trueNodeBottom = false
    
    var score: Int = 0
    // MARK: - ... @IBOutlet
    @IBOutlet var sceneView: ARSCNView!
    
    
    ///////////////////////////////////////////////////////
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

        sceneView.scene.physicsWorld.contactDelegate = self

    }
    ///////////////////////////////////////////////////////
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical]
        print("WA")
        // Run the view's session
        sceneView.session.run(configuration)
    }
    ////////////////
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("WD")
        // Pause the view's session
        sceneView.session.pause()
    }
    ////////////////
    ////////////////
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
        body.categoryBitMask = bodyType.ball.rawValue
        body.collisionBitMask = bodyType.hoop.rawValue
        body.contactTestBitMask = bodyType.top.rawValue | bodyType.bottom.rawValue
        
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
       // return ballNode
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
        body.categoryBitMask = bodyType.hoop.rawValue
        body.collisionBitMask = bodyType.ball.rawValue
        hoopNode.physicsBody = body
        sceneView.scene.rootNode.addChildNode(hoopNode)
        
    }
    
    func createCylinderBottom(result: ARHitTestResult)  {
        guard let cylinderBottomNode = createNode(from: "cylinder") else { return }
        
        cylinderBottomNode.simdTransform = result.worldTransform
        cylinderBottomNode.scale = SCNVector3(0.3,0.025,0.3)
        cylinderBottomNode.eulerAngles.x -= .pi / 2
        
        cylinderBottomNode.position.x -= 0.0
        cylinderBottomNode.position.z += 0.5
        cylinderBottomNode.position.y -= 0.6
        
        let physicShape = SCNPhysicsShape(geometry: cylinderBottomNode.geometry!, options: nil)
        let bodyDown = SCNPhysicsBody(type: .kinematic, shape: physicShape)
        
        bodyDown.categoryBitMask = bodyType.bottom.rawValue
        bodyDown.collisionBitMask = bodyType.none.rawValue
        bodyDown.contactTestBitMask = bodyType.ball.rawValue
        
        bodyDown.mass = 0

        cylinderBottomNode.physicsBody = bodyDown
        
        sceneView.scene.rootNode.addChildNode(cylinderBottomNode)
    }
    
    
    func createCylinderTop(result: ARHitTestResult) {
      
        guard let cylinderTopNode = createNode(from: "cylinder") else { return }
       
        cylinderTopNode.simdTransform = result.worldTransform
        cylinderTopNode.scale = SCNVector3(0.3,0.025,0.3)
        cylinderTopNode.eulerAngles.x -= .pi / 2
        
        cylinderTopNode.position.x -= 0.0   //-035 right left
        cylinderTopNode.position.z += 0.5    //+06 //05 045 0.65
        cylinderTopNode.position.y -= 0.4
        
        let physicShape = SCNPhysicsShape(geometry: cylinderTopNode.geometry!, options: nil)
        let bodyTop = SCNPhysicsBody(type: .kinematic, shape: physicShape)
        
        bodyTop.categoryBitMask = bodyType.top.rawValue
        bodyTop.collisionBitMask = bodyType.none.rawValue
        bodyTop.contactTestBitMask = bodyType.ball.rawValue
        
        bodyTop.mass = 0
        
        cylinderTopNode.physicsBody = bodyTop
        
        sceneView.scene.rootNode.addChildNode(cylinderTopNode)
    }
    
/////////////////
    
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
            createCylinderBottom(result: result)
            createCylinderTop(result: result)
        } else {
            if(trueNodeBottom == true && trueNodeTop == true) {
                score += 1
                print(score)
                
            }
            createBasketball()
            trueNodeTop = false
            trueNodeBottom = false
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

extension ViewController: SCNPhysicsContactDelegate {
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {

        let nodeA = contact.nodeA
        let nodeB = contact.nodeB
        //print("???????????")
        if (nodeA.physicsBody?.contactTestBitMask == bodyType.ball.rawValue) /* && nodeB.physicsBody?.contactTestBitMask == bodyType.ball.rawValue) || (nodeB.physicsBody?.contactTestBitMask == bodyType.ball.rawValue && nodeA.physicsBody?.contactTestBitMask == bodyType.top.rawValue)*/ {
print("???????????")
             trueNodeTop = true
            
        }
        if trueNodeTop == true{
            if nodeB.physicsBody?.contactTestBitMask == bodyType.ball.rawValue /* && nodeB.physicsBody?.contactTestBitMask == bodyType.bottom.rawValue) || (nodeB.physicsBody?.contactTestBitMask == bodyType.ball.rawValue && nodeA.physicsBody?.contactTestBitMask == bodyType.bottom.rawValue) */{
                trueNodeBottom = true
              print("?????")
            }
        }
        
        
    }
}
