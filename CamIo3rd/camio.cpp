//
//  camio.cpp
//  CamIO4iOS
//
//  Created by Huiying Shen on 1/29/18.
//  Copyright © 2018 Huiying Shen. All rights reserved.
//

#include <math.h>
#include <chrono>
#include <thread>

#include "util.h"
#include "camio.h"

Mat CamIO::camMatrix;
Mat CamIO::distCoeffs;
Mat CamIO::camRotMat;

//Point3f CamIO::transformStylusTip2local() {
//    Mat tvec = pStylus->tvec - pSkiBoard->tvec;
//    Mat rMat;
//    Rodrigues(pSkiBoard->rvec, rMat);
//    rMat = rMat.t();
//    Matx31f out = Matx33f(rMat)*Matx31f(tvec);
//    return Point3f(out(0, 0), out(1, 0), out(2, 0));
//}

void CamIO::addNewRegion() {

    if (bufP3f.isNotMoving(0.005)){ //dMaxTol, in meter
        obj.addNewRegion(bufP3f.centroid);
        action = Action::Exploring;
    }
}


void CamIO::do1timeStep(Mat& bgr){
    // yield some cpu time
    std::this_thread::sleep_for(std::chrono::milliseconds(5));
    
    Mat gray;
//    resize(bgr, bgr,  bgr.size()*2,0,0,INTER_NEAREST);
    cvtColor(bgr, gray, CV_BGR2GRAY);
    isDark = isImageBlack(gray);
    markers.detect(gray);
    markers.draw(bgr);
    if (isCalib) return;
    
    // 1. no board
    iState = 0;
    stateString = "";
    bool bBoard = pSkiBoard->detect(markers, camMatrix, distCoeffs);
    pSkiBoard->draw(bgr);
    
    int fontFace=FONT_HERSHEY_DUPLEX;
    float fontScale=1.0;
    Scalar color=Scalar(100,100,0);
    pSkiBoard->drawDetectErrors(bgr, Point(200,30),fontFace,fontScale,color);
    pSkiBoard->drawProjectedPoints(bgr);
    
    if (bBoard) {
        //2. board only
        if (!audioGuidance) obj.current = -1;
        iState = 1;
        pSkiBoard->drawAxis(bgr, camMatrix, distCoeffs,0.05);
        drawObj(bgr, camMatrix, distCoeffs);
    }
 
    for (int i=0; i<stylus_ids.size(); i++){
        pStylus->resetId(stylus_ids[i]);
        bStylus = pStylus->detect(markers, camMatrix, distCoeffs);
//        cout<<"stylus_ids[i], markers.size() = "<< stylus_ids[i]<<", "<<markers.size()<<endl;
        if (bStylus) {
            pStylus->addTvec2Buffer();
            int mult = 1;
            Size sz0 = bgr.size();
            if (mult>1) resize(bgr, bgr,  bgr.size()*mult,0,0,INTER_NEAREST);
            
            markers.draw(bgr,mult);
            pStylus->drawTip(bgr, camMatrix, distCoeffs,mult);
            pStylus->drawProjected(bgr,mult);
            if (mult>1){
                Size sz = bgr.size();
                Rect r(sz.width/2-sz0.width/2,sz.height/2-sz0.height/2,sz0.width,sz0.height);
                Mat tmp = bgr(r);
                tmp.copyTo(bgr);
            }
            break;
        }
    }

    if (bBoard && bStylus)
    {
        bufP3f.add(transformStylusTip2local()); //  add current p3f to the buffer
        
        if (pStylus->isWriting()) //pStylus->anchorIds[0] == stylus_ids[0])   // case of writing stylus
            procWritingStylus(bgr);  // 3. && 4. wring stylus
        else{
            cv::Rodrigues(pSkiBoard->rvec,CamIO::camRotMat);
            procReadingStylus(bgr);  // 5. && 6. reading stylus
        }

    }
//    else                                        //  add a random p3f to the buffer
//        bufP3f.add(Point3f(0.01f*rand()/RAND_MAX,0.01f*rand()/RAND_MAX,0.01f*rand()/RAND_MAX));
    
    // set roubust iState
    bool b = bufInt.tryAdd(iState);
    //cout<<"b, iState = "<<b<<", "<<iState<<endl;
    setRobustState();
    //
    // write PFS
    auto t = chrono::system_clock::now();
    long dt = chrono::duration_cast<chrono::milliseconds>(t - time_point).count();
    std::stringstream s;
    s << "FPS = " << std::setprecision(3) << 1000/dt;
    cv::putText(bgr, s.str(), Point(200,60), FONT_HERSHEY_DUPLEX, 1.0, Scalar(250,0,0));
    time_point = t;
}

void CamIO::setRobustState(){
    bufInt.getValidRange(500); //milli seconds
    if (!bufInt.setHisto()) return;  // no data in bufInt
    
    if (bufInt.histo[0] + bufInt.histo[1] >0.8){
        if (bufInt.histo[0] > bufInt.histo[1]) iState = 0;
        else iState = 1;
        return;
    }
    float h23 = bufInt.histo[2] + bufInt.histo[3];
    float h45 = bufInt.histo[4] + bufInt.histo[5];
    if (h23>h45){
        if (bufInt.histo[2] > bufInt.histo[3])
            iState = 2;
        else
            iState = 3;
    }
    else{
        if (bufInt.histo[4] > 0.33*bufInt.histo[5])
            iState = 4;
        else{
            iState = 5;
            if (obj.getDistMin()>10.0){
                stateString = "1.01_1.01"; // no hotspot
            } else{
                stringstream ss;
                ss<<obj.getDistMin();
                ss<<"_"<<obj.nearestErrP3f.x<<"_"<<obj.nearestErrP3f.y<<"_"<<obj.nearestErrP3f.z;
                stateString = ss.str();
            }
            cout<<"iState = 5, stateString = "+stateString<<endl;
        }
    }
}

void CamIO::procWritingStylus(Mat& bgr){
    bufP3f.getValidRange(1000); //milli seconds
    bufP3f.setCentroid();

    if (bufP3f.isNotMoving(0.01)) { //dMaxTol, in meter
        //3. writing stylus is steay
//        cout<<"bufP3f.kStart, kEnd = "<<bufP3f.kStart<<", "<<bufP3f.kStart<<endl;
//        cout<<"bufP3f.centroid = "<<bufP3f.centroid<<endl;
        stringstream ss("hotspot: ");
        ss<<setprecision(3)<<bufP3f.centroid.x<<"_";
        ss<<setprecision(3)<<bufP3f.centroid.y<<"_";
        ss<<setprecision(3)<<bufP3f.centroid.z;
        stateString = ss.str();
        iState = 2;
    }
    else  //4. writing stylus is moving
        iState = 3;    
}

void CamIO::procReadingStylus(Mat& bgr){
    float tol = 0.01; // meter
    if (audioGuidance){
        if (trySelectRegion(tol))
            det.update(obj.current);
        else
            det.update(-1);
    } else{
        Mat rMat;
        Rodrigues(pSkiBoard->rvec,rMat);
        pair<int,float> out = obj.getNearest(transformStylusTip2local(),rMat,0.5);
        if (out.first == -1 || out.second > tol)
            det.update(-1);
        else
            det.update(out.first);
    }
    
    if (det.iDet>=0 )  //5.  reading stylus is at a hot spot
    {
        iState = 4;
        stateString = obj.vRegion[det.iDet].name + ",------,"+ obj.vRegion[det.iDet].description;
    }
    else  //6. reading stylus is moving
        iState = 5;
    
    obj.draw(bgr, pSkiBoard->rvec, pSkiBoard->tvec, camMatrix, distCoeffs);
}
