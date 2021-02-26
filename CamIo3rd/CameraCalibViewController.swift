//
//  CameraCalibViewController.swift
//  CamIo3rd
//
//  Created by Huiying Shen on 12/18/19.
//  Copyright © 2019 Huiying Shen. All rights reserved.
//

import UIKit
import AVFoundation

public class RectDemo: UIView
{
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(displayP3Red: 1.0, green: 1.0, blue: 0.0, alpha: 0.1)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func draw(_ frame: CGRect) {
        let h = self.frame.height
        let w = self.frame.width
        let color:UIColor = UIColor.yellow
        
        
        let drect = CGRect(x: (w * 0.02), y: (h * 0.02), width: (w * 0.96), height: (h * 0.96))
        let bpath:UIBezierPath = UIBezierPath(rect: drect)

        color.set()
        bpath.stroke()

        print("it ran")
        NSLog("drawRect has updated the view")
    }
}

/*
 *****************************************************************************************************************************************
 *
 class UIKeyViewController
 
 */
class UIKeyViewController: SimpleCamViewController,UIKeyInput{
    var strCurrent = ""
    var hasText : Bool {
        get {
            return strCurrent.count>0
        }
    }
    
    ////    var eState = EditState.explore
    ////    var eStateOld = EditState.explore
    var txtOld = ""
    func insertText(_ txt: String) {
        print(txt + ", ascii: " + String(txt.characterAtIndex(index: 0)!.asciiValue))
//        if eState == .edit{
//            if txt == "\n" {
//                if txtOld != "\n"{
//                    ttsSpeaker.speak(strCurrent+", ..., Press Enter to confirm label or Backspace to enter the label over again")
//                }else{
//                    self.camIoWrapper.setCurrentNameDescription(strCurrent, with: "___")
//                    ttsSpeaker.speak("hotspot label saved")
//                    eState = .explore
//                    strCurrent = ""
//                }
//            } else{
//                strCurrent += txt
//            }
//            txtOld = txt
//        } else {
//            switch txt{
//            case "n": eState = .new
//            case "a": eState = .add
//            case "s": eState = .select
//            default: break
//            }
//        }
        
    }
    
    func deleteBackward() {
        if hasText {
//            strCurrent = strCurrent[0..<(strCurrent.count-1)]
            strCurrent = ""
            print(strCurrent)
        }
        txtOld = "" // in case txtOld was "\n"
    }
        
//    override var canBecomeFirstResponder: Bool {
//        get {
//            return true
//        }
//    }
}

/*
 ******************************************************************************************************************************************
 *
 class CameraCalibViewController
 */

class CameraCalibViewController: UIKeyViewController{
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { get {return .portrait} }
    
    let camIoWrapper = CamIoWrapper()

    let audioManager = AudioManager()
    let imageView = UIImageView()
    
    var btnAddImage = UIButton()
    var btnDoCalib = UIButton()
    var buttons = [UIButton]()
    var labels = [UILabel]()
    
    let yBtn = 20
    override func viewDidLoad() {
        super.viewDidLoad()
        setupImageView()
        
        animator = UIDynamicAnimator(referenceView: view)
        
//        let x = 10, w = 120, h = 20, dy = 30
//        yBtn += dy; _ = addButton(x:x, y:yBtn, w:w, h:h, title: "Init Calib", color:.blue, selector: #selector(initCalib))
//        yBtn += dy; btnAddImage = addButton(x:x, y:yBtn, w:w, h:h, title: "Add Image", color:.blue, selector: #selector(addImage))
//        yBtn += dy; btnDoCalib = addButton(x:x, y:yBtn, w:w, h:h, title: "Do Calib", color:.blue, selector: #selector(doCalib))
    }
    
    func setupImageView(){
        view.addSubview(imageView)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(x:0 , y:0, width: view.bounds.width, height: view.bounds.height)
    }
    
    func addButton(x:Int, y: Int, w: Int, h: Int, title: String, color: UIColor, selector: Selector) -> UIButton{
        let btn =  UIButton()
        btn.frame = CGRect (x:x, y:y, width:w, height:h)
        btn.setTitle(title, for: UIControl.State.normal)
        btn.setTitleColor(color, for: .normal)
        btn.backgroundColor = .lightGray
        btn.addTarget(self, action: selector, for: UIControl.Event.touchUpInside)
        self.view.addSubview(btn)
        buttons.append(btn)
        return btn
    }
    
    func addLabel(x:Int, y: Int, w: Int, h: Int, text: String, color: UIColor) -> UILabel{
        let label =  UILabel()
        label.frame = CGRect (x:x, y:y, width:w, height:h)
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor =  color
        label.backgroundColor = .lightGray
        label.text = text
        self.view.addSubview(label)
        labels.append(label)
        return label
    }
    
    var isCalib = false
        
    var xRect = 0, yRect=0
    var wRect = 10.0, hRect = 10.0
    var rectDemo = RectDemo(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    
    @objc func initCalib(sender: UIButton!) {
        isCalib = true
        camIoWrapper.initCalib()
        wRect = Double(view.frame.width/3)
        hRect = Double(view.frame.height/3)
        showRectArea()
        cnt = (cnt + 1)%9
    }
    
    var goCalib = false
    @objc func doCalib(sender: UIButton!) {
        goCalib = true
    }

    var cnt = 0
    var xImg = 0.0, yImg = 0.0
    @objc func addImage(sender: UIButton!) {
        rectDemo.removeFromSuperview()
        showRectArea()
        addImage4calib = true
        cnt = (cnt + 1)%9
        audioManager.playSingleClick()
    }
    
    func showRectArea(){
        xImg = Double(cnt%3)
        yImg = Double(Int(cnt/3))
        rectDemo = RectDemo(frame: CGRect(x: wRect*xImg, y: hRect*yImg, width: wRect, height: hRect))
        rectDemo.draw(CGRect(x: 0, y: 0, width: 0, height: 0))
        view.addSubview(rectDemo)
        btnAddImage.backgroundColor = .green
        btnDoCalib.backgroundColor = .green
        view.bringSubviewToFront(btnAddImage)
        view.bringSubviewToFront(btnDoCalib)
    }
    
    var imViews: [UIImageView] = []
    
    var addImage4calib = false
    var currentSubview = UIImageView()
    private var animator: UIDynamicAnimator!
    private var tossing: TossingBehavior!
    
    
    func addImageAndView(_ image:UIImage){
        currentSubview = UIImageView()
        currentSubview.image = image
        let wImg = 120.0
        let hImg = wImg*Double((image.size.height/image.size.height))
        let cnt2 = (cnt - 2 + 9)%9
        let xImg = Double(cnt2%3)
        let yImg = Double(cnt2/3)
        currentSubview.frame = CGRect(x: wRect*xImg, y: hRect*yImg, width: wImg, height: hImg)
        currentSubview.contentMode = .scaleAspectFit
        view.addSubview(currentSubview)
        
        tossing = TossingBehavior(item: currentSubview, snapTo: view.center)
//        animator.addBehavior(tossing)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(pannedView))
        currentSubview.addGestureRecognizer(panGesture)
        currentSubview.isUserInteractionEnabled = true
        
        imViews.append(currentSubview)
        view.bringSubviewToFront(btnAddImage)
        view.bringSubviewToFront(btnDoCalib)
    }
    
    @objc func pannedView(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            tossing.isEnabled = false
        case .changed:
            let translation = recognizer.translation(in: view)
            currentSubview.center = CGPoint(x: currentSubview.center.x + translation.x,
                                        y: currentSubview.center.y + translation.y)
            recognizer.setTranslation(.zero, in: view)
            
        case .ended, .cancelled, .failed:
            tossing.isEnabled = false
        case .possible:
            break
        }
    }
    
    func saveCalib(_ calibResult: String) {
        let calib = UIAlertController(title: "Calib Result", message: calibResult, preferredStyle: .alert)
        
        let save = UIAlertAction(title: "Save", style: .default) { (alertAction) in
            let sz = self.getSubstring(str:calibResult, after:"[", upto: "]").components(separatedBy: " x ")
            let fn = "cam_calib_"+sz[0]+"_"+sz[1]+".txt"
            print("writing cam calib to file: ", fn)
            self.writeTo(fn: fn, dat: calibResult)
        }
        
        calib.addAction(save)
        calib.addAction(UIAlertAction(title: "Cancel", style: .default) { (alertAction) in })
        
        self.present(calib, animated:true, completion: nil)
    }
    
    func oneCalibFrame(_ image: UIImage){
        if self.addImage4calib{
            if self.camIoWrapper.tryAdd4Calib(image) {
                self.addImageAndView(self.imageView.image!)
            }
        }
        self.addImage4calib = false  // if this time click does not work, click again
        
        if self.goCalib{
            let out = self.camIoWrapper.doCalib();
            print(out)
            saveCalib(out)
            self.goCalib = false
        }
    }
}
