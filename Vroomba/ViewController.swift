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
    @IBOutlet weak var labelConnectedIP: UILabel!
    @IBOutlet weak var portIP: UITextField!
    @IBOutlet weak var port: UITextField!
    
    let ARConfig = ARWorldTrackingConfiguration()
    let redis = Redis()
    var isConnect: Bool = false
    let bufferSize: Int = 3
    var bufferCounter: Int = 0
    var pushData: Array<String> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.sceneView.scene.background.contents = UIColor.black
        //self.sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin]
        self.sceneView.session.run(self.ARConfig)
        self.sceneView.session.delegate = self
        self.port.delegate = self
        
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
    
    @IBAction func connectCoord(_ sender: UIButton) {
        
        if self.isConnect {
            //Close connection with Redis
            self.isConnect = false
            sender.setTitle("Connect", for: [])
        } else {
            //Establish connection with Redis
            
            redis.connect(host: self.portIP.text!, port: Int32(self.port.text!) ?? 0) { (redisError: NSError?) in
            //redis.connect(host: "192.168.1.5", port: 6379) { (redisError: NSError?) in
                
                //Check for if host and port are incorrect0
                if let error = redisError {
                    print(error)
                    return
                }
                
                /*
                //If connection to Redis successful then pass in the password
                else {
                    
                    let password = "pf60fdc52fbcdbef653d7936622dd3b332fec2da875a2e928a2bdd8d15eb7edb0"
                    redis.auth(password) { (pwdError: NSError?) in
                        if let errorPwd = pwdError {
                            print(errorPwd)
                        }
                        else {
                            print("Password Authentication Is Successful")
                        }
                    }
                    
                    print("Established Connection to Redis")
                }
                */
                self.labelConnectedIP.text = "ip: \(self.portIP.text!):\(self.port.text!)"
            }
            
            self.isConnect = true
            sender.setTitle("Disconnect", for: [])
        }
        
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        if self.isConnect {
            
            let transform = SCNMatrix4(frame.camera.transform)
            let orientation = SCNVector3(-transform.m31, -transform.m32, transform.m33)
            let location = SCNVector3(transform.m41, transform.m42, transform.m43)
            //self.labelOrientation.text = "(\(orientation.x), \(orientation.y), \(orientation.z))"
            //self.labelCoordinates.text = "(\(location.x), \(location.y), \(location.z))"
            
            
            var cgImage: CGImage?
            VTCreateCGImageFromCVPixelBuffer(frame.capturedImage, options: .none, imageOut: &cgImage)
            let uiImage = UIImage(cgImage: cgImage!)
            
            let rect = CGRect(x: 0.0, y: 0.0, width: 256, height: 128)
            UIGraphicsBeginImageContext(rect.size)
            uiImage.draw(in: rect)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            let imageData = image!.jpegData(compressionQuality: 0.25)!.base64EncodedString()
            UIGraphicsEndImageContext()
            
            //self.socket.emit("data", "{\"data\": {\"position\": {\"x\": \(location.x), \"y\": 0, \"z\": \(location.z)}, \"img\": \"\(imageData)\"}}")
            
            if self.bufferCounter < self.bufferSize {
                self.pushData.append("{\"data\": {\"position\": {\"x\": \(location.x), \"y\": 0, \"z\": \(location.z)}, \"img\": \"\(imageData)\"}}")
                self.bufferCounter = self.bufferCounter + 1
            } else {
                redis.rpush("vroomba", values: self.pushData[0], self.pushData[1], self.pushData[2], callback: { (result, message) in
                    //print("\(result) : \(message)")
                })
                self.bufferCounter = 0
                self.pushData.removeAll()
            }
        }
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        print("CONNECTING NEW PORT: " + self.portIP.text! + ":" + self.port.text!)
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
