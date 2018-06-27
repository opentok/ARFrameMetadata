//
//  ViewController.swift
//  ARFrameMetadata
//
//  Created by Roberto Perez Cubero on 24/05/2018.
//  Copyright © 2018 tokbox. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import OpenTok

class PublisherViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var capturer: SCNViewVideoCapture?
    var otSession: OTSession?
    var otPublisher: OTPublisher?
    var otSessionDelegate: ViewControllerSessionDelegate?
    var starNode: SCNNode?
    var ballNode: SCNNode?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        sceneView.autoenablesDefaultLighting = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/empty.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
        sceneView.debugOptions = ARSCNDebugOptions.showWorldOrigin
        
        let markerScene = SCNScene(named: "art.scnassets/marker.scn")!
        starNode = markerScene.rootNode.childNode(withName: "star", recursively: false)!
        ballNode = markerScene.rootNode.childNode(withName: "ball", recursively: false)!
        
        capturer = SCNViewVideoCapture(sceneView: sceneView)
        capturer?.delegate = self
        otSessionDelegate = ViewControllerSessionDelegate(self)
        otSession = OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: otSessionDelegate)
        let pubSettings = OTPublisherSettings()
        otPublisher = OTPublisher(delegate: self, settings: pubSettings)
        otPublisher?.videoCapture = capturer
        
        otSession?.connect(withToken: kToken, error: nil)
        
        becomeFirstResponder()
    }
    
    override var canBecomeFirstResponder: Bool {
        get {
            return true
        }
    }
    
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            deleteAllObjects()
        }
    }
    
    fileprivate func deleteAllObjects() {
        let nodes = sceneView.scene.rootNode.childNodes.filter { return $0.name == "ball" || $0.name == "star" || $0.name == "marker" }
        nodes.forEach({ node in
            node.removeFromParentNode()
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
    }
    
    func sessionConnected() {
        otSession!.publish(otPublisher!, error: nil)
    }
    
    func addNewNode(withString string: String) {
        guard let star = starNode,
            let ball = ballNode,
            let ballGeom = ball.clone().geometry?.copy() as? SCNGeometry,
            let starGeom = star.clone().geometry?.copy() as? SCNGeometry else {
            print("Error getting models.")
            return
        }
        
        let newNode: SCNNode = {
            if arc4random_uniform(10) % 2 == 0 {
                let node = SCNNode(geometry: ballGeom)
                node.scale = SCNVector3(0.05, 0.05, 0.05)
                node.name = "ball"
                return node
            } else {
                let node = SCNNode(geometry: starGeom)
                node.scale = SCNVector3(0.001, 0.001, 0.001)
                node.name = "star"
                return node
            }
        }()
        
        let nodePos = string.split(separator: ":")
        if  nodePos.count == 5,
            let newNodeX = Float(nodePos[0]),
            let newNodeY = Float(nodePos[1]),
            let newNodeZ = Float(nodePos[2]),
            let x = Float(nodePos[3]),
            let y = Float(nodePos[4])
        {
            newNode.simdPosition.x = newNodeX
            newNode.simdPosition.y = newNodeY
            newNode.simdPosition.z = newNodeZ
            
            let z = sceneView.projectPoint(newNode.position).z
            let p = sceneView.unprojectPoint(SCNVector3(x, y, z))
            newNode.position = p
            newNode.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat(Float.pi * 2), z: 0, duration: 3)))
            
            sceneView.scene.rootNode.addChildNode(newNode)
            sceneView.session.add(anchor: ARAnchor(transform: newNode.simdTransform))
            
            // Add line
            let lineNode = SCNNode(geometry: SCNCylinder(radius: 0.005, height: CGFloat(abs(newNode.position.y))))
            lineNode.name = "marker"
            lineNode.geometry?.firstMaterial = SCNMaterial()
            lineNode.geometry?.firstMaterial?.diffuse.contents = UIColor.gray
            lineNode.position = newNode.position
            if newNode.position.y > 0 {
                lineNode.position.y -= abs(lineNode.position.y) / 2
            } else {
                lineNode.position.y += abs(lineNode.position.y) / 2
            }
            sceneView.scene.rootNode.addChildNode(lineNode)
        }
    }
}

extension PublisherViewController: SCNViewVideoCaptureDelegate {
    func prepare(videoFrame: OTVideoFrame) {
        let cameraNode = sceneView.scene.rootNode.childNodes.first {
            $0.camera != nil
        }
        if let node = cameraNode, let cam = node.camera {
            let data = Data(fromArray: [
                node.simdPosition.x,
                node.simdPosition.y,
                node.simdPosition.z,
                node.eulerAngles.x,
                node.eulerAngles.y,
                node.eulerAngles.z,
                Float(cam.zNear),
                Float(cam.fieldOfView)
                ])
            
            var err: OTError?
            videoFrame.setMetadata(data, error: &err)
            if let e = err {
                print("Error adding frame metadata: \(e.localizedDescription)")
            }
        }
    }
}

extension PublisherViewController: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print("Publisher error: \(error)")
    }
}

class ViewControllerSessionDelegate : NSObject, OTSessionDelegate {
    let parent: PublisherViewController
    
    init(_ parent: PublisherViewController) {
        self.parent = parent
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("Session Fail")
    }
    
    func session(_ session: OTSession, streamCreated stream: OTStream) {
        print("Stream Created")
    }
    
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print("Stream Destroyed")
    }
    
    func sessionDidConnect(_ session: OTSession) {
        print("SessionConnected")
        parent.sessionConnected()
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
        print("Disconnect")
    }
    
    func session(_ session: OTSession, receivedSignalType type: String?, from connection: OTConnection?, with string: String?) {
        print("Received Signal\ntype:\(type ?? "nil") - \(string ?? "nil")")
        if type == "newNode", let coords = string{
            parent.addNewNode(withString: coords)
        } else if type == "deleteNodes" {
            parent.deleteAllObjects()
        }        
    }
}
