#ifndef __ANCHORCUBE__
#define __ANCHORCUBE__

#include <iostream>
#include <opencv2/opencv.hpp>
#include <opencv2/aruco/charuco.hpp>
#include <opencv2/aruco.hpp>
#include <opencv2/opencv.hpp>
#include "util.h"
#include "markerArray.h"

using namespace std;
using namespace cv;

struct BaseObject : public Marker3dGroup{
    int id1st;
    float markerLength;
    
	MarkerArray markers;
	vector<int> anchorIds;
    
	BaseObject(aruco::PREDEFINED_DICTIONARY_NAME dictName = aruco::DICT_5X5_250) :markers(dictName) {}
	void setIds(int nIds) {
		anchorIds.resize(nIds);  
		for (int i = 0; i < nIds; i++)
			anchorIds[i] = id1st + i;
	}
    
    void setParams(int id1st, float markerLength) {
        this->id1st = id1st;
        this->markerLength = markerLength;
    }
    
    virtual void setMarker3ds() = 0;
    
};

struct RectBase : public BaseObject {
    float dx, dy;
	RectBase(aruco::PREDEFINED_DICTIONARY_NAME dictName = aruco::DICT_5X5_250) :BaseObject(dictName) {}

    void setParams(int id1st, float markerLength, float dx, float dy){
        BaseObject::setParams(id1st,markerLength);
        this->dx = dx;
        this->dy = dy;
    }
    
    void setMarker3ds();
	void setMarker3ds(int id1st, float markerLength, float dx, float dy){
        setParams(id1st,markerLength,dx,dy);
        setIds(8);
        setMarker3ds();
    }

	static cv::Ptr<RectBase> create(aruco::PREDEFINED_DICTIONARY_NAME dictName = aruco::DICT_5X5_250) {
		return cv::Ptr<RectBase>(new RectBase(dictName));
	}
};

struct SkiBoard: public BaseObject {
    float gap;
    int nx, ny;
    
    
    SkiBoard(aruco::PREDEFINED_DICTIONARY_NAME dictName = aruco::DICT_5X5_250) :BaseObject(dictName) {}
    void setParams(int id1st, float markerLength, float gap, int nx, int ny){
        BaseObject::setParams(id1st,markerLength);
        this->gap = gap;
        this->nx = nx;
        this->ny = ny;
    }
    void setMarker3ds();
    void setMarker3ds(int id1st, float markerLength, float gap2markerLength=0.2, int nx=8, int ny=12){
        setParams(id1st,markerLength,markerLength*gap2markerLength, nx, ny);
        setIds(nx*ny);
        setMarker3ds();
    }
    
    void draw(Mat &bgr, float mult=1.0,Scalar color= Scalar(0, 0, 255)) const;
    static cv::Ptr<SkiBoard> create(aruco::PREDEFINED_DICTIONARY_NAME dictName = aruco::DICT_5X5_250) {
        return cv::Ptr<SkiBoard>(new SkiBoard(dictName));
    }
};
 
struct CamCalib{
    SkiBoard board;
    MarkerArray markerArray;
    
    vector<vector<Point2f> > vImagePoints;
    vector<vector<Point3f> > vObjectPoints;
    vector<Mat> rvecs;
    vector<Mat> tvecs;
    
    Mat camMatrix;
    Mat distCoeffs;
    cv::Size size;
    
    CamCalib(aruco::PREDEFINED_DICTIONARY_NAME dictName = aruco::DICT_5X5_250):board(dictName),markerArray(dictName){
        board.setMarker3ds(0,0.0215);
    }
    
    void clear(){vImagePoints.clear(); vObjectPoints.clear();}
    
    bool tryAddFrame(const Mat &gray);
    
    string calib();
    
    void getReprojErrorOneFrame(const vector<Point2f> &imagePoints, const vector<Point3f> &objectPoints, const Mat &rvec, const Mat &tvec, float &errSum, float &errMax);
};

#endif

