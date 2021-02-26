//
//  ViewController.swift
//  CamIoAgain
//
//  Created by Huiying Shen on 2/14/19.
//  Copyright © 2019 Huiying Shen. All rights reserved.
//

import UIKit
import AVFoundation
import Vision
import Speech

func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}

class Model{
    init(){}
    init(fromFile name:String){
        self.name = name
        
    }
    var name = ""
    var description = ""
}

enum UI_State{
    case lib
    case modelList
    case model
    case hotspotList
}

public enum App_State {
   case active
   case inactive
   case background
}
//enum TableViewState{
//    case lib
//    case model
//    case none
//}

/*
 **************************************************************************************************************************************
 *
 class ViewController
 
 */
class ViewController: CameraCalibViewController, UITableViewDataSource, UITableViewDelegate,SFSpeechRecognizerDelegate, SFSpeechRecognitionTaskDelegate{
    
//}, UIContextMenuInteractionDelegate  {
//    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
//        <#code#>
//    }
    
    
    let modelListFn =  "modelList.txt"
    var modelList = [String]()
    var hotspotList = [String]()
    var modelAndData = [String:String]()
    
    var _modelName = ""
    var curModel = Model()
    var audioGuidance = true
    
    let urlStr = "http://34.211.90.21:8000/"
    private let context = CIContext()
    
    func doSpeechRecognition(_ fileURL: URL){
        let speechRecognizer = SFSpeechRecognizer()
      
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        speechRecognizer?.supportsOnDeviceRecognition = true
        speechRecognizer?.recognitionTask(
            with: request,
            resultHandler: { (result, error) in
                if let _ = error {
                    self.speak_local("transcription not successful")
                } else if let result = result {
                    if result.isFinal{
                        let txtFrSpeech = result.bestTranscription.formattedString
                        print("txt = \(txtFrSpeech)")
                        self.saveHotspotTranscription(txtFrSpeech)
                    }
                }
        })
    }
    
    let tableview: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = UIColor.white
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch uiState {
        case .modelList:
            return modelList.count
        case .hotspotList:
            return hotspotList.count
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("get cell")
        print("row: \(indexPath.row)")
        let cell = UITableViewCell(style: UITableViewCell.CellStyle.value1, reuseIdentifier: "Cell")
        switch uiState {
        case .modelList:
            cell.textLabel!.text = modelList[indexPath.row]
        case .hotspotList:
            cell.textLabel!.text = hotspotList[indexPath.row]
        default:
            cell.textLabel!.text = ""
        }
        return cell
    }
    var current:Int = -1
    var _hotspot:String {
        get{
            if current > hotspotList.count - 1 {current = hotspotList.count - 1}
            if current == -1 || hotspotList.count == 0{ return ""}
            return hotspotList[current]
        }
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("selected row: \(indexPath.row)")
        switch uiState {
        case .modelList:
            print("load model \(modelList[indexPath.row])")
            if indexPath.row >= modelList.count {
                print("indexPath.row >= modelList.count")
                return
            }
            loadModelLocal(modelList[indexPath.row])
            if loadHotspotList() == 0{
                speak_local("No hotspot in the model, it is being deleted")
                removeCurrentModelEntry()
                camIoWrapper.clear()
                removeTableview()
                setButtons4lib()
            } else if !audioGuidance {
                removeTableview()
                setButtons4model()
            } else{ showHotpotList() }
        case .hotspotList:
            if indexPath.row >= hotspotList.count {
                print("indexPath.row >= hotspotList.count")
                return
            }
            current = indexPath.row
            setCurrentHotspot()
            removeTableview()
            setButtons4model()
        default:
            return
        }
    }
    
    func setCurrentHotspot(){
        speak_local(hotspotList[current])
        self.camIoWrapper.setCurrent(Int32(current))
    }
    
    func loadHotspotList()  -> Int{
        let rNames = self.camIoWrapper.getRegionNames().components(separatedBy: "\n")
        if rNames.count == 0 {removeTableview(); return 0}
        hotspotList.removeAll()
        var cnt = 0
        for n in rNames{
            let trimmed = n.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count != 0 {
                cnt += 1
                let tmp = trimmed.components(separatedBy: "?")
                if tmp.count == 2{
                    hotspotList.append(tmp[1])
                } else{
                    hotspotList.append(n)
                }
            }
        }
        return hotspotList.count
    }
    
    var n_viewDidLoad_called = 0
    
    override func viewDidLoad() {
        n_viewDidLoad_called += 1
        isVga = false               // isVga = false ---> 720x1280
        super.viewDidLoad()
        print("n_viewDidLoad_called = \(n_viewDidLoad_called)")
        
        loadModelList()
        if n_viewDidLoad_called <= 2 || modelList.count == 0{
            setButtons4lib()
            camIoWrapper.setCameraCalib(loadCamCalib())

            let notificationCenter = NotificationCenter.default
        
            notificationCenter.addObserver(self, selector: #selector(movedToBackgroundOrResignActive), name: UIApplication.didEnterBackgroundNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(movedToBackgroundOrResignActive), name: UIApplication.willResignActiveNotification, object: nil)
//          notificationCenter.addObserver(self, selector: #selector(appCameToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        }
        else{
            setButtons4model()
        }
    }

    @objc func movedToBackgroundOrResignActive() {
        print("move To Background Or ResignActive")
        turnOffCamera()
    }
  
    @objc func didBecomeActive() {
        print("Become Active")
        viewDidLoad()
    }

    override func accessibilityPerformMagicTap() -> Bool{
        print("MagicTap!")
        if uiState == .model {
            if !videoPaused && audioManager.recStage != .saved2cpp {
                turnOffCamera()
                audioManager.playHighLow()
            }
            else {  // non recording
                videoPaused = !videoPaused
                setCamButtonProperties()
                if videoPaused {audioManager.playHighLow()}
                else {audioManager.playLowHigh()}
                if videoPaused {audioManager.stopPlaying()}
            }
        }
        return true
    }
       
    @objc func setupTableView(_ y:CGFloat = 100) {
        loadModelList()
        
        if modelList.count == 0 {removeTableview(); return}
        tableview.register(UITableViewCell.self, forCellReuseIdentifier: "cellId")
        tableview.delegate = self
        tableview.dataSource = self
        tableview.frame = CGRect(x: 0, y: y, width: view.frame.maxX, height: view.frame.maxY)
        view.addSubview(tableview)
        tableview.reloadData()
    }
    
    @objc func removeTableview(){
        tableview.removeFromSuperview()
        videoPaused = false
    }
    
    func loadModelList(){
        modelList.removeAll()
        var dat = self.readFr(modelListFn)
        if dat.count == 0 {return}
        dat = dat.replacingOccurrences(of: "\n\n", with: "\n")
        let sArray = dat.components(separatedBy: "\n")
        for m in sArray{
            let trimmed = m.trimmingCharacters(in: .whitespacesAndNewlines)
            let tmp = self.readFr(trimmed + ".txt")
            if tmp.count != 0{
                modelList.append(trimmed)
                modelAndData[trimmed] = tmp
            }
        }
    }
    
    @objc func saveModelList(){
        var out = ""
        for m in modelList{
            if m.count != 0 {
                out += m + "\n"
            }
        }
        self.writeTo(fn: modelListFn, dat: out)
    }
    

    
    func loadCamCalib() -> String{
        var calib_str = ""
        if isVga {
            calib_str =
            """
            imgSize = [480 x 640]
            camMatrix =[503.850, 0, 240; 0, 503.850, 320;  0, 0, 1]
            distCoeffs =[0.12099, -0.494297, 0, 0, 0.518957]
            """;
            
            let tmp = readFr("cam_calib_480_640.txt")
            if tmp.count != 0 { calib_str = tmp}
        }else{
            calib_str =
            """
            imgSize = [720 x 1280]
            camMatrix =[1112.56, 0, 360; 0, 1112.56, 640; 0, 0, 1]
            distCoeffs =[-0.0312405904906104, 0.8632159810235785, 0, 0, -2.962057332856677]
            """;
            
            let tmp = readFr("cam_calib_721_1280.txt")
            if tmp.count != 0 { calib_str = tmp}
        }
        return calib_str
    }

//    @objc func toggleFirstResp(){
//        if (isFirstResponder){resignFirstResponder()}
//        else{ becomeFirstResponder()}
//    }
    
//    var toggleCalib = UIButton()
//    var toggleBeep = UIButton()
    var toggleCam = UIButton()
    var audioGuide = UIButton()

    var uiState = UI_State.lib
    
    func delAllButtonsLabels(){
        buttons.forEach { (item) in
             item.removeFromSuperview()
        }
        
        labels.forEach { (item) in
             item.removeFromSuperview()
        }
    }
    
    @objc func setButtons4lib(){
        uiState = .lib
        delAllButtonsLabels()
        loadModelList()
        removeTableview()
              
        let x = 10, w = 180, h = 30, dy = 40
        var y = yBtn
        y += dy; _ = addButton(x:x, y:y, w:w, h:h, title: "Add Model", color: .blue, selector: #selector(addNewModel))
        if modelList.count > 0 {
            y += dy; _ = addButton(x:x, y:y, w:w, h:h, title: "Model List", color: .blue, selector: #selector(showModelList))
        }
        y += dy; audioGuide = addButton(x:x, y:y, w:w, h:h, title: "Audio Guidance", color: .blue, selector: #selector(toggleAudioGuidance))
        setButtonAppearance(btn: audioGuide, isTrue: audioGuidance, cTrue: .green, cFalse: .red, partTitle: "Audio Guidance")
        turnOffCamera()
        imageView.image = nil
        imageView.setNeedsDisplay()
    }
    
    var backBtn = UIButton()
    
    @objc func setButtons4model(){
        uiState = .model
        delAllButtonsLabels()
        removeTableview()
        
        let x = 0, w = 160, h = 30, dy = 40
        var y = yBtn
        y += dy; backBtn = addButton(x:x, y:y, w:w, h:h, title: "Back", color: .blue, selector: #selector(setButtons4lib))
        y += dy; toggleCam = addButton(x:x, y:y, w:w, h:h, title: "Camera", color: .blue, selector: #selector(cameraOnOff))
        y += dy; _ = addLabel(x:x, y:y, w:250, h:h, text: "Current Model: " + _modelName, color: .black)
        y += dy; _ = addLabel(x:x, y:y, w:250, h:h, text: "Current Hotspot: " + _hotspot, color: .black)
        
//        y += dy; _ = addButton(x:x, y:y, w:w, h:h, title: "Model List", color: .blue, selector: #selector(showModelList))
        y += dy; _ = addButton(x:x, y:y, w:w, h:h, title: "Edit Model Name", color: .blue, selector: #selector(editModelName))
        y += dy; _ = addButton(x:x, y:y, w:w, h:h, title: "Delete Model", color: .blue, selector: #selector(delModel))
        
        y += dy; _ = addButton(x:x, y:y, w:w, h:h, title: "Hotspot List", color: .blue, selector: #selector(showHotpotList))
        y += dy; _ = addButton(x:x, y:y, w:w, h:h, title: "Edit Hotspot", color: .blue, selector: #selector(editHotspot))
        y += dy; _ = addButton(x:x, y:y, w:w, h:h, title: "Delete Hotspot", color: .blue, selector: #selector(delHotspot))

        y += dy; _ = addButton(x:x, y:y, w:w, h:h, title: "Transcribe Hotspot", color: .blue, selector: #selector(transcribeHotspot))
//        y += dy; _ = addButton(x:x, y:y, w:w, h:h, title: "cancel Recording", color: .blue, selector: #selector(movedToBackgroundOrResignActive))
//
        turnOffCamera()
        imageView.image = nil
        imageView.setNeedsDisplay()
    }
    
    func turnOffCamera(){
        videoPaused = true
        setCamButtonProperties()
        audioManager.cancelRecording()
    }
    
    @objc func toggleAudioGuidance(){
        audioGuidance = !audioGuidance
        setButtonAppearance(btn: audioGuide, isTrue: audioGuidance, cTrue: .green, cFalse: .red, partTitle: "Audio Guidance")
    }
    
    @objc func showModelList(){
        turnOffCamera()
        uiState = .modelList
        delAllButtonsLabels()
        turnOffCamera();
        loadModelList()
        if modelList.count > 0{ setupTableView(CGFloat(self.yBtn+80)) }
        else {
            speak_local("No model in the library")
            setButtons4lib()
        }
        let x = 10, w = 160, h = 30, dy = 40
        _ = addButton(x:x, y:yBtn+dy, w:w, h:h, title: "Back", color: .blue, selector: #selector(setButtons4lib))
    }
    
    @objc func showHotpotList(){
        if loadHotspotList() > 0{
            turnOffCamera();
            delAllButtonsLabels()
            uiState = .hotspotList
            setupTableView(CGFloat(self.yBtn+20))
        }
        else { speak_local("Empty hotspot list")  }
    }
    
    @objc func addNewModel(){
        turnOffCamera()
       
        let dialog = UIAlertController(title: "Add Model", message: "", preferredStyle: .alert)
        dialog.addTextField { (textField) in
            textField.placeholder = "Model Name"
            textField.textColor = .green
        }

        let save = UIAlertAction(title: "Save", style: .default) { (alertAction) in
            self._modelName = dialog.textFields![0].text ?? ""
            self.camIoWrapper.clear()
            self.turnOffCamera()
            self.hotspotList.removeAll()
            self.tryAddModelName(self._modelName)
            self.setButtons4model()
        }
        
        dialog.addAction(save)
        dialog.addAction(UIAlertAction(title: "Cancel", style: .default) { (alertAction) in
        })
        self.present(dialog, animated:true, completion: nil)
    }
    
    func tryAddModelName(_ name: String){
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == 0 {return}
        var all = self.readFr(self.modelListFn)
        for nm in all.components(separatedBy: "\n"){
              if trimmed == nm{
                  return
              }
        }
        print(trimmed + "is added to model library")
        all.append("\n" + trimmed)
        self.writeTo(fn: self.modelListFn, dat: all)
    }
     
    @objc func cameraOnOff(){
        videoPaused = !videoPaused
        if videoPaused { turnOffCamera() }
        setCamButtonProperties()
    }
    
    func setCamButtonProperties(){
        setButtonAppearance(btn: toggleCam, isTrue: !videoPaused, cTrue: .green, cFalse: .red, partTitle: "Camera")
        if videoPaused {backBtn.isEnabled = true}
        else {backBtn.isEnabled = false}
    }
    
    func setButtonAppearance(btn: UIButton, isTrue: Bool, cTrue: UIColor, cFalse: UIColor, partTitle: String){
        if isTrue{
            btn.backgroundColor = cTrue
            btn.isSelected = true
        } else {
            btn.backgroundColor = cFalse
            btn.isSelected = false
        }
        btn.setTitle(partTitle + " Off", for: .normal)
        btn.setTitle(partTitle + " On", for: .selected)
    }
    
    func speak_local(_ voiceOutdata: String ) {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        let utterance = AVSpeechUtterance(string: voiceOutdata)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        let synth = AVSpeechSynthesizer()
        synth.speak(utterance)
    }
    
    @objc func delHotspot(){
        turnOffCamera()
        if self.camIoWrapper.getCurrentRegion() == -1 {
            speak_local("no hotspot left")
            return
        }
        let model = UIAlertController(title: "Delete Current Hotspot ", message: "", preferredStyle: .alert)
        model.addAction(UIAlertAction(title: "OK", style: .default) { (alertAction) in
            self.camIoWrapper.deleteCurrentRegion()
            self.saveModelData()
            
            self.updateCurrentHotspot()
        })
        model.addAction(UIAlertAction(title: "Cancel", style: .default) { (alertAction) in})

        self.present(model, animated:true, completion: nil)
    }
    
    func removeCurrentModelEntry(){
        var all = self.readFr(self.modelListFn)
        all = all.replacingOccurrences(of: self._modelName, with: "")
        all = all.replacingOccurrences(of: "\n\n", with: "\n")
        self.writeTo(fn: self.modelListFn, dat: all)
    }
    
    @objc func delModel() {// delete current model from database
        turnOffCamera()
        let model = UIAlertController(title: "Delete Model: "+self._modelName, message: "Are you sure?", preferredStyle: .alert)
        let del = UIAlertAction(title: "OK", style: .default) { (alertAction) in
            self.removeCurrentModelEntry()
            self.camIoWrapper.clear()
            self.setButtons4lib()
        }
        
        model.addAction(del)
        model.addAction(UIAlertAction(title: "Cancel", style: .default) { (alertAction) in})
        
        self.present(model, animated:true, completion: nil)
    }

    func saveModelData(){
        let dat = self.camIoWrapper.getModelString()
        self.writeTo(fn: self._modelName + ".txt",dat:dat)
        print("save model to file" + self._modelName + ".txt\n" + dat)
    }
    
    @objc func editModelName(){
        turnOffCamera()
        let model = UIAlertController(title: "Edit Model Name", message: "", preferredStyle: .alert)
        model.addTextField { (textField) in
            textField.placeholder = "Name"
            textField.text = self._modelName
            textField.textColor = .green
        }
        
        let save = UIAlertAction(title: "Save", style: .default) { (alertAction) in

            let name = model.textFields![0] as UITextField
            let dat = self.camIoWrapper.getModelString()
            self.writeTo(fn:name.text! + ".txt",dat:dat)
            self._modelName = name.text!
            //
            // if the model is already in the library, skip, otherwise, add to it
            var all = self.readFr(self.modelListFn)
            for nm in all.components(separatedBy: "\n"){
                if name.text == nm{
                    return
                }
            }
            all.append("\n" + name.text!)
            self.writeTo(fn: self.modelListFn, dat: all)
        }
        
        model.addAction(save)
        model.addAction(UIAlertAction(title: "Cancel", style: .default) { (alertAction) in
        })
        
        self.present(model, animated:true, completion: nil)
    }
    
    @objc func saveModel() {
        turnOffCamera()
        let model = UIAlertController(title: "Model", message: "name, description", preferredStyle: .alert)
        model.addTextField { (textField) in
            textField.placeholder = "Name"
            if self._modelName.count != 0 {textField.text = self._modelName}
            textField.textColor = .green
        }
        
        model.addTextField { (textField) in
            textField.placeholder = "Description (optional)"
            if self.curModel.description.count != 0 {textField.text = self.curModel.description}
            textField.textColor = .green
        }
        
        let save = UIAlertAction(title: "Save", style: .default) { (alertAction) in
            self.curModel.name = model.textFields![0].text ?? ""
            self.curModel.description = model.textFields![1].text ?? ""
            let name = model.textFields![0] as UITextField
            let dat = self.camIoWrapper.getModelString()
            self.writeTo(fn:name.text! + ".txt",dat:dat)

            self.postTo(urlStr: self.urlStr, route:"model",json: ["name":name.text!,"data":dat])
            self._modelName = name.text!
            //
            // if the model is already in the library, skip, otherwise, add to it
            var all = self.readFr(self.modelListFn)
            for nm in all.components(separatedBy: "\n"){
                if name.text == nm{
                    return
                }
            }
            all.append("\n" + name.text!)
            self.writeTo(fn: self.modelListFn, dat: all)
        }
        
        model.addAction(save)
        model.addAction(UIAlertAction(title: "Cancel", style: .default) { (alertAction) in })
        
        self.present(model, animated:true, completion: nil)
    }
    

    func getModelList() -> [String] {
        return self.readFr(modelListFn).components(separatedBy: "\n")
    }
    
    func loadModelLocal(_ name: String){
        let dat = self.readFr(name + ".txt")
        if dat.count>0{
            print("loading model: \(name)")
            print(dat)
            self.camIoWrapper.loadModel(dat)
            self._modelName = name
        }
    }
    
    @objc func loadModel() {
        turnOffCamera()
        let model = UIAlertController(title: "Model", message: "", preferredStyle: .alert)
        
        model.addTextField { (textField) in
            textField.placeholder = "Name"
            if self._modelName.count != 0 {textField.text = self._modelName}
            textField.textColor = .green
        }
        
        let load = UIAlertAction(title: "Load", style: .default) { (alertAction) in
            let name = model.textFields![0] as UITextField
            self.loadModelLocal(name.text!)
//            let dat = self.readFr(name.text! + ".txt")
//            if dat.count>0{
//                print(dat)
//                self.camIoWrapper.loadModel(dat)
//                self._modelName = name.text!
//            } else {  // try to get it from web server
//                let session = URLSession.shared
//                let url = URL(string: self.urlStr+"model?name="+name.text!)!
//
//                let task = session.dataTask(with: url) { data, response, error in
//                    if error != nil || data == nil {print("Client error!"); return }
//                    guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {print("Server error!"); return}
//                    guard let mime = response.mimeType, mime == "application/json" else {print("Wrong MIME type!"); return }
//                    do {
//                        if let json = try JSONSerialization.jsonObject(with: data!, options: []) as? [String: AnyObject] {
//                            if let dat = json["data"] as? String {
//                                self.camIoWrapper.loadModel(dat)
//                                self._modelName = name.text!
//                            }
//                        }
//                    } catch {print("JSON error: \(error.localizedDescription)")}
//                }
//                task.resume()
//            }
//            self.pauseVideo = false
        }
        
        model.addAction(load)
        model.addAction(UIAlertAction(title: "Cancel", style: .default) { (alertAction) in
//             self.pauseVideo = false
        })
        
        self.present(model, animated:true, completion: nil)
    }
    
    var videoPaused = false
    
    @objc func transcribeHotspot(){
        let iRegion = self.camIoWrapper.getCurrentRegion()
        if iRegion == -1 {
            speak_local("no hotspot selected")
            return
        }
        turnOffCamera()
        let nameDescription = self.camIoWrapper.getCurrentNameDescription().components(separatedBy: "------");
        let des_label = nameDescription[0].components(separatedBy: "?")
        let fileURL = getDocumentsDirectory().appendingPathComponent(des_label[0] + ".m4a")
        doSpeechRecognition(fileURL)
    }
    
    func updateCurrentHotspot(){
        current = Int(self.camIoWrapper.getCurrentRegion())
        self.setButtons4model()
        if current == -1 {
            speak_local("no hotspot left")
        }
    }
    
    func saveHotspotTranscription(_ tr:String){
         let nameDescription = self.camIoWrapper.getCurrentNameDescription().components(separatedBy: "------");
         let des_label = nameDescription[0].components(separatedBy: "?")
                
         print("name = ", nameDescription[0])
         let regionInfo = UIAlertController(title: "Replace Hotspot Name?", message: "Old name: \(des_label[1])", preferredStyle: .alert)

         regionInfo.addTextField { (textField) in
            textField.textColor = .green
            textField.text = tr
        }
  
        let save = UIAlertAction(title: "Save", style: .default) { (alertAction) in
            let label = regionInfo.textFields![0] as UITextField
            let newName = des_label[0]+"?"+label.text!
            self.camIoWrapper.setCurrentNameDescription(newName, with: nameDescription[1]+"___");
            self.saveModelData()
            
            self.updateCurrentHotspot()
            _ = self.loadHotspotList()
            self.setButtons4model()
        }

        regionInfo.addAction(save)
        regionInfo.addAction(UIAlertAction(title: "Cancel", style: .default) { (alertAction) in
        })
        
        self.present(regionInfo, animated:true, completion: nil)
    }
    
    @objc func editHotspot() {
        let iRegion = self.camIoWrapper.getCurrentRegion()
        if iRegion == -1 {
            speak_local("no hotspot selected")
            return
        }
                
        turnOffCamera()
        let nameDescription = self.camIoWrapper.getCurrentNameDescription().components(separatedBy: "------");
        let des_label = nameDescription[0].components(separatedBy: "?")
        
        print("name = ", nameDescription[0])
//        print("description = ", nameDescription[1])
        let regionInfo = UIAlertController(title: "Edit Hotspot", message: "", preferredStyle: .alert)

        regionInfo.addTextField { (textField) in
//            textField.placeholder = "Label"
            textField.textColor = .green
            if des_label.count>1 { textField.text = des_label[1] }
        }
        
//        regionInfo.addTextField { (textField) in
//            //textField.placeholder = "Region Description"
//            textField.text = nameDescription[1]
//            textField.textColor = .blue
//        }
        
        let save = UIAlertAction(title: "Save", style: .default) { (alertAction) in
             let label = regionInfo.textFields![0] as UITextField
//            let description = regionInfo.textFields![1] as UITextField
            
//            let des = description.text!
            let newName = des_label[0]+"?"+label.text!
//            let des = nameDescription[1]
            self.camIoWrapper.setCurrentNameDescription(newName, with: nameDescription[1]+"___");
            self.saveModelData()
            
            self.updateCurrentHotspot()
        }

        regionInfo.addAction(save)
        regionInfo.addAction(UIAlertAction(title: "Cancel", style: .default) { (alertAction) in
        })
        
        self.present(regionInfo, animated:true, completion: nil)
    }
    
//    var barcodeRequest:VNDetectBarcodesRequest?
//    func startQRDetection(){
//        barcodeRequest = VNDetectBarcodesRequest(completionHandler:self.qrcodeHandler)
//    }
    
//    func qrcodeHandler(request: VNRequest, error: Error?){
//        guard let results = request.results else { return }
//        for result in results {
//            // Cast the result to a barcode-observation
//            if let barcode = result as? VNBarcodeObservation {
//                // Print barcode-values
//                print("Payload: ", barcode.payloadStringValue!)
//                toggleQRDetector(btn:toggleCalib)
//            }
//        }
//    }
//

    func addNewRegion(_ newRegionXyz: String){
        camIoWrapper.newRegion(newRegionXyz)
        loadHotspotList()
        current = hotspotList.count-1
        setCurrentHotspot()
        setButtons4model()
        cameraOnOff()
    }
    
    
    func processFrame(_ image:UIImage) {
        camIoWrapper.setAudioGuidance(audioGuidance)
        imageView.image = camIoWrapper.procImage(image)
//        if camIoWrapper.isCameraCovered(){
//            print("camera is covered")
//        }
        if isCalib { return }
        let saved = audioManager.trySaveRegion2cpp(self)
        if saved {  saveModelData() }
        if iSaveJpg > -1 && iSaveJpg < iImageMax { tmp4saveImages(iImageMax) }
        audioManager.processState(iState:camIoWrapper.getStateIdx(), stylusString: camIoWrapper.getState(),audioGuidance:audioGuidance)
    }
    

    
    var iSaveJpg = -1
    let iImageMax = 100
    var images = [UIImage]()
    func tmp4saveImages(_ iMax: Int){
        if iSaveJpg == 0{  images = [UIImage]()}
        images.append(imageView.image!)
        iSaveJpg += 1
        print("iSaveJpg = ", iSaveJpg)
        if iSaveJpg == iImageMax - 1 {
            var i=0
            for image in self.images{
                _ = UIViewController.storeImageToDocumentDirectory(image: image, fileName: "img"+String(i)+".jpg")
                i += 1
            }
            iSaveJpg = -1
        }
    }
    
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if self.videoPaused == true {
            audioManager.stopPlaying()
            return
        }
        usleep(10000) //will sleep for 10 milli seconds
        DispatchQueue.main.sync {

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            guard let cgImage = self.context.createCGImage(ciImage, from: ciImage.extent) else { return }
            let image = UIImage(cgImage: cgImage).imageRotatedByDegrees(degrees:90.0,flip:false)
            self.processFrame(image)
            self.oneCalibFrame(image)
//
//            if self.toggleCalib.isSelected {
//                try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([self.barcodeRequest!])
//            }
        }
    }
}

//*****************************************************************************************************************************************
//start of extensions
//

extension UIViewController{
    public static var documentsDirectoryURL: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    public static func fileURLInDocumentDirectory(_ fileName: String) -> URL {
        return self.documentsDirectoryURL.appendingPathComponent(fileName)
    }
    
    public static func storeImageToDocumentDirectory(image: UIImage, fileName: String) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
               return nil
        }
        
        let fileURL = self.fileURLInDocumentDirectory(fileName)
        do {
            try data.write(to: fileURL)
            print("saved: "+fileName)
            return fileURL
        } catch {
            return nil
        }
    }
    
    func listDir(){
        let fileManager = FileManager.default
        
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let contents = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            for filename in contents {
                print(filename)
            }
        } catch {
            print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
        }
    }
    
    func deleteFile(_ fn2Del:String){
        let fileManager = FileManager.default
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentDirectory = paths[0]
        let filePath = documentDirectory.appendingFormat("/" + fn2Del)
        do {try fileManager.removeItem(atPath: filePath)}
        catch let error as NSError {
            print("Error : \(error)")
        }
    }
    
    func writeTo(fn:String,  dat:String){
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(fn)
            //writing
            do {
                try dat.write(to: fileURL, atomically: false, encoding: .utf8)
            }
            catch {/* error handling here */}
        }
    }
    
    func readFr(_ fn:String) -> String{
        var text = ""
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(fn)
            do {
                text = try String(contentsOf: fileURL, encoding: .utf8)
            }
            catch {
                return ""
            }
        }
        return text
    }
    
    func postTo(urlStr: String, route:String, json: [String:String]){
        let session = URLSession.shared
        let url = URL(string: urlStr+route)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Powered by Swift!", forHTTPHeaderField: "X-Powered-By")
        
        let jsonData = try! JSONSerialization.data(withJSONObject: json, options: [])
        let task = session.uploadTask(with: request, from: jsonData) { data, response, error in
            if let data = data, let dataString = String(data: data, encoding: .utf8) {
                print(dataString)
            }
        }
        task.resume()
    }
    
    func getSubstring(str: String, after: Character, upto: Character) -> String{
          guard after != upto else {return str}
        return String(str[str.firstIndex(of: after)! ..< str.firstIndex(of: upto)!].dropFirst())
    }
}

extension UIImage {
    
    public func imageRotatedByDegrees(degrees: CGFloat, flip: Bool) -> UIImage {
        let degreesToRadians: (CGFloat) -> CGFloat = {
            return $0 / 180.0 * CGFloat.pi
        }
        
        // calculate the size of the rotated view's containing box for our drawing space
        let rotatedViewBox = UIView(frame: CGRect(origin: .zero, size: size))
        rotatedViewBox.transform = CGAffineTransform(rotationAngle: degreesToRadians(degrees))
        let rotatedSize = rotatedViewBox.frame.size
        
        // Create the bitmap context
        UIGraphicsBeginImageContext(rotatedSize)
        let bitmap = UIGraphicsGetCurrentContext()
        
        // Move the origin to the middle of the image so we will rotate and scale around the center.
        bitmap?.translateBy(x: rotatedSize.width / 2.0, y: rotatedSize.height / 2.0)
        
        //   // Rotate the image context
        bitmap?.rotate(by: degreesToRadians(degrees))
        
        // Now, draw the rotated/scaled image into the context
        var yFlip = CGFloat(1.0)
        if flip { yFlip = CGFloat(-1.0) }
        
        bitmap?.scaleBy(x: yFlip, y: -1.0)
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        bitmap?.draw(cgImage!, in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }
}

extension Character {
    var asciiValue: Int {
        get {
            let s = String(self).unicodeScalars
            return Int(s[s.startIndex].value)
        }
    }
}

extension String {
    func characterAtIndex(index: Int) -> Character? {
        var cur = 0
        for char in self {
            if cur == index {
                return char
            }
            cur+=1
        }
        return nil
    }
}

extension String {
    subscript(_ range: CountableRange<Int>) -> String {
        let idx1 = index(startIndex, offsetBy: max(0, range.lowerBound))
        let idx2 = index(startIndex, offsetBy: min(self.count, range.upperBound))
        return String(self[idx1..<idx2])
    }
}

extension String {
    func convertToValidFileName() -> String {
        let invalidFileNameCharactersRegex = "[^a-zA-Z0-9_]+"
        let fullRange = startIndex..<endIndex
        let validName = replacingOccurrences(of: invalidFileNameCharactersRegex,
                                           with: "-",
                                        options: .regularExpression,
                                          range: fullRange)
        return validName
    }
}

//  "name.name?/!!23$$@1asd".convertToValudFileName()           // "name-name-23-1asd"
//  "!Hello.312,^%-0//\r\r".convertToValidFileName()            // "-Hello-312-0-"
//  "/foo/bar/pop?soda=yes|please".convertToValidFileName()     // "-foo-bar-pop-soda-yes-please"

extension String {
    func index(from: Int) -> Index {
        return self.index(startIndex, offsetBy: from)
    }

    func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return String(self[fromIndex...])
    }

    func substring(to: Int) -> String {
        let toIndex = index(from: to)
        return String(self[..<toIndex])
    }

    func substring(with r: Range<Int>) -> String {
        let startIndex = index(from: r.lowerBound)
        let endIndex = index(from: r.upperBound)
        return String(self[startIndex..<endIndex])
    }
}
//let str = "Hello, playground"
//print(str.substring(from: 7))         // playground
//print(str.substring(to: 5))           // Hello
//print(str.substring(with: 7..<11))    // play
