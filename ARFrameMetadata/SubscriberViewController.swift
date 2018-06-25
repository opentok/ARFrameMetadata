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
    
    override func viewDidLoad() {
        otSession.connect(withToken: kToken, error: nil)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(SubscriberViewController.viewTapped(_:)))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func viewTapped(_ recoginizer: UITapGestureRecognizer) {
        let loc = recoginizer.location(in: view)
        otSession.signal(withType: "xy", string: "\(loc.x):\(loc.y)", connection: nil, error: nil)
    }
}

extension SubscriberViewController: ExampleVideoRenderDelegate {
    func renderer(_ renderer: ExampleVideoRender, didReceiveFrame videoFrame: OTVideoFrame) {
        guard let metadata = videoFrame.metadata else {
            return
        }
        
        let arr = metadata.toArray(type: Float.self)
        DispatchQueue.main.async {
            let arrString = "[x: \(String(format: "%.2f", arr[0])), y: \(String(format:"%.2f", arr[1])), z: \(String(format:"%.2f", arr[2]))]\n[rx: \(String(format:"%.2f", arr[3]))), ry: \(String(format:"%.2f", arr[4])), rz: \(String(format:"%.2f", arr[5])))]"
            self.debugLabel.text = arrString
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
