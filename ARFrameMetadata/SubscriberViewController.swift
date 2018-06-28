//
//  SubscriberViewController.swift
//  ARFrameMetadata
//
//  Created by Roberto Perez Cubero on 12/06/2018.
//  Copyright © 2018 tokbox. All rights reserved.
//

import UIKit
import OpenTok
import MetalKit
import SceneKit

fileprivate let FIXED_ANNOTATION_DEPTH: Float = 2
fileprivate let CAMERA_DEFAULT_ZFAR = 1000

class SubscriberViewController: UIViewController {
    
    @IBOutlet weak var debugContainerView: UIView!
    @IBOutlet weak var debugLabel: UILabel!
    
    lazy var otSession: OTSession = {
       return OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)!
    }()
    
    var subscriber: OTSubscriber?
    lazy var videoRender: ExampleVideoRender = {
        let videoRender = ExampleVideoRender()
        videoRender.delegate = self
        return videoRender
    }()
    
    var lastNode: SCNNode?
    
    override func viewDidLoad() {
        otSession.connect(withToken: kToken, error: nil)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(SubscriberViewController.viewTapped(_:)))
        view.addGestureRecognizer(tapGesture)
        
        becomeFirstResponder()
    }
    
    override var canBecomeFirstResponder: Bool {
        get {
            return true
        }
    }
    
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            otSession.signal(withType: "deleteNodes", string: nil, connection: nil, error: nil)
        }
    }
    
    @objc func viewTapped(_ recoginizer: UITapGestureRecognizer) {
        guard let lastCamera = lastNode else {
            return
        }
        let loc = recoginizer.location(in: view)
        let nodePos = lastCamera.simdWorldFront * FIXED_ANNOTATION_DEPTH
        
        otSession.signal(withType: "newNode", string: "\(nodePos.x):\(nodePos.y):\(nodePos.z):\(loc.x):\(loc.y)", connection: nil, error: nil)
    }
}

extension SubscriberViewController: ExampleVideoRenderDelegate {
    func renderer(_ renderer: ExampleVideoRender, didReceiveFrame videoFrame: OTVideoFrame) {
        guard let metadata = videoFrame.metadata else {
            return
        }
        
        let arr = metadata.toArray(type: Float.self)
        DispatchQueue.main.async {
            let arrString = "[x: \(String(format: "%.2f", arr[0])), y: \(String(format:"%.2f", arr[1])), z: \(String(format:"%.2f", arr[2]))]\n[rx: \(String(format:"%.2f", arr[3])), ry: \(String(format:"%.2f", arr[4])), rz: \(String(format:"%.2f", arr[5]))]"
            self.debugLabel.text = arrString
            
            let cameraNode = SCNNode()
            cameraNode.simdPosition.x = arr[0]
            cameraNode.simdPosition.y = arr[1]
            cameraNode.simdPosition.z = arr[2]
            
            cameraNode.eulerAngles.x = arr[3]
            cameraNode.eulerAngles.y = arr[4]
            cameraNode.eulerAngles.z = arr[5]
            
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.zFar = Double(CAMERA_DEFAULT_ZFAR)
            cameraNode.camera?.zNear = Double(arr[6])
            cameraNode.camera?.fieldOfView = CGFloat(arr[7])
            
            self.lastNode = cameraNode
        }
    }
}

extension SubscriberViewController: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession) {
        self.debugLabel.text = "Connected to session"
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
        
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        self.debugLabel.text = "Session error"
    }
    
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        
    }        
    
    func session(_ session: OTSession, streamCreated stream: OTStream) {
        guard let subscriber = OTSubscriber(stream: stream, delegate: self) else {
            return
        }
        subscriber.videoRender = videoRender
        videoRender.frame = view.bounds
        view.addSubview(videoRender)
        view.bringSubview(toFront: debugContainerView)
        session.subscribe(subscriber, error: nil)
    }
}

extension SubscriberViewController: OTSubscriberDelegate {
    func subscriberDidConnect(toStream subscriber: OTSubscriberKit) {
        self.debugLabel.text = "Subscribing"
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
    }
}
