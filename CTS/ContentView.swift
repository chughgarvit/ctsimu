//
//  ContentView.swift
//  CTS
//
//  Created by Garvit on 24/02/25.
//

import SwiftUI
import SceneKit
import WatchConnectivity

/// An observable object that receives IMU data from the Apple Watch.
class IMUDataReceiver: NSObject, ObservableObject, WCSessionDelegate {
    @Published var roll: Double = 0.0
    @Published var pitch: Double = 0.0
    @Published var yaw: Double = 0.0
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    // Called when the watch sends a message with IMU data.
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let attitude = message["attitude"] as? [String: Double] {
                self.roll = attitude["roll"] ?? 0.0
                self.pitch = attitude["pitch"] ?? 0.0
                self.yaw = attitude["yaw"] ?? 0.0
            }
            // Optionally, you can also process additional data like rotationRate, gravity, etc.
        }
    }
    
    // MARK: - WCSessionDelegate stubs
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("iOS WCSession activated with state: \(activationState.rawValue)")
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
    #endif
}

struct ContentView: View {
    @StateObject private var imuReceiver = IMUDataReceiver()
    @State private var scene: SCNScene = SCNScene()
    @State private var handNode: SCNNode?
    
    var body: some View {
        SceneView(
            scene: scene,
            pointOfView: nil,
            options: [.autoenablesDefaultLighting, .allowsCameraControl]
        )
        .onAppear {
            setupScene()
        }
        // Update the hand orientation whenever new IMU values are received.
        .onChange(of: imuReceiver.roll) { _ in updateHandOrientation() }
        .onChange(of: imuReceiver.pitch) { _ in updateHandOrientation() }
        .onChange(of: imuReceiver.yaw) { _ in updateHandOrientation() }
    }
    
    /// Loads the SceneKit scene containing your hand model.
    func setupScene() {
        if let loadedScene = SCNScene(named: "HandScene.scn") {
            scene = loadedScene
            handNode = scene.rootNode.childNode(withName: "hand", recursively: true)
        } else {
            // Fallback: Create a simple cube if your hand model isn't available.
            scene = SCNScene()
            let cube = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
            handNode = SCNNode(geometry: cube)
            scene.rootNode.addChildNode(handNode!)
        }
    }
    
    /// Updates the hand node's orientation using the received IMU attitude values.
    func updateHandOrientation() {
        guard let handNode = handNode else { return }
        // Adjust the Euler angles if your model's coordinate system requires it.
        handNode.eulerAngles = SCNVector3(imuReceiver.roll, imuReceiver.pitch, imuReceiver.yaw)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
