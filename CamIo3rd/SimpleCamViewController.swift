//
//  SimpleCamViewController.swift
//  CamIo3rd
//
//  Created by Huiying Shen on 5/6/19.
//  Copyright © 2019 Huiying Shen. All rights reserved.
//

import AVFoundation

class SimpleCamViewController:UIViewController,AVCaptureVideoDataOutputSampleBufferDelegate{
    var isVga = false
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCamera()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        session.startRunning()
    }
    
    lazy var session: AVCaptureSession = {
        let s = AVCaptureSession()
        if isVga{
            s.sessionPreset = .vga640x480
        }else {
            s.sessionPreset = .hd1280x720
        }
        return s
    }()
    
    func setupCamera() {
        let availableCameraDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back)
        var activeDevice: AVCaptureDevice?
        for device in availableCameraDevices.devices as [AVCaptureDevice]{
            if device.position == .back {
                activeDevice = device
                
                break
            }
        }
        //activeDevice?.set(frameRate: frameRate)
        do {
            let camInput = try AVCaptureDeviceInput(device: activeDevice!)
            if session.canAddInput(camInput) {
                session.addInput(camInput)
            }
        } catch {print("no camera") }
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "buffer queue", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil))
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            // enable getting camera intrinsic matrix (and distortion coefficient?) delivery
            //            for c in videoOutput.connections{
            //                if c.isCameraIntrinsicMatrixDeliverySupported{
            //                    c.isCameraIntrinsicMatrixDeliveryEnabled = true
            //                }
            //            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        DispatchQueue.main.async {
            //            let ct0 = CACurrentMediaTime()
            guard let _ = CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
            
        }
    }
}
