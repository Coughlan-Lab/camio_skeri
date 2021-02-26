//
//  ttsSpeaker.swift
//  CamIo3rd
//
//  Created by Huiying Shen on 5/6/19.
//  Copyright © 2019 Huiying Shen. All rights reserved.
//

import AVFoundation


class TtsSpeaker: NSObject,AVSpeechSynthesizerDelegate{
    let synth = AVSpeechSynthesizer()
    var done = true
    
    override init() {
        super.init()
        synth.delegate = self
    }
    private var uttStore: [String: AVSpeechUtterance] = [:]
    var current = CACurrentMediaTime()
    private func addItem(str: String){
        uttStore[str] = AVSpeechUtterance(string: str)
        print("addItyem()")
    }
    
    func speak(_ str: String){
        if (str=="_stop"){
            synth.stopSpeaking(at: .immediate)
            done = true
            return
        }
        if (str=="_away") {return}
        if (!done){return}
        done = false
        prepareAudioSession()
        //        synth.speak(AVSpeechUtterance(string: "..."))
        synth.speak(AVSpeechUtterance(string: str))
        
        //        if let utt = uttStore[str] {
        //            synth.speak(utt)
        //        } else {
        //            addItem(str:str)
        //            synth.speak(uttStore[str]!)
        //        }
    }
    
    private func prepareAudioSession() {
        //        do {
        //            try AVAudioSession.sharedInstance().setCategory(.ambient, with: .mixWithOthers)
        //        } catch {
        //            print(error)
        //        }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print(error)
        }
    }
    
    func stop() {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance){
        print("done speaking")
        done = true
    }
}

