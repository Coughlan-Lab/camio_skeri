//
//  AudioRecorder.swift
//  CamIo3rd
//
//  Created by Huiying Shen on 7/3/19.
//  Copyright © 2019 Huiying Shen. All rights reserved.
//

import AVFoundation

class AudioRecorder: NSObject,AVAudioRecorderDelegate{
    
    var audioRecorder: AVAudioRecorder!
    var success = false
    
    func startRecording(_ fn: String){
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = dir.appendingPathComponent(fn) as URL
            startRecordingUrl(url)
        }
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        success = flag
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Error while recording audio \(error!.localizedDescription)")
    }
    func startRecordingUrl(_ url: URL) {
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder.record()
        }
        catch {
            print("error startRecordingUrl()")
        }
    }
    
    func stop(){
        audioRecorder.stop()
    }
}
