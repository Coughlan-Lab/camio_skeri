//
//  markerArray.hpp
//  CamIO4iOS
//
//  Created by Huiying Shen on 9/11/18.
//  Copyright © 2018 Huiying Shen. All rights reserved.
//

#ifndef markerArray_hpp
#define markerArray_hpp



#include <iostream>
#include <string>
#include <opencv2/opencv.hpp>
#include <opencv2/aruco/charuco.hpp>
#include <opencv2/aruco.hpp>
#include "util.h"

using namespace std;
using namespace cv;


struct Marker3d{
    int id_;
    float length;
    vector<Point3f> vP3f;
    Marker3d(int id_=0, float length=2.0){
        init(id_,length);
    }
    
    void init(int id_, float length){
        this->id_= id_;
        this->length = length;
        vP3f.resize(4);
        float sz = length/2.0;
        vP3f[0] = Point3f(-sz,sz,0);
        vP3f[1] = Point3f(sz,sz,0);
        vP3f[2] = Point3f(sz,-sz,0);
        vP3f[3] = Point3f(-sz,-sz,0);
    }
    void translate(const Point3f &p){
        for (int i=0; i<4; i++)
            vP3f[i] += p;
    }
    void rotateX(float angle){
        Vec3f rvec(angle/180.0*3.1415926,0,0);
        ::rotate(vP3f,rvec);
    }
    void rotateY(float angle){
        Vec3f rvec(0,angle/180.0*3.1415926,0);
        ::rotate(vP3f,rvec);
    }
    void rotateZ90(){
        Vec3f rvec(0,0,3.1415926/2);
        ::rotate(vP3f,rvec);
    }
    friend ostream& operator<<(ostream& os, const Marker3d& m);
};

struct MarkerArray;  // forward declaration
struct Marker3dGroup{
    vector<Marker3d> vMarker3d;
    vector<Point2f> projectedPoints;

    ConvexHullGiftWrapping convexHull;
    vector<Point2f> imagePoints;
    vector<Point3f> objectPoints;
    vector<int> detectedIds;
    
    float errMean, errMax, medianDist;
    
	//Vec3f rvec, tvec;
	Mat rvec, tvec;
	void clear() { vMarker3d.clear(); }
	void push_back(const Marker3d &m3d) { vMarker3d.push_back(m3d); }
    bool detect(MarkerArray &markers, Mat &bgr,const Mat &camMatrix, const Mat &distCoeffs);
    void fillterMarkers(const MarkerArray &markers, vector<Point2f> &imagePoints, vector<Point3f> &objectPoints);
    
    bool detect(const MarkerArray &markers, const Mat &camMatrix, const Mat &distCoeffs);
    bool detect(vector<Point2f> &imagePoints, vector<Point3f> &objectPoints, const Mat &camMatrix, const Mat &distCoeffs);

	Mat tvecDiff(const Marker3dGroup &other) { return other.tvec - tvec; }
	static Mat rvecDiff0(const Vec3d &rvec0, const Vec3d &rvec1);
	Mat rvecDiff(const Marker3dGroup &other) { return rvecDiff0(rvec, other.rvec); }
    //FONT_HERSHEY_SIMPLEX, 0.5, Scalar(0, 0, 255)
    void drawDetectErrors(Mat &bgr, const cv::Point &p, int fontFace=FONT_HERSHEY_SIMPLEX, float fontScale=0.33, Scalar color=Scalar(0,255,0)){
        std::stringstream s;
        s << "reproj. err = " << std::setprecision(3) << errMean<<", "<<std::setprecision(3) << errMax;//<<", "<<std::setprecision(3) << medianDist;
        cv::putText(bgr, s.str(), p, fontFace, fontScale, color);
    }
    
    void drawProjectedPoints(Mat &bgr, Scalar color=Scalar(0,255,0)){
        for (int i=0; i<projectedPoints.size(); i++){
            cv::circle(bgr, projectedPoints[i],5,color,3);
        }
    }
    
    void drawAxis(Mat &bgr, const Mat &camMatrix, const Mat &distCoeffs, float l = 0.01){
        vector<Point3f> vP3f = {Point3f(0,0,0),};
        vector<Point2f> vP2f;
        cv::projectPoints(vP3f, rvec, tvec, camMatrix, distCoeffs, vP2f);
        float x = vP2f[0].x, y = vP2f[0].y;
        if (x<0 || y<0 || x>=bgr.size().width || y>=bgr.size().height) return;
        aruco::drawAxis(bgr, camMatrix, distCoeffs, rvec, tvec, l);
    }
    
    static float getMedianDist(const vector<Point2f> &v2f){
        Point2f centroid = Point2f(0,0);
        for (int i=0; i<v2f.size(); i++)
            centroid += v2f[i];
        centroid *= 1.0/v2f.size();
        
        vector<float> vd2;
        for (int i=0; i<v2f.size(); i++){
            Point2f tmp = centroid - v2f[i];
            vd2.push_back(tmp.dot(tmp));
        }
        std::sort(vd2.begin(), vd2.end());
        
        return sqrt(vd2[vd2.size()/2]);
    }
};

ostream& operator<<(ostream& os, const Marker3d& m);

struct ArucoObj{
    cv::Ptr<aruco::Dictionary> dictionary;
    cv::Ptr<aruco::DetectorParameters> detectionParams;
    
    float squareLength, markerLength;
    ArucoObj(aruco::PREDEFINED_DICTIONARY_NAME dictName = aruco::DICT_5X5_250):dictionary(aruco::getPredefinedDictionary(dictName)){
        detectionParams = aruco::DetectorParameters::create();
        detectionParams->cornerRefinementMethod = 2; //corner refinement, 2 -> contour
        detectionParams->adaptiveThreshWinSizeMin = 33;
        detectionParams->adaptiveThreshWinSizeMax = 53;
    }
    
    ArucoObj(cv::Ptr<aruco::Dictionary> dictionary):dictionary(dictionary){
        detectionParams = aruco::DetectorParameters::create();
        detectionParams->cornerRefinementMethod = 2; //corner refinement, 2 -> contour
        detectionParams->adaptiveThreshWinSizeMin = 33;
        detectionParams->adaptiveThreshWinSizeMax = 53;
    }
    void setParam(float squareLength, float markerLength){
        this->squareLength = squareLength;
        this->markerLength = markerLength;
    }
};

struct SingleMarker {
	int id_ = -1;
	vector< Point2f > corners;
	Vec3d rvec, tvec;
	SingleMarker() {}
	void reset() { id_ = -1; }
	SingleMarker(int id_, const vector< Point2f > &corners, const Vec3d &rvec, const Vec3d  &tvec) { 
		init(id_, corners, rvec, tvec); 
	}
	void init(int id_, const vector< Point2f > &corners, const Vec3d &rvec, const Vec3d  &tvec){
		this->id_ = id_;
		this->corners = corners;
		this->rvec = rvec;
		this->tvec = tvec;
	}
};


struct MarkerArray: public ArucoObj{
    vector< int > ids;
    vector< vector< Point2f > > corners;
    vector<Vec3d> rvecs, tvecs;
    
    
    MarkerArray(aruco::PREDEFINED_DICTIONARY_NAME dictName=aruco::DICT_5X5_250):ArucoObj(dictName){}
    MarkerArray(cv::Ptr<aruco::Dictionary> dictionary):ArucoObj(dictionary){}

    void clear(){ids.clear(); corners.clear();}
    static bool isIn(int i, const vector<int> &vi){
        for (int k: vi)
            if (i==k)
                return true;
        return false;
    }
    const vector<Point2f> *getCorner(int id_) const {
        int indx = id2Index(id_);
        if (indx !=-1 )  return &(corners[indx]);
        return 0;
    }
    int id2Index(int id_) const {
        for (int i=0; i<ids.size(); i++)
            if (id_==ids[i])
                return i;
        return -1;
    }
    int copyValidMarkers(const MarkerArray &src, const vector< int > &ids0);
    void detect(const Mat &gray){
        cv::Size imageSize = gray.size();
        vector< vector< Point2f > > rejected;
        aruco::detectMarkers(gray, dictionary, corners, ids, detectionParams, rejected);
        removeMarkerClose2ImageCorners(imageSize,corners, ids);
    }
    int removeMarkerClose2ImageCorners(const cv::Size &imageSize, vector< vector< Point2f > > &corners, vector< int > &ids);

	bool getMarkerById(int id_, SingleMarker &marker) {
		for (int i = 0; i < ids.size(); i++)
			if (id_ == ids[i]) {
				marker.init(id_, corners[i], rvecs[i], tvecs[i]);
				return true;
			}

		return false;
	}
    size_t size() const { return ids.size();}
    
    static void draw(const  vector< int > &ids, const vector<vector<Point2f> > &corners, Mat &bgr, float mult=1.0, Scalar color= Scalar(0, 255, 0));
    
    void draw(Mat &bgr, float mult=1.0, Scalar color= Scalar(127, 127, 0)){draw(ids,corners,bgr,mult,color);}
    
    void estimatePose(float markerLength,const Mat &camMatrix, const Mat &distCoeffs){
        aruco::estimatePoseSingleMarkers(corners,markerLength,camMatrix,distCoeffs,rvecs,tvecs);
    }
    static void drawXYZ(const Point3f &p3, int precision, const cv::Point &xy, Mat &bgr, int fontFace, float fontScale, const Scalar &color);
    //void drawAxis(Mat &bgr,const Mat &camMatrix, const Mat &distCoeffs, int idMin=0, int idMax=250);
    
    static void test0();
};


#endif /* markerArray_hpp */
