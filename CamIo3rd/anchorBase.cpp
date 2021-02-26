//
//  anchorCube.cpp
//  helloAgain
//
//  Created by Huiying Shen on 10/2/18.
//  Copyright © 2018 Huiying Shen. All rights reserved.
//

#include <iostream>
#include <opencv2/opencv.hpp>
#include <opencv2/aruco/charuco.hpp>
#include <opencv2/aruco.hpp>
#include <opencv2/opencv.hpp>
#include "util.h"
#include "markerArray.h"
#include "anchorBase.h"

using namespace std;
using namespace cv;



ostream& operator<<(ostream& os, const Marker3d& m)
{
    os << m.id_<<", "<<m.length<<endl;
    for (int i=0; i<m.vP3f.size(); i++)
        os<<m.vP3f[i]<<endl;
    
    return os;
}

void RectBase::setMarker3ds(){
    vMarker3d.clear();
    //lower, left
    Marker3d m(id1st, markerLength);
    push_back(m);
    //lower, right
    m.init(id1st + 1, markerLength);
    m.translate(Point3f(dx, 0, 0));
    push_back(m);
    //upper,right
    m.init(id1st + 2, markerLength);
    m.translate(Point3f(dx, dy, 0));
    push_back(m);
    //upper,left
    m.init(id1st + 3, markerLength);
    m.translate(Point3f(0, dy, 0));
    push_back(m);
    
    //lower
    m.init(id1st + 4, markerLength);
    m.translate(Point3f(dx/2, 0, 0));
    push_back(m);
    //right
    m.init(id1st + 5, markerLength);
    m.translate(Point3f(dx/2, dy/2, 0));
    push_back(m);
    //upper
    m.init(id1st + 6, markerLength);
    m.translate(Point3f(dx/2, dy, 0));
    push_back(m);
    //left
    m.init(id1st + 7, markerLength);
    m.translate(Point3f(0, dy/2, 0));
    push_back(m);
}

void SkiBoard::setMarker3ds(){
    vMarker3d.clear();
    for (int iy=0; iy<ny; iy++){
        float y = iy*(markerLength + gap);
        for (int ix=0; ix<nx; ix++){
            float x = ix*(markerLength + gap);
            Marker3d m(anchorIds[iy*nx + ix], markerLength);
            m.translate(Point3f(x, y, 0));
            push_back(m);
        }
    }
}

void SkiBoard::draw(Mat &bgr, float mult,Scalar color) const {
    if (convexHull.convexHull.size()==0 || imagePoints.size()==0) return;
    vector<vector<Point2f> > vc;
    vc.resize(imagePoints.size()/4);
    for (int i=0; i<vc.size(); i++){
        vc[i].resize(4);
        for (int j=0; j<4; j++){
            //cout<<"i, j = "<<i<<", "<<j<<endl;
            vc[i][j] = imagePoints[i*4+j]*mult;
        }
    }
    
    aruco::drawDetectedMarkers(bgr, vc,noArray(),color);

    for (int k=0; k<convexHull.convexHull.size(); k++){
        std::stringstream s;
        s << convexHull.convexHull[k].first;
        int x = convexHull.convexHull[k].second.x, y = convexHull.convexHull[k].second.y;
        cv::putText(bgr, s.str(), cv::Point(x, y), FONT_HERSHEY_SIMPLEX, 0.5, color);
    }
}
    
bool CamCalib::tryAddFrame(const Mat &gray){
    markerArray.detect(gray);
    vector<Point2f> imagePoints;
    vector<Point3f> objectPoints;
    board.fillterMarkers(markerArray, imagePoints, objectPoints);
     
    if (imagePoints.size()<16) return false;
    vImagePoints.push_back(imagePoints);
    vObjectPoints.push_back(objectPoints);
    size = gray.size();
    return true;
}

string CamCalib::calib(){
    int flags = CALIB_FIX_PRINCIPAL_POINT|CALIB_FIX_ASPECT_RATIO|CALIB_ZERO_TANGENT_DIST;
    //TermCriteria criteria = TermCriteria(TermCriteria::COUNT + TermCriteria::EPS, 30, DBL_EPSILON);
    
    calibrateCamera(vObjectPoints, vImagePoints, size, camMatrix, distCoeffs, rvecs, tvecs,flags);
    int nCorners = 0;
    float errSum = 0, errMax = 0;
    for (int i=0; i<vImagePoints.size(); i++){
        getReprojErrorOneFrame(vImagePoints[i],vObjectPoints[i],rvecs[i],tvecs[i],errSum,errMax);
        nCorners += vObjectPoints[i].size();
    }
    
    cout<<"errMean, errMax = "<<errSum/nCorners<<", "<<errMax<<endl;
    stringstream ss;
    ss<<"errMean, errMax = "<<errSum/nCorners<<", "<<errMax<<endl;
    ss<<"imgSize = "<<size<<endl;
    ss<<"camMatrix = "<<camMatrix<<endl;
    ss<<"distCoeffs ="<<distCoeffs<<endl;
    return ss.str();
}

void CamCalib::getReprojErrorOneFrame(const vector<Point2f> &imagePoints, const vector<Point3f> &objectPoints, const Mat &rvec, const Mat &tvec, float &errSum, float &errMax){
    
    vector<Point2f> projectedPoints;
    cv::projectPoints(objectPoints, rvec, tvec, camMatrix, distCoeffs, projectedPoints);

    for (int i=0; i<imagePoints.size(); i++){
        float err = cv::norm(imagePoints[i] - projectedPoints[i]);
        errSum += err;
        errMax = std::fmax(err,errMax);
    }
}
