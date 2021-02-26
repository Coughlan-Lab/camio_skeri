#ifndef __UTIL_H__
#define __UTIL_H__


#include <chrono>
#include <thread>
#include <string>       // std::string
#include <iostream>     // std::cout
#include <sstream>      // std::stringstream
#include <iomanip>      // std::setw


#include <opencv2/core.hpp>
#include <opencv2/opencv.hpp>

using namespace std;
using namespace cv;


string getTestString(string fn);

std::string & ltrim(std::string & str);
std::string & rtrim(std::string & str);

void rotate(vector<Point3f> &vP3f, const Vec3f &rvec);

template<typename TPoint>
float dist2(TPoint p1, TPoint p2){
	p1 -= p2;
	return p1.dot(p1);
}

bool setCameraCalib(std::string calibStr, cv::Mat &camMatrix,cv::Mat &distCoeffs);
bool replace(string &input, const string &to_be_replaced, const string &replacing );
void replaceAll(string &input, const string &to_be_replaced, const string &replacing );
void getOneGroup(stringstream &ss, string &out, char cStart = '[', char cEnd=']');
vector<int> getAllPos(string s, string tok);
vector<string> getAllGroup(string s, string tokStart, string tokEnd);

template<class T> void getVector(const string &s, vector<T> &out, int size){
    stringstream ss0;
    ss0<<s;
    ss0<<'\n';
    out.resize(size);
    for (int i=0; i<out.size(); i++)
        ss0>>out[i];
}

float dist2(const Point3f &p1, const Point3f &p2);

template<typename T>
void vec2mat(MatIterator_<T> it, const vector<double> &vec){
    for (int i=0; i<vec.size(); i++,it++)
        *it = vec[i];
}

void pointToVec3f(const Point3f &p3f, Vec3f &v3f);
void toCamera(const Matx33f &rMat, const Vec3f &tvec, Vec3f &v3f);

template<typename T>
struct SimpleCluster{
    float tol;
    vector<T> data;
    T centroid;
    int weight() const { return data.size();}
    SimpleCluster(const T &t, float tol = 0.05):tol(tol),centroid(t){data.push_back(t);}
    
    bool tryAdd(const T &t){
        float d2 = dist2(centroid,t);
        if (d2 < tol*tol){
            float w = weight();
            centroid = w/(w+ 1.0f) * centroid + 1.0/(w + 1.0f)* t;
            data.push_back(t);
            return true;
        }
        return false;
    }
    static void add(vector<SimpleCluster> &vCluster, const T &t){
        for (int i=0; i<vCluster.size(); i++){
            if (vCluster[i].tryAdd(t))
                break;
        }
        vCluster.push_back(SimpleCluster(t));
    }
    
    static int getMaxWeight(const vector<SimpleCluster> &vCluster){
        int indx = -1, w = 0;
        for (int i=0; i<vCluster.size(); i++){
            if (vCluster[i].weight()>w){
                indx = i;
                w = vCluster[i].weight();
            }
        }
        return indx;
    }
};


template<typename T>
struct TimedData{
    T data;
    chrono::time_point<chrono::system_clock> time_point;
    long timeDiffMilli(const TimedData<T> &other) const {
        return chrono::duration_cast<chrono::milliseconds>(time_point - other.time_point).count();
    }
    TimedData():time_point (chrono::system_clock::now()){}
    TimedData(const T &data):data(data),time_point (chrono::system_clock::now()){}
};


template<typename T>
struct RingBuf{
    int capacity;
    vector<TimedData<T> > vDat;
    int kStart, nDat;
    
    RingBuf(int capacity=999):kStart(-1),capacity(capacity){
        vDat.resize(capacity);
        for (int i=0; i<capacity; i++){
            add(T());
        }
    }
    void add(const T &dat){
        kStart = (kStart+1)%capacity;
        vDat[kStart] = TimedData<T>(dat);
    }
    
    void getValidRange(long dtTolMilli) {
        const TimedData<T> &dat0 = vDat[kStart];
        nDat = 1;
        for (int k=kStart-1; nDat<=capacity; k--,nDat++){
            long dt = dat0.timeDiffMilli(vDat[k%capacity]);
            //cout<<"k, dt = "<<k<<", "<<dt<<endl;
            if (dt>dtTolMilli){
                //cout<<"k, dt = "<<k<<", "<<dt<<endl;
                return;
            }
        }
    }
    
};

struct RingBufInt: RingBuf<int>{
    int iMin, iMax;
    vector<float> histo;
    RingBufInt(int iMin=0, int iMax=5, int capacity=500):iMin(iMin),iMax(iMax),RingBuf<int>(capacity){
        histo.resize(iMax-iMin+1);
    }
    
    bool tryAdd(int dat){
        if (dat<iMin || dat>iMax) return false;
        add(dat);
        return true;
    }
    
    bool setHisto();
    
};

float dist2(const Point3f &p1, const Point3f &p2);
float dist(const Point3f &p1, const Point3f &p2);


struct RingBufP3f: RingBuf<cv::Point3f>{
    RingBufP3f(int cap=999):RingBuf<cv::Point3f>(cap){}
    Point3f centroid;
    
    void setCentroid();
    
    float getMaxDist2();
    
    bool isNotMoving(float dTol = 0.01);
    
    void setTestData1(int nDat=499, int sleepMilli=11);
    
    static void test0();
    
};

struct ConvexHullGiftWrapping{
    vector<std::pair<int,Point2f> > vPair;
    vector<std::pair<int,Point2f> > convexHull;

    void clear() {vPair.clear(); convexHull.clear();}
    bool tryAddData(int id_, const Point2f &p);
    bool findLeft();
    bool findNext();
    void removePointsClose2Line(float tol = -0.98);
    
    bool hasId(int id_){
        for (int i=0; i<convexHull.size(); i++)
            if (convexHull[i].first == id_)
                return true;
        return false;
    }
    
    static float d2(const Point2f &p1,const Point2f &p2){
        return (p1.x - p2.x)*(p1.x - p2.x) + (p1.y - p2.y)*(p1.y - p2.y);
    }
    
    static float cosine(const Point2f &prev,const Point2f &cur,const Point2f &next){
        float d2b = d2(prev,cur);
        float d2c = d2(next,cur);
        return -(d2(prev,next) - d2b - d2c)/2.0/sqrt(d2b*d2c);
    }
    
    static void test0();
};

template<class T>
struct HistoT{
    vector<T> vVal;
    vector<int> vCnt;
    int indxMax;
    float fMostComm;
    void reset(){vVal.clear(); vCnt.clear();}
    void add(const T &val){
        for (unsigned int i=0; i<vVal.size(); i++)
            if (val==vVal[i]){
                vCnt[i]++;
                return;
            }
        vVal.push_back(val);
        vCnt.push_back(1);
    }
    
    int getMostCommon(){
        if (vVal.size() == 0) {
            fMostComm = 0.1;
            return -1;
        }
        int cntMax=0;
        float sum = 0;
        for (unsigned int i=0; i<vCnt.size(); i++){
            sum += vCnt[i];
            if (cntMax<vCnt[i]){
                cntMax = vCnt[i];
                indxMax = i;
            }
        }
        fMostComm = vCnt[indxMax]/sum;
        //cout<<"getMostCommon(), sum = "<<sum<<endl;
        return vVal[indxMax];
    }
    int getCntMax(){return vCnt[indxMax];}
    float get_fMostComm(){return fMostComm;}
};

#endif
