//
//  dowelStylus.hpp
//  helloAgain
//
//  Created by Huiying Shen on 10/10/18.
//  Copyright © 2018 Huiying Shen. All rights reserved.
//

#ifndef dowelStylus_hpp
#define dowelStylus_hpp

#include <iostream>
#include <opencv2/opencv.hpp>
#include <opencv2/aruco/charuco.hpp>
#include <opencv2/aruco.hpp>
#include <opencv2/opencv.hpp>
#include "util.h"
#include "markerArray.h"

using namespace std;
using namespace cv;

struct SimpleRingBuf{
    int cur;
    vector<Matx31f> vDat;
    SimpleRingBuf(int cap=30):cur(-1){
        vDat.resize(cap);
        for(int i=0; i<vDat.size(); i++)
            vDat[i] = 0;
    }
    void add(const Matx31f &d){
        cur = (cur+1)%vDat.size();
        vDat[cur] = d;
    }
    
    Matx31f getSmoothed(){
        Matx31f out(0,0,0);
        for (int i=0; i<vDat.size(); i++)
            out += vDat[i];
        return out*(1.0/vDat.size());
    }
};

struct DowelStylus: public ArucoObj, public Marker3dGroup{
    MarkerArray markers;
    vector<int> anchorIds;
    int nRow;
    
    SimpleRingBuf tipStore;

	Point3f tip;
    
    DowelStylus(aruco::PREDEFINED_DICTIONARY_NAME dictName = aruco::DICT_5X5_250):ArucoObj(dictName),tipStore(5){}
    void setParam(float topId, int nRow, float squareLength, float markerLength);
    void setXYZ1col(int col);
    void setXYZ() { for (int c=0; c<4; c++) setXYZ1col(c); }
    
    void resetId(int id0){
        for (int c=0; c<4; c++){
            for (int r=0; r<nRow; r++){
                int indx = c*nRow + r;
                vMarker3d[indx].id_ = anchorIds[indx] = id0 + indx;
            }
        }
    }
    bool isWriting(int id0 = 100){
        //return anchorIds[0] == id0;
        for (int i=0; i<nRow; i++)
            for (int j=0; j<detectedIds.size(); j++)
                if (anchorIds[i]==detectedIds[j])
                    return true;
        return false;
    }
//    void print1(char c){
//        cout<<c<<" = ["<<endl;
//        for (int i=0; i<vMarker3d.size(); i++)
//            for (int k=0; k<4; k++){
//                if (c=='x') cout<<vMarker3d[i].vP3f[k].x<<"\n";
//                if (c=='y') cout<<vMarker3d[i].vP3f[k].y<<"\n";
//                if (c=='z') cout<<vMarker3d[i].vP3f[k].z<<"\n";
//            }
//        cout<<"];"<<endl;
//    }
    
    void addTvec2Buffer(){ tipStore.add(Matx31f(tvec));}
	 
	Point3f transformStylusTip2local(const Marker3dGroup &base);

    void drawTip(Mat &bgr, const Mat &camMatrix, const Mat &distCoeffs,float mult=1.0);
    void drawProjected(Mat &bgr, float mult=1.0);

    friend ostream& operator<<(ostream& os, const DowelStylus& anch);
    
    static cv::Ptr<DowelStylus> create(aruco::PREDEFINED_DICTIONARY_NAME dictName = aruco::DICT_5X5_250) {
        return cv::Ptr<DowelStylus>(new DowelStylus(dictName));
    }
};

#endif /* dowelStylus_hpp */
