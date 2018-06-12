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
    @IBOutlet weak var subView: MTKView!
    lazy var otSession: OTSession = {
       return OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)!
    }()
    
    var subscriber: OTSubscriber?
    lazy var videoRender: AROpentokVideoRenderer = {
        return AROpentokVideoRenderer(subView)
    }()
    
    override func viewDidLoad() {
        otSession.connect(withToken: kToken, error: nil)
    }
}

extension SubscriberViewController: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession) {
        
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
        
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        
    }
    
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        
    }        
    
    func session(_ session: OTSession, streamCreated stream: OTStream) {
        guard let subscriber = OTSubscriber(stream: stream, delegate: self) else {
            return
        }
        subscriber.videoRender = videoRender
        session.subscribe(subscriber, error: nil)
    }
}

extension SubscriberViewController: OTSubscriberDelegate {
    func subscriberDidConnect(toStream subscriber: OTSubscriberKit) {
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
    }
}
