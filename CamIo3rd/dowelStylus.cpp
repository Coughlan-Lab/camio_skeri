//
//  dowelStylus.cpp
//  helloAgain
//
//  Created by Huiying Shen on 10/10/18.
//  Copyright © 2018 Huiying Shen. All rights reserved.
//

#include "camIoObj.h"
#include "dowelStylus.h"

//ostream& operator<<(ostream& os, const DowelStylus& a){
//    os<<"DowelStylus: "<<a.squareLength<<", "<<a.markerLength<<", "<<a.nRow<<endl;
//    for (Marker3d m: a.vMarker3d)
//        os<<m;
//    return os;
//}

void DowelStylus::setParam(float topId, int nRow, float squareLength, float markerLength){
    this->nRow = nRow;
    anchorIds.resize(nRow*4);
    for (int j=0; j<4; j++){
        for (int i=0; i<nRow; i++){
            int k = j*nRow + i;
            anchorIds[k] = topId + k;
        }
    }
    this->markerLength = markerLength;
    this->squareLength = squareLength;
}

void DowelStylus::setXYZ1col(int col){
    Marker3d m3d(anchorIds[col],markerLength);
    m3d.rotateX(90);
    m3d.translate(Point3f(0,-squareLength/2.0,-squareLength/2.0));
    
    for (int j=0; j<col; j++)
        m3d.rotateZ90();
    for (int i=0; i<nRow; i++){
        m3d.id_ = anchorIds[col*nRow+i];
        m3d.translate(Point3f(0,0,-squareLength));
        vMarker3d.push_back(m3d);
    }
}

Point3f DowelStylus::transformStylusTip2local(const Marker3dGroup &base) {
    Matx31f tSmoothed = tipStore.getSmoothed();
    Mat tmp = (Mat_<double>(3,1) << tSmoothed(0,0),tSmoothed(1,0),tSmoothed(2,0));
    //cout<<"DowelStylus::transformStylusTip2local(), t = "<<tmp;
	Mat tip2Base = tmp - base.tvec;
	Mat rMat;
	Rodrigues(base.rvec, rMat);
	rMat = rMat.t();
	Matx31f out = Matx33f(rMat)*Matx31f(tip2Base);
	return Point3f(out(0, 0), out(1, 0), out(2, 0));
}

//void DowelStylus::printTipOnScreen(const Marker3dGroup &base, Mat &bgr, const Mat &camMatrix, const Mat &distCoeffs) {
//	tip = transformStylusTip2local(base);
//	Point2f p2f = P3fProjector(tip).project(bgr, base.rvec, base.tvec, camMatrix, distCoeffs);
//	cv::putText(bgr, Region::p3fToString(tip), Point(p2f), FONT_HERSHEY_SIMPLEX, 0.5, Scalar(0, 0, 255));
//}

void DowelStylus::drawTip(Mat &bgr, const Mat &camMatrix, const Mat &distCoeffs, float mult){
//    Matx31f t(tvec);
//    Point3f p3f(t(0, 0), t(1, 0), t(2, 0));
    Matx31f tSmoothed = tipStore.getSmoothed();
    //Mat t(tSmoothed(0,0),tSmoothed(1,0),tSmoothed(2,0));
    Mat tmp = (Mat_<float>(3,1) << tSmoothed(0,0),tSmoothed(1,0),tSmoothed(2,0));
    //cout<<"DowelStylus::drawTip(), t = "<<tmp;
    Point2f p2f = P3fProjector(Point3f(0,0,0)).project(bgr, rvec, tmp, camMatrix, distCoeffs);
    cv::circle(bgr, p2f*mult, 3, Scalar(255, 255, 255),3.0);
}
void DowelStylus::drawProjected(Mat &bgr, float mult){
    for (int i=0; i<projectedPoints.size(); i+=4){
        for (int k=0; k<4; k++){
            Point p1(projectedPoints[i+k]*mult);
            Point p2(projectedPoints[i+(k+1)%4]*mult);
            cv::line(bgr, p1, p2, Scalar(128, 0, 255),2,4);
        }
    }
}
