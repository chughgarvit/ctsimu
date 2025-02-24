//
//  ContentView.swift
//  CTS
//
//  Created by Garvit on 24/02/25.
//

import SwiftUI
import SceneKit
import WatchConnectivity

/// Observable object to receive IMU data from the Apple Watch.
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
    
    /// Called when the Apple Watch sends a message with IMU data.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            if let attitude = message["attitude"] as? [String: Double] {
                self.roll = attitude["roll"] ?? 0.0
                self.pitch = attitude["pitch"] ?? 0.0
                self.yaw = attitude["yaw"] ?? 0.0
            }
        }
    }
    
    // MARK: - WCSessionDelegate Stubs
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("WCSession activated with state: \(activationState.rawValue)")
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
    #endif
}

/// Main SwiftUI view to display and control the SceneKit scene.
struct ContentView: View {
    @StateObject private var imuReceiver = IMUDataReceiver()
    @State private var scene: SCNScene = SCNScene()
    @State private var handNode: SCNNode?
    
    // Previous values for smoothing
    @State private var previousRoll: Double = 0.0
    @State private var previousPitch: Double = 0.0
    @State private var previousYaw: Double = 0.0
    
    var body: some View {
        ZStack {
            // SceneKit view to display the hand model.
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
            
            // Optional debug overlay to display raw IMU data.
            VStack {
                Text("Roll: \(imuReceiver.roll)")
                Text("Pitch: \(imuReceiver.pitch)")
                Text("Yaw: \(imuReceiver.yaw)")
            }
            .background(Color.black.opacity(0.5))
            .foregroundColor(.white)
            .padding()
        }
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
        
        // Apply smoothing using a low-pass filter.
        let alpha = 0.1 // Smoothing factor (adjust as needed).
        let smoothedRoll = lowPassFilter(current: imuReceiver.roll, previous: previousRoll, alpha: alpha)
        let smoothedPitch = lowPassFilter(current: imuReceiver.pitch, previous: previousPitch, alpha: alpha)
        let smoothedYaw = lowPassFilter(current: imuReceiver.yaw, previous: previousYaw, alpha: alpha)
        
        // Adjust for SceneKit's coordinate system (if needed).
        handNode.eulerAngles = SCNVector3(smoothedPitch, -smoothedYaw, smoothedRoll)
        
        // Update previous values for smoothing.
        previousRoll = smoothedRoll
        previousPitch = smoothedPitch
        previousYaw = smoothedYaw
    }
    
    /// Low-pass filter to smooth out rapid changes in IMU data.
    func lowPassFilter(current: Double, previous: Double, alpha: Double) -> Double {
        return alpha * current + (1 - alpha) * previous
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
