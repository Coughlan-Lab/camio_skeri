/*
 * camIoObj.h
 *
 *  Created on: Mar 13, 2018
 *      Author: huiying
 */

#ifndef CAMIOOBJ_H_
#define CAMIOOBJ_H_

#include <chrono>
#include <thread>
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/opencv.hpp>

#include "util.h"
#include "markerArray.h"
#include "dowelStylus.h"
#include "anchorBase.h"

using namespace std;
using namespace cv;



struct P3fProjector {
	Point3f p3f;
	P3fProjector(const Point3f &p3f) :p3f(p3f) {}
	Point2f project(Mat &bgr, const Mat &rvec, const Mat &tvec, const Mat &camMatrix, const Mat &distCoeffs);
};

struct Region{
	vector<Point3f> vP3f;
    vector<Point3f> vP3fCam;
    //int iNearest;
    std::pair<int,float> nearest;
    Point3f nearestErrP3f;
    float dist2Stylus;
    
    string name = "name";
	string description = "description";

    Region():dist2Stylus(999),nearest({-1,999.0}){}
	Region(const Point3f &p3f):dist2Stylus(999),nearest({-1,999.0}){vP3f.push_back(p3f);}
    
    void setNameDescription(const string &name, const string &description){
        this->name = "" + name;
        this->description = ""+description;
    }
    
    string getNameDescription(){
        return name + "------" + description;
    }

	static string f2s(float f, int precision = 3) {
		stringstream ss;
		ss << setprecision(precision) << f;
		return ss.str();
	}
	static string nameAndValToJson(const string &name, float val) {
		return '\"' + name + "\": " + f2s(val);
	}
	static string nameAndValToJson(const string &name, string val) {
		return '\"' + name + "\": " + '\"' + val+ '\"';
	}
	static string toJson(const Point3f &f) {
		return  nameAndValToJson("x", f.x) + ", "
			  + nameAndValToJson("y", f.y) + ", "
			  + nameAndValToJson("z", f.z);
	}
	 
	static string toJson(const vector<Point3f> &vP3f) {
		string o;
        for (int i=0; i<vP3f.size(); i++){
            const Point3f &p = vP3f[i];
            o += '{' + toJson(p) +'}';
            if (i < vP3f.size()-1)
                o += ',';
            o += '\n';
        }
		return o;
	}

	string toJson() {
		string o("{");
		o += nameAndValToJson("name", name) + ",\n";
		o += nameAndValToJson("description", description) + ",\n";
		o += "\"vPoint3f\": [\n" + toJson(vP3f) + "]\n}\n";
		return o;
	}

	void addPoint(const Point3f &p3f) { vP3f.push_back(p3f); }
	void setNearest(const Point3f &p3f, const Mat &rMat, float zScale);

	static string p3fToString(const Point3f &p3f, int precision=3) {
		std::stringstream s;
		s << std::setprecision(precision) << p3f.x << ", ";
		s << std::setprecision(precision) << p3f.y << ", ";
		s << std::setprecision(precision) << p3f.z;
		return s.str();
	}

	void draw(Mat &bgr, const Vec3f &rvec, const Vec3f &tvec, const Mat &camMatrix, const Mat &distCoeffs,
		Scalar color = Scalar(255, 255, 0),int thickness = 3) const;

    static float dist(const Point3f & p1, const Point3f &p2, Mat rMat = (Mat_<float>(3,3) << 1,0,0,0,1,0,0,0,1), float zScale = 1.0);

	bool tryInit(string &s) {
		return trySetOneString("name", name, s)
			&& trySetOneString("description", description, s)
			&& getAllPoint3f(s) > 0;
	}

	static bool tryInitPoint3f(const string &s, Point3f &p) {
		vector<string> vs = parseVar(s);
		return trySetP3fXyz(vs, p);
	}

	static bool trySetP3fXyz(const vector<string> &vs, Point3f &p);

	template<typename T>
	static bool trySetOneFloat(const string &name, T &val, const string &sIn) {
		long pos = sIn.find('\"' + name + '\"');
		if (pos == -1) return false;
		pos = sIn.find_first_of(':');
		if (pos == -1) return false;
		stringstream ss(sIn.substr(pos + 1));
		ss >> val;
		return true;
	}

	static vector<string> parseVar(string s);
	static bool trySetOneString(const string &name, string &val, string &sIn);
	static string getOneVecPoint3f(string &s);
	static string getOnePoint3f(string &s);
	int getAllPoint3f(string &s);

	static void test0() {
		string s = "\
			{	name: \"mountain top\",\
				description: \"the mountain top is covered by snow\", \
			";
	}
};



struct SmoothedDetection{
    
    struct Detection{
        int val;
        chrono::time_point<chrono::system_clock> time_point = chrono::system_clock::now();
        Detection(int val=-1):val(val){
            time_point = chrono::system_clock::now();
        }
        long timeDiffMilli(const Detection &other){
            return chrono::duration_cast<chrono::milliseconds>(time_point - other.time_point).count();
        }
    };
    
    vector<Detection> vDet;
    int cur;
    int iDet = -1;
    SmoothedDetection(int sz=60):cur(-1){vDet.resize(sz);}
    void addNew(int val){
        cur = (cur+1)%vDet.size();
        vDet[cur] = Detection(val);
    }
    
    void update(int newVal){
        addNew(newVal);
        iDet = getMostCommon();
        
//        if (h.get_fMostComm() < 0.33)   // most common state is less than half of the total
//            iDet = -1;
    }
    
    HistoT<int> h;
    int getMostCommon(long dtMilli=300 /* millisec */){
        h.reset();
        for (unsigned int i=0; i<vDet.size(); i++){
//            long milli = vDet[cur].timeDiffMilli(vDet[i]);
            //cout<<"milli = "<<milli<<endl;
            if (vDet[cur].timeDiffMilli(vDet[i]) < dtMilli)
                h.add(vDet[i].val);
            //cout<<"millisec = "<<vDet[cur].timeDiffMilli(vDet[i])<<endl;
        }
        return h.getMostCommon();
    }
    int getCntMax(){return h.getCntMax();}
    float get_fMostComm(){return h.get_fMostComm();}
    
    static void test0(){
        SmoothedDetection smDet(12);
        int vv[20] = {1,2,2,4,5, 5,4,3,3,4, 4,3,1,3,5, 4,3,4};
        for (int i=0; i<15; i++){
            smDet.addNew(vv[i]);
            std::this_thread::sleep_for (std::chrono::milliseconds(9));
        }
        cout<<smDet.getMostCommon()<<endl;
        cout<<smDet.getCntMax()<<endl;
        cout<<smDet.get_fMostComm()<<endl;
    }
    
};

struct Obj {
	string name;
	string description;
	vector<Region> vRegion;

//    int iNearest = -1;
	int current = -1;
    bool isCurrentClose = false;
    Point3f nearestErrP3f;

    Obj():name("name_"),description("des_"){}
	void clear() { vRegion.clear(); current = -1;}

	bool add2Region(const Point3f &p3f) {
		if (current == -1) return false;
		vRegion[current].addPoint(p3f);
		return true;
	}
    
    string getRegionNames(){
        string out = "";
        for (int i=0; i<vRegion.size(); i++)
            out += vRegion[i].name + '\n';
        return out;
    }
    
    void checkReginNames(){
        for (int i=0; i<vRegion.size(); i++){
            string name = vRegion[i].name;
            int pos = name.find('?');
            if (pos==-1){
                stringstream ss;
                ss<<name<<"?hotspot"<<i;
                vRegion[i].name = ss.str();
            }else{
                int pos2 = name.find("?hotspot");
                if (pos2 != -1){
                    stringstream ss;
                    ss<<name.substr(0,pos2)<<"?hotspot"<<i;
                    vRegion[i].name = ss.str();
                }
            }
        }
    }
    
    void setCurrent(int i){
        if (i<0 || i>=vRegion.size()) return;
        current = i;
    }

	bool deleteRegion(const Point3f &p3f, float tol = 10.0);

    void newRegionWithXyz(const string &xyz){
        string tmp(xyz);
        replaceAll(tmp,"_"," ");
        Point3f p3f;
        stringstream ss(tmp);
        ss>>p3f.x;
        ss>>p3f.y;
        ss>>p3f.z;
        Region &r = addNewRegion(p3f);
        
        stringstream ss1;
        ss1<<xyz<<"?hotspot"<<current;
        string name = ss1.str();
        r.name = ss1.str();
        r.description = "recording";
    }
    
	Region &addNewRegion(const Point3f &p3f) {
		vRegion.push_back(p3f);
		current = (int)vRegion.size() - 1;
        return vRegion[current];
	}

	bool tryAdd2Region(const Point3f &p3f);
    
    bool setCurrentNameDescription(const string &name, const string &description){
        if (current==-1) return false;
        vRegion[current].setNameDescription(name,description);
        return true;
    }
    
    string getCurrentNameDescription(){
        if (current==-1) return "none";
        return vRegion[current].getNameDescription();
    }
    
    void deleteCurrentRegion(){
        if (current==-1) return;
        vRegion.erase(vRegion.begin()+current);
        current = vRegion.size()-1;
    }

	void draw(Mat &bgr, const Mat &rvec, const Mat &tvec, const Mat &camMatrix, const Mat &distCoeffs) const;
    
    pair<int,float> getNearest(const Point3d &p3f, const Mat &rMat, float zScale){
        pair<int,float> out = {-1, -1};
        if (vRegion.size() > 0){
            float dMin = 999.0;
            for (int i=0; i< vRegion.size(); i++){
                Region &r = vRegion[i];
                r.setNearest(p3f,rMat,zScale);
                if (dMin > r.nearest.second){
                    dMin = r.nearest.second;
                    out = {i,dMin};
                }
            }
        }
        return out;
    }
    
    void setNearest(const Point3d &p3f, const Mat &rMat, float zScale, float tol = 0.01f ){
    if (current == -1) return;
        
    //    float dMin = 999.0;
    //    for (int i=0; i< vRegion.size(); i++){
    //        vRegion[i].setNearest(p3f,rMat,zScale);
    //        if (dMin > vRegion[i].nearest.second){
    //            dMin = vRegion[i].nearest.second;
    //            iNearest = i;
    //            nearestErrP3f = vRegion[i].nearestErrP3f;
    //        }
    //    }
        
        vRegion[current].setNearest(p3f,rMat,zScale);
        if (vRegion[current].nearest.second < tol) isCurrentClose = true;
        else isCurrentClose = false;
        nearestErrP3f = vRegion[current].nearestErrP3f;
    }
    float getDistMin(){
        if (current == -1) return 999;
        return vRegion[current].nearest.second;
    }
//	void drawNearest(const Point3d &p3f, Mat &bgr, const Mat &rvec, const Mat &tvec, const Mat &camMatrix,
//		const Mat &distCoeffs, Scalar color = Scalar(0, 200, 0));
	bool trySelectRegion(const Point3f &p3f, const Mat &rMat, float tol = 0.01f);
	bool tryDeleteRegion(const Point3f &p3f, float tol = 0.01f);
	bool tryInit(string &s) {
        clear();
		return Region::trySetOneString("name", name, s)
			&& Region::trySetOneString("description", description, s)
			&& setAllRegions(s) > 0;
	}

	static string get_vRegion(string &s);
	int setAllRegions(string &s);

	string toJson() {
		string o = "{\n";
		o += Region::nameAndValToJson("name", name) + ",\n";
		o += Region::nameAndValToJson("description", description) + ",\n";
		o += "\"vRegion\": [\n";
        for (int i=0; i<vRegion.size(); i++){
            Region &r = vRegion[i];
            o += r.toJson();
            if (i<vRegion.size()-1)
                o += ',';
            o += '\n';
        }
		return o + "]\n}";
	}
};

#endif /* CAMIOOBJ_H_ */
