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
    var arrowNode: SCNNode?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/empty.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
        sceneView.debugOptions = ARSCNDebugOptions.showWorldOrigin
        
        let arrowScene = SCNScene(named: "art.scnassets/arrow.scn")!
        arrowNode = arrowScene.rootNode.childNode(withName: "arrow", recursively: false)!
        
        capturer = SCNViewVideoCapture(sceneView: sceneView)
        capturer?.delegate = self
        otSessionDelegate = ViewControllerSessionDelegate(self)
        otSession = OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: otSessionDelegate)
        let pubSettings = OTPublisherSettings()
        otPublisher = OTPublisher(delegate: self, settings: pubSettings)
        otPublisher?.videoCapture = capturer
        
        otSession?.connect(withToken: kToken, error: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func sessionConnected() {
        otSession!.publish(otPublisher!, error: nil)
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
        print("Received Signal: \(string)")
        
        let newNode = parent.arrowNode?.clone() ?? SCNNode()
        newNode.scale = SCNVector3(0.1, 0.1, 0.1)
        
        if let nodePos = string?.split(separator: ":"),
            nodePos.count == 5,
            let newNodeX = Float(nodePos[0]),
            let newNodeY = Float(nodePos[1]),
            let newNodeZ = Float(nodePos[2]),
            let x = Float(nodePos[3]),
            let y = Float(nodePos[4])
        {
                newNode.simdPosition.x = newNodeX
                newNode.simdPosition.y = newNodeY
                newNode.simdPosition.z = newNodeZ
                let z = parent.sceneView.projectPoint(newNode.position).z
                let p = parent.sceneView.unprojectPoint(SCNVector3(x, y, z))
                newNode.position = p
                
                parent.sceneView.scene.rootNode.addChildNode(newNode)
                parent.sceneView.session.add(anchor: ARAnchor(transform: newNode.simdTransform))
        }        
    }
}
