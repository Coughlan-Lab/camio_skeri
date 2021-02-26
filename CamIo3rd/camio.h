//
//  camio.hpp
//  CamIO4iOS
//
//  Created by Huiying Shen on 1/29/18.
//  Copyright © 2018 Huiying Shen. All rights reserved.
//

#ifndef camio_hpp
#define camio_hpp

#include <iostream>
#include <fstream>
#include <string>
#include <opencv2/opencv.hpp>

#include "camIoObj.h"
#include "util.h"
#include "anchorBase.h"
#include "dowelStylus.h"

//struct StylusStateString{
//    String no_board;
//    String board_only;
//    String exploring;
//    String tts_speaking;
//    String pre_recording;
//    String startRecording;
//};

class CamIO {
    enum Action { NewRegion, Add2Region, SelectRegion, DeleteRegion, Exploring };

    cv::Ptr<aruco::Dictionary> dictionary;
    cv::Ptr<aruco::DetectorParameters> detectionParams;
    MarkerArray markers;
    SmoothedDetection det;
    CamCalib calib;
    
	Obj obj;
    //Ptr<RectBase> pRectBase;
    cv::Ptr<SkiBoard> pSkiBoard;
	cv::Ptr<DowelStylus> pStylus;
    vector<int> stylus_ids;
    RingBufP3f bufP3f;
    RingBufInt bufInt;
    
    Action action = Action::Exploring;

    bool isIntrinscSet = false;
    bool bStylus = false;
    bool isCaptured = false;
    bool audioGuidance = true;
    
    //StylusStateString ssString;

    chrono::time_point<chrono::system_clock> time_point;

    string stateString;
public:
    int iState;
    bool isCalib = false;
    bool isDark = false;
public:
    static Mat camMatrix, distCoeffs;
    static Mat camRotMat;
public:

	CamIO(aruco::PREDEFINED_DICTIONARY_NAME dictName = aruco::DICT_5X5_250) :markers(dictName),
		pSkiBoard(SkiBoard::create(dictName)), pStylus(DowelStylus::create(dictName)),bufP3f(999),calib(dictName),
        time_point(chrono::system_clock::now())
    {
        stylus_ids = {100,200}; //1st for writing, 2nd for reading
        pStylus->setParam(stylus_ids[1],10, 0.0254*0.5, 0.0181*0.5);
        pStylus->setXYZ();
        //pRectBase->setMarker3ds(150, 0.0155, 0.0931,0.124);
        pSkiBoard->setMarker3ds(0,0.0215);
            
//        ConvexHullGiftWrapping::test0();
//        cout<<"here";
	}
    void clear() {obj.clear();}
    bool isCameraCovered() {return isDark;}
    bool isImageBlack(const Mat& gray, int thrsh = 20, float tol = 0.05){
        float nHigh = 0;
        unsigned char *input = (unsigned char*)(gray.data);
        for (int i = 0;i < gray.cols;i++){
            for (int j = 0;j < gray.rows;j++)
                if (input[gray.cols * j + i ] > thrsh)
                    nHigh += 1;
        }
        return nHigh/gray.cols/gray.rows < tol;
    }

//    void setRectBase(int id1st, float markerLength, float rWidth2markerLength, float rHeight2markerLength) {
//        float dx = markerLength * rWidth2markerLength;
//        float dy = markerLength * rHeight2markerLength;
//        //pRectBase->setMarker3ds(id1st,  markerLength,  dx,  dy);
//        pSkiBoard->setMarker3ds(id1st,  markerLength);
//    }
    
//    string getRectBaseString(){
//        stringstream ss;
//        ss<<"[\"id\":";
//        ss<<pRectBase->id1st<<", ";
//        ss<<"\"markerLengthInMeter\":";
//        ss<<pRectBase->markerLength<<", ";
//        ss<<"\"rWidth2markerLength\":";
//        ss<<pRectBase->dx/pRectBase->markerLength<<", ";
//        ss<<"\"rHeight2markerLength\":";
//        ss<<pRectBase->dy/pRectBase->markerLength<<"]";
//        return ss.str();
//    }
    string getSkiBoardString(){
        stringstream ss;
        ss<<"[\"id\":";
        ss<<pSkiBoard->id1st<<", ";
        ss<<"\"markerLengthInMeter\":";
        ss<<pSkiBoard->markerLength<<", ";
        ss<<"\"rWidth2markerLength\":";
        return ss.str();
    }
    
    void newRegionWithXyz(const string &xyz){
        obj.newRegionWithXyz(xyz);
    }
    bool tryAddImage4Calib(const Mat &gray){
        return calib.tryAddFrame(gray);
    }
    
    void initCalib(){
        isCalib = true;
        calib.clear();
    }
    string doCalib(){
        return calib.calib();
    }
    string getRegionNames(){
        return obj.getRegionNames();
    }
    void setCurrent(int i){
         obj.setCurrent(i);
     }
    
    void setAudioGuidance(bool b){
        audioGuidance = b;
    }
    
    bool isNewRegion(){ return action == Action::NewRegion;}
    bool isExploring(){ return action == Action::Exploring;}
    bool locationCaptured(){ return isCaptured; }
    
    void setNewRegion(){action = Action::NewRegion;}
    void setAdd2Region(){action = Action::Add2Region;}
    void setSelectRegion(){action = Action::SelectRegion;}
    bool isActionDone() const { return action==Action::Exploring;}
    bool isStylusVisible() const {return bStylus;}
    int getCurrentRegion() const {return obj.current;}
    bool setCurrentNameDescription(const string &name, const string &description){
        return obj.setCurrentNameDescription(name,description);
    }
    
    string getCurrentNameDescription(){
        return obj.getCurrentNameDescription();
    }

	bool setIntrinsic(string calibStr) {
		return ::setCameraCalib(calibStr, camMatrix, distCoeffs);
	}

    bool loadObj(string objStr){ return true;}

    string getObjJson(){ return obj.toJson(); }
    
    void loadModel(string objJson){
        obj.clear();
        obj.setAllRegions(objJson);
        obj.checkReginNames();
    }

	void drawObj(Mat &bgr, const Mat &camMatrix, const Mat &distCoeffs) {
		obj.draw(bgr, pSkiBoard->rvec, pSkiBoard->tvec, camMatrix, distCoeffs);
	}
    
    Point3f transformStylusTip2local(){return pStylus->transformStylusTip2local(*pSkiBoard);}

    void addNewRegion();
	bool tryAdd2Region() {return obj.tryAdd2Region(transformStylusTip2local());}
    
	bool trySelectRegion(float tol = 0.01f) {
        Mat rMat;
        Rodrigues(pSkiBoard->rvec,rMat);
        obj.setNearest(transformStylusTip2local(),rMat,0.5,tol);
        return obj.isCurrentClose;
    }
    
	void deleteCurrentRegion() { obj.deleteCurrentRegion(); }
     
    string getState(){ return stateString; }
    
    static string p3fToString(const Point3f &p3f){
        stringstream ss;
        ss<<setprecision(3)<<p3f.x<<"_";
        ss<<setprecision(3)<<p3f.y<<"_";
        ss<<setprecision(3)<<p3f.z;
        return ss.str();
    }
    
    void do1timeStep(Mat& bgr);
    void procWritingStylus(Mat& bgr);
    void procReadingStylus(Mat& bgr);
    void setRobustState();
};

#endif /* camio_hpp */
