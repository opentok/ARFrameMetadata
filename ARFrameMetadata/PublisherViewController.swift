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
        
        capturer = SCNViewVideoCapture(sceneView: sceneView)
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
        let rootNode = parent.sceneView.scene.rootNode
        let arrowScene = SCNScene(named: "art.scnassets/arrow.scn")!
        let newNode = arrowScene.rootNode.childNode(withName: "arrow", recursively: false)!        
        newNode.scale = SCNVector3(0.1, 0.1, 0.1)
        
        let camera = rootNode.childNodes.first {
            $0.camera != nil
        }
        if let cam = camera {
            newNode.simdPosition = cam.simdWorldFront * 2
            
            if let touchXyStr = string?.split(separator: ":"),
                touchXyStr.count == 2,
                let x = Float(touchXyStr[0]),
                let y = Float(touchXyStr[1])
            {
                let z = parent.sceneView.projectPoint(newNode.position).z
                let p = parent.sceneView.unprojectPoint(SCNVector3(x, y, z))
                newNode.position = p
                print("Cam: \(camera!.eulerAngles)")
            }
            
            parent.sceneView.scene.rootNode.addChildNode(newNode)
            parent.sceneView.session.add(anchor: ARAnchor(transform: newNode.simdTransform))
        }        
    }
}
