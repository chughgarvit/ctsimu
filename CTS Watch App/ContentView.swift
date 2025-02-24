//
//  ContentView.swift
//  CTS Watch App
//
//  Created by Garvit on 24/02/25.
//

import SwiftUI
import CoreMotion
import WatchConnectivity

/// Manages IMU (motion) updates and sends data to the iPhone.
class MotionManager: NSObject, ObservableObject, WCSessionDelegate {
    private var motionManager = CMMotionManager()
    private var session: WCSession?
    
    // Published values so the UI can display them (if desired)
    @Published var roll: Double = 0.0
    @Published var pitch: Double = 0.0
    @Published var yaw: Double = 0.0
    
    override init() {
        super.init()
        // Set up Watch Connectivity if available.
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
        startUpdates()
    }
    
    /// Starts capturing device motion and sends the complete IMU data to the iPhone.
    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device Motion is not available.")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0  // 50 Hz sampling rate
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self, let motionData = data else { return }
            
            // Update published properties for display
            let attitude = motionData.attitude
            self.roll = attitude.roll
            self.pitch = attitude.pitch
            self.yaw = attitude.yaw
            
            // Prepare a dictionary with complete IMU data:
            let imuData: [String: Any] = [
                "attitude": [
                    "roll": attitude.roll,
                    "pitch": attitude.pitch,
                    "yaw": attitude.yaw
                ],
                "rotationRate": [
                    "x": motionData.rotationRate.x,
                    "y": motionData.rotationRate.y,
                    "z": motionData.rotationRate.z
                ],
                "gravity": [
                    "x": motionData.gravity.x,
                    "y": motionData.gravity.y,
                    "z": motionData.gravity.z
                ],
                "userAcceleration": [
                    "x": motionData.userAcceleration.x,
                    "y": motionData.userAcceleration.y,
                    "z": motionData.userAcceleration.z
                ]
            ]
            
            // Send the data to the iPhone
            self.session?.sendMessage(imuData, replyHandler: nil, errorHandler: { error in
                print("Error sending IMU data: \(error.localizedDescription)")
            })
        }
    }
    
    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
    
    // MARK: - WCSessionDelegate methods
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("Watch WCSession activated with state: \(activationState.rawValue)")
    }
    
    #if os(watchOS)
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("Watch WCSession reachability changed: \(session.isReachable)")
    }
    #endif
}

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Sending IMU Data to iPhone")
                .font(.headline)
            Text("Roll: \(motionManager.roll, specifier: "%.2f")")
            Text("Pitch: \(motionManager.pitch, specifier: "%.2f")")
            Text("Yaw: \(motionManager.yaw, specifier: "%.2f")")
        }
        .padding()
        .onAppear {
            motionManager.startUpdates()
        }
        .onDisappear {
            motionManager.stopUpdates()
        }
    }
}

#Preview {
    ContentView()
}
