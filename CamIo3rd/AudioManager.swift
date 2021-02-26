//
//  AudioMnanger.swift
//  CamIo3rd
//
//  Created by Huiying Shen on 7/30/19.
//  Copyright © 2019 Huiying Shen. All rights reserved.
//

import AVFoundation



class AudioManager: NSObject, AVAudioRecorderDelegate,AVAudioPlayerDelegate,AVSpeechSynthesizerDelegate {
    
    var audioSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer!
    let synth = AVSpeechSynthesizer()
    
    let engine = AVAudioEngine()
    var playerH = AVAudioPlayerNode()
    var playerV = AVAudioPlayerNode()
    
    var bufLeft:AVAudioPCMBuffer!
    var bufRight:AVAudioPCMBuffer!
    var bufForward:AVAudioPCMBuffer!
    var bufBack:AVAudioPCMBuffer!
    var bufUp:AVAudioPCMBuffer!
    var bufDown:AVAudioPCMBuffer!
    
    var bufLow:AVAudioPCMBuffer!
//    var bufMid:AVAudioPCMBuffer!
    var bufHigh:AVAudioPCMBuffer!
    
    var hasPermission = false
    
    override init() {
        super.init()
        synth.delegate = self
        getMicPermission()
        
        playerH.volume = 0.5
        playerV.volume = 0.25
        engine.attach(playerH)
        engine.attach(playerV)
        loadBuffers()
        playBuf(player:playerH, buf: bufLeft) // needed to prepare engine
        playBuf(player:playerV, buf: bufLow)  // ditto
        engine.prepare()
        try! engine.start()
//        playBuf2(player:playerV, buf1: bufLow, buf2: bufHigh)
//        playHV()
        
    }
    
    func loadBuffers(){
        bufLeft = file2Buf("left", suff:"mp3")
        bufRight = file2Buf("right", suff:"mp3")
        bufForward = file2Buf("forward", suff:"mp3")
        bufBack = file2Buf("back", suff:"mp3")
        bufUp = file2Buf("up", suff:"mp3")
        bufDown = file2Buf("down", suff:"mp3")
        
        bufLow = prepareBuffer(frequency: 440,timeSec: 0.1)
        bufHigh = prepareBuffer(frequency: 440*1.25,timeSec: 0.1)
    }
    var nPlay = 0
    func complete(){
        print("done playing")
        nPlay += 1
    }
    
    func playBuf(player: AVAudioPlayerNode, buf: AVAudioPCMBuffer,completionHandler: AVAudioNodeCompletionHandler? = nil){
        print("in playBuf()")
        engine.connect(player,  to: engine.mainMixerNode, format: buf.format)
        player.scheduleBuffer(buf, at: nil, options: AVAudioPlayerNodeBufferOptions.interruptsAtLoop, completionHandler: completionHandler)
    }
    

    func stopHV(){
        playerH.stop()
        playerV.stop()
    }
    
    func file2Buf(_ fn: String, suff: String) -> AVAudioPCMBuffer{
        let path = Bundle.main.path(forResource: fn, ofType: suff)!
        let url = NSURL.fileURL(withPath: path)
        let file = try? AVAudioFile(forReading: url)
        let buffer = AVAudioPCMBuffer(pcmFormat: file!.processingFormat, frameCapacity: AVAudioFrameCount(file!.length))
        try! file!.read(into: buffer!)
        return buffer!
    }
    
    func getMicPermission(){
        audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            //try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
            try audioSession.setActive(true)
            audioSession.requestRecordPermission { [unowned self] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        self.hasPermission = true
                    } else {
                        // failed to record
                    }
                }
            }
        } catch {// failed to record!
        }
    }
    func isRecording() ->Bool {
        return audioRecorder?.isRecording ?? false
    }
    
    class StateTime{
        var iState0 = -1
        var t = Int64(Date().timeIntervalSince1970 * 1000)
        func dt(iState: Int){
            if iState == 0{
                if iState0 != 0 {
                    t = Int64(Date().timeIntervalSince1970 * 1000)
                    iState0 = 0
                }
            }
            else{
                
            }
        }
    }
    
    func currentTimeInMilliSeconds() -> Int64
    {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    func isRightRecStage() -> Bool{
        switch recStage {
        case .instruction, .beep, .recording:
            return true
        default:
            return false
        }
    }
//    func cancelRecordingIfRightStages(){
////        print("cancelRecordingIfRightStages(), recStage = \(recStage)")
//        if isRightRecStage(){
//            cancelRecording()
//        }
//    }

    var iStateOld:Int32 = 0
    var t4RecStage = Date().timeIntervalSince1970 * 1000
    
    var isPlayingFile = ""
//    var guidingBeepSound = true
    
    func processState(iState:Int32, stylusString: String, audioGuidance: Bool = true){
        if iState != 5 {isBeeping = false}
        switch iState{
        case 0:  // no board visible
            if iState != iStateOld {
                t4RecStage = Date().timeIntervalSince1970 * 1000
            }
            let dt = Date().timeIntervalSince1970 * 1000 - t4RecStage
            if dt > 1000 && isRightRecStage(){
//                print("processState(), dt = \(dt)")
                cancelRecording()
            }
            else if noAudio()  {playCrickets()}
        case 1:  // board visible , but no stylus
            if  recStage == .recording {
                audioRecorder?.stop()
                audioRecorder = nil
            }
            else if recStage == .saved2cpp{
                if audioPlayer != nil {audioPlayer.stop()}
                if synth.isSpeaking{synth.stopSpeaking(at: .immediate)}
            }
        case 3:  // writing stylus visible, but not stable, yet
            if noAudio() {playDoubleClick()}
        case 2:  // writing stylus stable: start recording or continue recording
            if recStage == .saved2cpp &&  stylusString.count > 0 && newRegionXyz.count == 0{
                print("stylusString = " + stylusString + ", newRegionXyz.count = ", newRegionXyz.count)
                newRegionXyz = stylusString
                recording_fn = newRegionXyz + ".m4a"
                recordingStartingStep()
            }
        case 5:  // in the process to find the hotspot
            if audioGuidance {
                //print("case 5")
                if noAudio()   {
                    let dist_dz = stylusString.components(separatedBy: "_")
                    let dist = dist_dz[0].toFloat(default: 1.01)
                    if dist>1.0 {return} // no hotspot
                    let dx = dist_dz[1].toFloat(default: 1.01)
                    let dy = dist_dz[2].toFloat(default: 1.01)
                    let dz = dist_dz[3].toFloat(default: 1.01)
                    print("case 5, dist = ", dist)
                   
                    if dist > 1 && dz > 1 { speak("no hotspot") }  // no hotspot
                    else { playGuidance(dx:dx, dy:dy, dz:dz) }
                }
            }
            else {playSingleClick()}
        case 4:  // hotspot found, playing its recording
            print("case 4, stylusString = " + stylusString)
            
            if stylusString.contains("recording"){
                // stylusString ~  "0.0483_0.103_0.0805, --------, recording"
                // or, stylusString ~  "0.0483_0.103_0.0805:some_text, --------, recording"
                let vs = stylusString.components(separatedBy: ",")
                let tmp = vs[0].components(separatedBy: "?")
                recording_fn = tmp[0] + ".m4a"
                if noAudio() || isPlayingFile != recording_fn {
                    startPlayback()
                    print("playing " + recording_fn)
                    isPlayingFile = recording_fn
                }
            }
            else {
                if Float(stylusString) != nil {return}
                speak(stylusString)
                print("case 4, speak(stylusString)")
            }

        default:
            print("processState(), should not be here")
        }
        if iState != 5 {oneClickOn = false}
        iStateOld = iState
    }
    
    func noAudio() -> Bool {
        if audioPlayer != nil && audioPlayer.isPlaying{return false}
        if synth.isSpeaking {return false}
        if recStage != .saved2cpp {return false}
        return true
    }
    
    var recording_fn = "recording.m4a"
    func startRecording() -> Bool {
                print("startRecording(), recStage:0 = \(recStage)")
        let audioFilename = getDocumentsDirectory().appendingPathComponent(recording_fn)
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22050,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        var started = true
                print("startRecording(), recStage:1 = \(recStage)")
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder!.delegate = self
            audioRecorder!.record()
            print("startRecording(), recStage:2 = \(recStage)")
            
        } catch {
            started = false
        }
        print("startRecording(), recStage:3 = \(recStage)")
        return started
    }
     
    var cancelRec = false
    func cancelRecording(){
        print("canceling recording...")
        cancelRec = true
        newRegionXyz = ""
        recStage = .saved2cpp
        
        if audioPlayer != nil {audioPlayer.stop()}
        synth.stopSpeaking(at: .immediate)
        if audioRecorder != nil {
            audioRecorder!.stop()
            audioRecorder = nil
        }
    }
    
    func startPlayback() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent(recording_fn)
        playUrl(audioFilename, vol: 1.0, nLoop:0)
    }
    
    func playUrl(_ url: URL, vol: Float, nLoop: Int = -1){
        if  preparePlayer(url,vol:vol,nLoop:nLoop) { audioPlayer.play()}
    }
    
    func preparePlayer(_ url: URL, vol: Float, nLoop: Int = -1) -> Bool {
        do {audioPlayer = try AVAudioPlayer(contentsOf: url)}
        catch { return false }
        audioPlayer.delegate = self
        audioPlayer.setVolume(vol, fadeDuration: 0.5)
        audioPlayer.enableRate = true
        audioPlayer.numberOfLoops = nLoop
        return true
    }
    
    func playResourceFile(_ fn: String, vol: Float,nLoop: Int = 5){
        let url = URL(fileURLWithPath: Bundle.main.path(forResource: fn, ofType:nil)!)
        playUrl(url,vol:vol,nLoop:nLoop)
    }
    
    func stopPlaying(){
        playSilence()  // silence audioPlayer instantly
        if audioPlayer != nil {audioPlayer.stop()}
    }

    var isBeeping = false
    func playGuidance(dx:Float, dy:Float, dz:Float){
        if nPlay != 0 {return}
        if abs(dx) > abs(dy) && abs(dx) > abs(dz){
            if dx > 0{playBuf(player:playerH, buf: bufLeft,completionHandler:complete)}
            else { playBuf(player:playerH, buf: bufRight,completionHandler:complete)}
        } else if abs(dy) > abs(dx) && abs(dy) > abs(dz){
            if dy>0 {playBuf(player:playerH, buf: bufBack,completionHandler:complete)}
            else{playBuf(player:playerH, buf: bufForward,completionHandler:complete)}
        } else {
            if dz>0 {playBuf(player:playerH, buf: bufDown,completionHandler:complete)}
            else {playBuf(player:playerH, buf: bufUp,completionHandler:complete)}
        }
        if !engine.isRunning {try! engine.start()}
        playerH.play()
        nPlay = -1
    }

    func playLowHigh(){
        playBuf(player:playerV, buf: bufLow)
        if !engine.isRunning {try! engine.start()}
        playerV.play()
        usleep(200_000)
        playBuf(player:playerV, buf: bufHigh)
        playerV.play()
    }
    
    func playHighLow(){
        playBuf(player:playerV, buf: bufHigh)
        if !engine.isRunning {try! engine.start()}
        playerV.play()
        usleep(200_000)
        playBuf(player:playerV, buf: bufLow)
       playerV.play()
    }
  
    func getGuidance(dx:Float, dy:Float, dz:Float) -> (String,String ){
         var xy: String

         if abs(dx) > abs(dy){
             if dx > 0 {xy = "left"}
             else {xy = "right"}
         }
         else {
             if dy > 0 {xy = "back"}
             else {xy = "forward"}
         }
         var z:String
         switch dz{ // in meters
             case -1.0 ..< -0.01:
                 z = "low"
         case 0.01 ..< 1.0:
             z = "high"
         default:
             z = "mid"
         }
         print("playGuidance(): ", xy, ", ", z)
         return (xy,z)
     }
    
    
    func playBeep0(){
        playResourceFile("censor-beep-01.mp3",vol:0.25,nLoop: 1)
    }
    
    var oneClickOn = false
    func playSingleClick(){
        if !self.oneClickOn {
            self.oneClickOn = true
            Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { timer in
                self.playResourceFile("single click.mp3",vol:0.25,nLoop: 0)
                if !self.oneClickOn { timer.invalidate() }
            }
        }
    }
    
    func stopOneClick(){
        oneClickOn = false
    }
    
    func playDoubleClick(){
        playResourceFile("double click.mp3",vol:0.25,nLoop: 1)
    }
    
    func playCrickets(){
        playResourceFile("crickets3.mp3",vol:0.25,nLoop: 0)
    }
    func playSilence(){
        playResourceFile("silence.wav",vol:0.1,nLoop:0)
    }
    
    var _str = ""
    var _timestamp = Date().currentTimeMillis()
    func speak(_ str: String){
        let dt = Date().currentTimeMillis() - _timestamp
        print ("dt = ", dt)
        if  synth.isSpeaking {return}
        if str == _str && Date().currentTimeMillis() - _timestamp < 500 {return}  // otherwise, str will be in the que and be spoken later
        _str = str
        _timestamp = Date().currentTimeMillis()
        synth.speak(AVSpeechUtterance(string: str))
    }
    
    var recStage = RecordingStages.saved2cpp
    var newRegionXyz = ""
      
    func recordingStartingStep(){
        if audioPlayer != nil {audioPlayer.stop()}
        cancelRec = false
        recStage = .instruction
        speak("start recording after the beep")  //recording step 1
    }
    
    func trySaveRegion2cpp(_ viewController: ViewController)  -> Bool{
        var saved = false
        if recStage == .done{
            print("trySaveRegion2cpp(), newRegionXyz = \(newRegionXyz)")
            if  newRegionXyz.count != 0{ viewController.addNewRegion(newRegionXyz); saved = true}
            newRegionXyz = ""
            recStage = .saved2cpp
        }
        return saved
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance){
        if cancelRec {return}
        if recStage == .instruction {
            recStage = .beep
            playBeep0()  // recording step 2
        }
        
        if recStage == .finish_notification {
            recStage = .playback // recording step done
            startPlayback()
        }
        
        if isBeeping {isBeeping = false}
    }
    var tRecStart = Date().timeIntervalSince1970 * 1000
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if cancelRec {return}
        if recStage == .beep {
            recStage = .recording
            let started = startRecording()  // recording step 3
            if started {
                tRecStart = Date().timeIntervalSince1970 * 1000
            }
        }
        
        if recStage == .playback{
            recStage = .done
        }
        
        if isBeeping {isBeeping = false}
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if cancelRec {return}
        print("audioRecorderDidFinishRecording(), recStage = \(recStage)")
        if recStage == .recording  && flag {
            let dt = Date().timeIntervalSince1970 * 1000 - tRecStart
            print("recording length = \(dt)")
            if dt < 200 {
                print("Recording is too short, and is discarded")
                cancelRecording()
            }
            else{
                recStage = .finish_notification
                speak("recording is finished, playback to verify")  // recording step 4
            }
        }
    }
}

func prepareBuffer(frequency: Double, timeSec: Double, sampleRate: Double = 22_100.0, volume: Double = 0.5) -> AVAudioPCMBuffer {
    
    let bufferCapacity: AVAudioFrameCount = AVAudioFrameCount(Int(timeSec*sampleRate))
    
    let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
    let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat!, frameCapacity: bufferCapacity)!
    
    let data = buffer.floatChannelData?[0]
    let numberFrames = buffer.frameCapacity
    
    for t in 0..<Int(numberFrames) {
        data?[t] = Float32(volume*sin(2.0 * .pi * frequency / sampleRate*Double(t)))
    }
    
    buffer.frameLength = numberFrames
    
    return buffer
}


enum RecordingStages{
    case instruction
    case beep
    case recording
    case finish_notification
    case playback
    case done
    case saved2cpp
}

extension Date {
    func currentTimeMillis() -> Int64 {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
}

extension String{
    func toFloat(default val:Float) -> Float{
        if Float(self) == nil {return val}
        return Float(self)!
    }
}
