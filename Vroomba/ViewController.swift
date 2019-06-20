//
//  ViewController.swift
//  Vroomba
//
//  Created by Tiana on 31/5/2019.
//  Copyright © 2019 Vroomba. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import AVFoundation
import VideoToolbox
import SocketIO

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, UITextFieldDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var labelCoordinates: UILabel!
    @IBOutlet weak var labelOrientation: UILabel!
    @IBOutlet weak var socketIP: UITextField!
    
    let ARConfig = ARWorldTrackingConfiguration()
    lazy var manager = SocketManager(socketURL: URL(string: "http://0.0.0.0:3000")!, config: [.log(true), .compress])
    lazy var socket: SocketIOClient = manager.defaultSocket
    var isConnectCoord: Bool = false
    var isConnectCam: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.sceneView.scene.background.contents = UIColor.black
        //self.sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin]
        self.sceneView.session.run(self.ARConfig)
        self.sceneView.session.delegate = self
        self.socketIP.delegate = self
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(self.view.endEditing(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
/*
        // Set the view's delegate
        sceneView.delegate = self
         
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
*/
    }

/*
    @IBAction func GetCoordinates(_ sender: Any) {
        //let location = getCamCoordinates(sceneView: sceneView)
        let transform = SCNMatrix4(sceneView.session.currentFrame?.camera.transform ?? matrix_identity_float4x4)
        let orientation = SCNVector3(-transform.m31, -transform.m32, transform.m33)
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        self.labelOrientation.text = "(\(orientation.x), \(orientation.y), \(orientation.z))"
        self.labelCoordinates.text = "(\(location.x), \(location.y), \(location.z))"
    }
    
    func getCamCoordinates(sceneView: ARSCNView) -> SCNVector3 {

        let transform = SCNMatrix4(sceneView.session.currentFrame?.camera.transform ?? matrix_identity_float4x4)
        //let orientation = SCNVector3(-transform.m31, -transform.m32, transform.m33)
        //let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        return SCNVector3(transform.m41, transform.m42, transform.m43)
    }
*/
    
    @IBAction func resetWorld(_ sender: UIButton) {
        self.sceneView.session.run(self.ARConfig, options: [.resetTracking, .removeExistingAnchors])
    }
    
    @IBAction func connectCam(_ sender: UIButton) {
        
        if sender.title(for: []) == "Connect Cam" {
            self.isConnectCam = true
            if !self.isConnectCoord {
                self.socket.connect()
            }
            sender.setTitle("Disconnect Cam", for: [])
        } else {
            self.isConnectCam = false
            if !self.isConnectCoord {
                self.socket.disconnect()
            }
            sender.setTitle("Connect Cam", for: [])
        }
        
    }
    
    @IBAction func connectCoord(_ sender: UIButton) {
        
        if sender.title(for: []) == "Connect Coord" {
            if !self.isConnectCam {
                self.socket.connect()
            }
            self.isConnectCoord = true
            sender.setTitle("Disconnect Coord", for: [])
        } else {
            if !self.isConnectCam {
                self.socket.disconnect()
            }
            self.isConnectCoord = false
            sender.setTitle("Connect Coord", for: [])
        }
        
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        if self.isConnectCoord {
            
            let transform = SCNMatrix4(frame.camera.transform)
            let orientation = SCNVector3(-transform.m31, -transform.m32, transform.m33)
            let location = SCNVector3(transform.m41, transform.m42, transform.m43)
            self.labelOrientation.text = "(\(orientation.x), \(orientation.y), \(orientation.z))"
            self.labelCoordinates.text = "(\(location.x), \(location.y), \(location.z))"
            
            self.socket.emit("position", "{\"x\": \(location.x), \"y\": 0, \"z\": \(location.z)}")
        }
        
        if self.isConnectCam {
             var cgImage: CGImage?
             VTCreateCGImageFromCVPixelBuffer(frame.capturedImage, options: .none, imageOut: &cgImage)
             let uiImage = UIImage(cgImage: cgImage!)
             
             let rect = CGRect(x: 0.0, y: 0.0, width: 512, height: 256)
             UIGraphicsBeginImageContext(rect.size)
             uiImage.draw(in: rect)
             let image = UIGraphicsGetImageFromCurrentImageContext()
             let imageData = image!.jpegData(compressionQuality: 0.2)!.base64EncodedString()
             UIGraphicsEndImageContext()
 
            
            //let image: UIImage? = pixelBuffertoUIImage(pixelBuffer: frame.capturedImage, scale: 0.15)
            //let imageData: String = image!.jpegData(compressionQuality: 0.25)!.base64EncodedString()
            
            self.socket.emit("camera", "{\"img\": \"\(imageData)\"}")
        }
        
    }
    
    func pixelBuffertoUIImage(pixelBuffer: CVPixelBuffer, scale: CGFloat) -> UIImage? {
        
        let size = CGSize(width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)) * scale,
                          height: CGFloat(CVPixelBufferGetHeight(pixelBuffer)) * scale)
        let uiImage = UIImage(ciImage: CIImage(cvPixelBuffer: pixelBuffer, options: nil))
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { (context) in
            uiImage.draw (in: CGRect(origin: .zero, size: size))
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        print("CONNECTING NEW SOCKET: " + self.socketIP.text!)
        self.manager = SocketManager(socketURL: URL(string: self.socketIP.text!)!, config: [.log(true), .compress])
        self.socket = manager.defaultSocket
        return true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
 /*
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

    // MARK: - ARSCNViewDelegate

    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
     
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
*/

}
