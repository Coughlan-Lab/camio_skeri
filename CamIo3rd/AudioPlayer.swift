//
//  AudioPlayer.swift
//  CamIo3rd
//
//  Created by Huiying Shen on 3/21/19.
//  Copyright © 2019 Huiying Shen. All rights reserved.
//

import UIKit
import AVFoundation


enum BgSound{
    case cricket
    case single
    case double
    case none
}

class AudioPlayer: NSObject,AVAudioPlayerDelegate {
    var player = AVAudioPlayer()
    var sound = BgSound.none
    var sleep_us:useconds_t = 2000000
    var breakLoop = false
    var finished = true
    
    override init() {
        super.init()
        player = AVAudioPlayer()
        sound = BgSound.none
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        finished = true
    }
    func startLoop(){
        DispatchQueue.global(qos: .background).async {
            var sound_old = BgSound.none
            self.sleep_us = 1000*100
            while true{
                if self.sound==sound_old && self.finished==false{
                    usleep(self.sleep_us)
                    continue
                }
                self.stop()
                self.finished = false
                switch self.sound{
                case .cricket:
                    usleep(self.sleep_us)
                    self.play("cricket3.mp3", vol: 0.05)
                case .single:
                    usleep(self.sleep_us)
                    self.play("single click.mp3", vol: 0.05)
                case .double:
                    usleep(self.sleep_us)
                    self.play("double click.mp3", vol: 0.1)
                case .none:
                    usleep(self.sleep_us)
                }
                if self.breakLoop { break }
                sound_old = self.sound
            }
        }
    }
    func playSingle(){
        if (sound == .single) {return}
        stop()
        playOneClick()
    }
    
    func playDouble(){
        if (sound == .double) {return}
        stop()
        playDoubleClick()
    }
    func playCricket(){
        play("cricket3.mp3", vol: 0.05)
        sound = .single
    }
    func playOneClick(){
        play("single click.mp3", vol: 0.05)
        sound = .single
    }
    func playDoubleClick(){
        play("double click.mp3", vol: 0.1)
        sound = .double
    }
    
    func playUrl(_ url: URL, vol: Float){
        do {
            self.player = try AVAudioPlayer(contentsOf: url)
            self.player.setVolume(vol, fadeDuration: 0.5)
            self.player.numberOfLoops = -1
            self.player.play()
        } catch {// couldn't load file :(
        }
    }
    
    func playRecording(_ fn: String, vol: Float){
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = dir.appendingPathComponent(fn) as URL
            playUrl(url,vol:vol)
        }
    }
    
    func play(_ fn: String, vol: Float){
        let url = URL(fileURLWithPath: Bundle.main.path(forResource: fn, ofType:nil)!)
        playUrl(url,vol:vol)
    }
    
    func stop(){
        if (player.isPlaying){
            player.stop()            
        }
        sound = .none
    }
    
    func test(){
        playOneClick()
        usleep(5000000)
        stop()
        usleep(5000000)
        playDoubleClick()
        usleep(5000000)
        stop()
    }
}

