import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    let configuration = ARWorldTrackingConfiguration()
    var hangarNode : SCNNode!
    var animation : CAAnimation?
    var longestDuration : Double? = 0
    let light = SCNLight()
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var debugSwitch: UISwitch!
    
    var session : ARSession {
        return sceneView.session
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupScene()
        
        self.configuration.planeDetection = .horizontal
        self.configuration.isLightEstimationEnabled = true
        session.run(self.configuration)
        
        sceneView.debugOptions = ARSCNDebugOptions.showFeaturePoints
        
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func setupScene() {
        sceneView.delegate = self
        
        sceneView.session = session
        
        sceneView.antialiasingMode = .multisampling4X
        
        sceneView.autoenablesDefaultLighting = false
        sceneView.automaticallyUpdatesLighting = false
        
        let scene = SCNScene()
        sceneView.scene = scene
        
        DispatchQueue.main.async {
            let hangarScene = SCNScene(named: "art.scnassets/hangar.scn")!
            self.hangarNode = hangarScene.rootNode.childNode(withName: "hangar", recursively: true)
        }
    }
    
    @IBAction func toggleDebug(_ sender: Any) {
        if debugSwitch.isOn {
            sceneView.debugOptions = ARSCNDebugOptions.showFeaturePoints
        } else {
            sceneView.debugOptions = []
        }
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
            self.light.type = .directional
            self.light.color = UIColor.white
            self.light.castsShadow = true
            
            let lightNode = SCNNode()
            lightNode.light = self.light
            lightNode.eulerAngles = SCNVector3Make(-45, 0, 0)
            lightNode.position = SCNVector3Make(0, 0, 1)
            
            self.sceneView.scene.rootNode.addChildNode(lightNode)
            
            // MARK: Floor
            
            let floor = UIImage(named: "art.scnassets/floor.png")!
            
            let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
            plane.firstMaterial?.diffuse.contents = floor
            plane.firstMaterial?.lightingModel = .physicallyBased
            
            let planeNode = SCNNode(geometry: plane)
            planeNode.name = "planeAnchor"
            planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
            planeNode.eulerAngles.x = -.pi / 2
            
            node.addChildNode(planeNode)
            
            // MARK: Hangar
            
            self.hangarNode?.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
            
            node.addChildNode(self.hangarNode!)
            
            // MARK: Disable Plane Detection after object is being added
            
            self.configuration.planeDetection = []
            self.session.run(self.configuration)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let planeNode = node.childNode(withName: "planeAnchor", recursively: true),
            let plane = planeNode.geometry as? SCNPlane
            else { return }
        
        planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        plane.width = CGFloat(planeAnchor.extent.x)
        plane.height = CGFloat(planeAnchor.extent.z)
    }
}