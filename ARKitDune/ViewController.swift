import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    let configuration = ARWorldTrackingConfiguration()
    let light = SCNLight()
    var longestDuration: CFTimeInterval = 0.0
    var timer: Timer!
    
    var hangarNode: SCNNode!
    var spaceshipNode: SCNNode!
    var doorLeftNode: SCNNode!
    var doorRightNode: SCNNode!
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var reset: UIButton!
    
    @IBOutlet weak var resetStackView: UIStackView!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var resetLabel: UILabel!
    
    @IBOutlet weak var restartStackView: UIStackView!
    @IBOutlet weak var restartButton: UIButton!
    @IBOutlet weak var restartLabel: UILabel!
    
    var session: ARSession {
        return sceneView.session
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        DispatchQueue.main.async {
            self.resetStackView.isHidden = true
            
            self.hideRestartAnimationButton()
            
            self.createMessage(message: "Initialising AR session. Please wait...", color: .white)
            
            self.setupScene()
            self.setupLights()
            self.setupConfig()
        }
        
        UIApplication.shared.isIdleTimerDisabled = true
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // Mark: Setup the configuration settings
    
    func setupConfig() {
        configuration.planeDetection = .horizontal
        configuration.isLightEstimationEnabled = true
        session.run(configuration)
    }
    
    // Mark: Setup the scene
    
    func setupScene() {
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        sceneView.antialiasingMode = .multisampling4X
        
        sceneView.autoenablesDefaultLighting = false
        sceneView.automaticallyUpdatesLighting = false
        
        DispatchQueue.main.async {
            let hangarScene = SCNScene(named: "art.scnassets/Hangar.scn")!
            self.hangarNode = hangarScene.rootNode.childNode(withName: "Hangar", recursively: true)
            
            self.spaceshipNode = self.hangarNode.childNode(withName: "Spaceship", recursively: true)!
            
            self.doorLeftNode = hangarScene.rootNode.childNode(withName: "DoorLeft", recursively: true)!
            self.doorRightNode = hangarScene.rootNode.childNode(withName: "DoorRight", recursively: true)!
            
            self.animationDuration()
        }
    }
    
    // Mark: Setup the lightings
    
    func setupLights() {
        light.type = .directional
        light.color = UIColor.white
        light.castsShadow = true
        light.shadowMode = .deferred
        light.shadowColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5)
        
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.eulerAngles = SCNVector3Make(-45, 0, 0)
        lightNode.position = SCNVector3Make(0, 0, 1)
        
        self.sceneView.scene.rootNode.addChildNode(lightNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let estimate = session.currentFrame?.lightEstimate
        
        if estimate == nil {
            return
        }
        
        let intensity = estimate!.ambientIntensity
        light.intensity = intensity
        sceneView.scene.lightingEnvironment.intensity = intensity
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else  { return }
        
        DispatchQueue.main.async {
            // MARK: Floor
            
            let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x * 5), height: CGFloat(planeAnchor.extent.z * 5))
            plane.firstMaterial?.colorBufferWriteMask = SCNColorMask(rawValue: 0)
            plane.firstMaterial?.lightingModel = .physicallyBased
            
            let planeNode = SCNNode(geometry: plane)
            planeNode.name = "planeAnchor"
            planeNode.simdPosition = SIMD3(planeAnchor.center.x, 0, planeAnchor.center.z)
            planeNode.eulerAngles.x = -.pi / 2
            
            node.addChildNode(planeNode)
            
            // MARK: Hangar
            
            self.hangarNode?.simdPosition = SIMD3(planeAnchor.center.x, 0, planeAnchor.center.z)
            
            node.addChildNode(self.hangarNode!)
            
            self.setAnimationTimer()
            
            // MARK: Disable Plane Detection after object is being added
            
            self.configuration.planeDetection = []
            self.session.run(self.configuration)
        }
    }
    
    // Mark: ARSessionDelegate
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        showMessage(for: frame, trackingState: frame.camera.trackingState)
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        showMessage(for: frame, trackingState: frame.camera.trackingState)
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        showMessage(for: session.currentFrame!, trackingState: camera.trackingState)
    }
    
    //    func sessionInterruptionEnded(_ session: ARSession) {
    //        let alert = UIAlertController(title: "Session Interrupted", message: "Session interruption ended. Press OK to restart the session", preferredStyle: .alert)
    //
    //        let ok = UIAlertAction(title: "OK", style: .default) { _ in
    //            self.resetTracking()
    //        }
    //
    //        alert.addAction(ok)
    //
    //        present(alert, animated: true, completion: nil)
    //    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        createMessage(message: "An error occurred while trying to setup an AR session.\nError: \(error.localizedDescription)", color: .red)
        resetTracking()
    }
    
    func showMessage(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        self.resetStackView.isHidden = false
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty:
            self.resetStackView.isHidden = true
            
            createMessage(message: "Tracking Surface - Move the device around to detect horizontal surfaces.", color: .yellow)
            
        case .normal:
            createMessage(message: "", color: .green)
            
        case .limited(.initializing):
            self.resetStackView.isHidden = true
            
            createMessage(message: "Calibrating - Move your camera around to calibrate.", color: .blue)
            
        case .notAvailable:
            self.resetStackView.isHidden = false
            
            createMessage(message: "Camera tracking is not available.", color: .red)
            
        case .limited(.excessiveMotion):
            self.resetStackView.isHidden = false
            
            createMessage(message: "Tracking Limited - Move the device more slowly.", color: .red)
            
        case .limited(.insufficientFeatures):
            self.resetStackView.isHidden = false
            
            createMessage(message: "Tracking Limited - Point the device at an area with more visible surface details or improved lighting conditions.", color: .red)
            
        case .limited(.relocalizing):
            createMessage(message: "Relocalising", color: .green)
        case .limited(_):
            createMessage(message: "Relocalising"
                          , color: .green)
        }
    }
    
    func createMessage(message: String, color: UIColor) {
        if message.isEmpty {
            messageLabel.isHidden = true
        } else {
            messageLabel.isHidden = false
        }
        
        messageLabel.text = message
        messageLabel.textColor = color
        
    }
    
    func resetTracking() {
        DispatchQueue.main.async {
            //            self.timer.invalidate()
            self.hideRestartAnimationButton()
            self.createMessage(message: "Tracking reset.", color: .red)
            self.configuration.planeDetection = .horizontal
            self.session.run(self.configuration, options: [.resetTracking, .removeExistingAnchors])
        }
    }
    
    func animationDuration() {
        let doorLeftAnimationKey = doorLeftNode.animationKeys.first!
        let doorLeftAnimation = doorLeftNode.animationPlayer(forKey: doorLeftAnimationKey)
        let animationDuration = CAAnimation(scnAnimation: doorLeftAnimation!.animation).duration
        
        self.longestDuration = animationDuration
    }
    
    func setAnimationTimer() {
        self.timer = Timer.scheduledTimer(timeInterval: self.longestDuration, target: self, selector: #selector(self.showRestartAnimationButton), userInfo: nil, repeats: false)
    }
    
    func hideRestartAnimationButton() {
        self.restartStackView.isHidden = true
    }
    
    @objc func showRestartAnimationButton() {
        self.restartStackView.isHidden = false
    }
    
    func resetAnimation() {
        let spaceshipAnimationKey = spaceshipNode.animationKeys.first!
        let spaceshipAnimation = spaceshipNode.animationPlayer(forKey: spaceshipAnimationKey)
        spaceshipAnimation?.play()
        
        let doorLeftAnimationKey = self.doorLeftNode.animationKeys.first!
        let doorRightAnimationKey = self.doorRightNode.animationKeys.first!
        
        let doorLeftAnimation = doorLeftNode.animationPlayer(forKey: doorLeftAnimationKey)
        let doorRightAnimation = doorRightNode.animationPlayer(forKey: doorRightAnimationKey)
        
        doorLeftAnimation?.play()
        doorRightAnimation?.play()
    }
    
    @IBAction func reset(_ sender: Any) {
        DispatchQueue.main.async {
            self.resetTracking()
        }
    }
    
    @IBAction func restart(_ sender: Any) {
        DispatchQueue.main.async {
            self.hideRestartAnimationButton()
            self.resetAnimation()
            self.setAnimationTimer()
        }
    }
}
