#include <string>
#include <cmath>


#include "util.h"

using namespace std; 
using namespace cv;

void rotate(vector<Point3f> &vP3f, const Vec3f &rvec){
    Mat rMat;
    Rodrigues(rvec, rMat);
    for (int i=0; i<vP3f.size(); i++){
		Matx31f out = Matx33f(rMat)*Matx31f(vP3f[i]);     
        vP3f[i].x =out(0,0);
        vP3f[i].y =out(1,0);
        vP3f[i].z =out(2,0);
    }
}



bool setCameraCalib(std::string calibStr, cv::Mat &camMatrix,cv::Mat &distCoeffs) {

    replaceAll(calibStr, "x", " ");
    replaceAll(calibStr, ";", ",");
    replaceAll(calibStr, ",", " ");

    stringstream ss;
    ss << calibStr;
    string s_imSize, s_camMatrix, s_distCoefs;
    vector<double> imSize, camMat, distCoefs;

    getOneGroup(ss, s_imSize);
    getOneGroup(ss, s_camMatrix);
    getOneGroup(ss, s_distCoefs);

    getVector<double>(s_imSize, imSize, 2);
    getVector<double>(s_camMatrix, camMat, 9);
    getVector<double>(s_distCoefs, distCoefs, 5);

    Mat_<double> cam(3, 3), coef(1, 5);
    vec2mat<double>(cam.begin(), camMat);
    vec2mat<double>(coef.begin(), distCoefs);
    cout << "cam = \n" << cam << endl;
    cout << "coef = \n" << coef << endl;
    cam.copyTo(camMatrix);
    coef.copyTo(distCoeffs);
    return true;
}

bool replace(string &input, const string &to_be_replaced, const string &replacing ){
    int pos = (int)input.find(to_be_replaced);
    if (pos==-1) return false;
    input.replace(pos,to_be_replaced.size(), replacing);
    return true;
}

void replaceAll(string &input, const string &to_be_replaced, const string &replacing ){
    while (replace(input,to_be_replaced,replacing ))
        ;
}
void getOneGroup(stringstream &ss, string &out, char cStart, char cEnd){
    string jnk;
    getline(ss, jnk, cStart);
    getline(ss, out, cEnd);
}


vector<int> getAllPos(const string s, string tok){
    vector<int> out;
    int pos = -1;
    while (true){
        pos = (int)s.find(tok,pos+1);
        if (pos==-1) break;
        out.push_back(pos);
        //        cout<<"pos = "<<pos<<endl;
    }
    return out;
}

vector<string> getAllGroup(string s, string tokStart, string tokEnd){
    vector<string> out;
    vector<int> iStart = getAllPos(s,tokStart);
    vector<int> iEnd = getAllPos(s,tokEnd);
    if (iStart.size()!=iEnd.size()) return out;
    for (int i=0; i<iStart.size(); i++){
        if (iStart[i]>=iEnd[i]) return out;
        string line = s.substr(iStart[i],iEnd[i]-iStart[i]+1);
        //        cout<<"iStart[i], iEnd[i], line = "<<iStart[i]<<", "<<iEnd[i]<<", "<<line<<endl;
        cout<<"line = "<<line<<endl;
        out.push_back(line);
    }
    
    return out;
}
void pointToVec3f(const Point3f &p3f, Vec3f &v3f){
    v3f[0] = p3f.x;
    v3f[1] = p3f.y;
    v3f[2] = p3f.z;
}
void toCamera(const Matx33f &rMat, const Vec3f &tvec, Vec3f &v3f){
    Matx31f tmp = rMat*Matx31f(v3f);
    v3f[0] = tmp(0,0) + tvec[0];
    v3f[1] = tmp(1,0) + tvec[1];
    v3f[2] = tmp(2,0) + tvec[2];
};



//
//https://stackoverflow.com/questions/25829143/trim-whitespace-from-a-string
//


std::string & ltrim(std::string & str)
{
	auto it = std::find_if(str.begin(), str.end(), [](char c) {return !std::isspace(c); });
	str.erase(str.begin(), it);
	return str;
}

std::string & rtrim(std::string & str)
{
	auto it = std::find_if(str.rbegin(), str.rend(), [](char c) {return !std::isspace(c); });
	str.erase(it.base(), str.end());
	return str;
}


string getTestString(string fn) {
	string s0;
	string line;
	ifstream myfile(fn);
	if (!myfile.is_open()) {
		cout << "Unable to open file";
		return "error!!!";
	}
	while (getline(myfile, line))
		s0 += line + '\n';
	myfile.close();
	return s0;
}

float dist2(const Point3f &p1, const Point3f &p2){
    float dx = p1.x - p2.x;
    float dy = p1.y - p2.y;
    float dz = p1.z - p2.z;
    return dx*dx + dy*dy + dz*dz;
}
float dist(const Point3f &p1, const Point3f &p2){return sqrt(dist2(p1,p2));}



void RingBufP3f::setCentroid(){
    centroid = Point3f(0,0,0);
    for (int k=kStart,i=0; i<nDat; k--,i++){
        centroid += vDat[k%capacity].data;
//            cout<<"k, sum = "<<k<<", "<<centroid<<endl;
    }
    centroid *= 1.0/nDat;
}

float RingBufP3f::getMaxDist2(){
    float d2Max = 0;
     for (int k=kStart,i=0; i<nDat; k--,i++){
        float d2 = dist2(centroid,vDat[k%capacity].data);
        d2Max = fmax(d2Max,d2);
    }
    return d2Max;
}

bool RingBufP3f::isNotMoving(float dTol ){
    bool b = getMaxDist2()<dTol*dTol;
//    if (b){
//        cout<<"nDat = "<<nDat<<endl;
//    }
    if (nDat<5) return false;
    return b;
}

void RingBufP3f::setTestData1(int nDat, int sleepMilli){
    for (int i=0; i<nDat; i++){
        float x= 0.01*((float) rand() / (RAND_MAX));
        float y= 0.01*((float) rand() / (RAND_MAX));
        float z= 0.01*((float) rand() / (RAND_MAX));
        add(Point3f(x,y,z));
        std::this_thread::sleep_for (std::chrono::milliseconds(sleepMilli));
    }
}

void RingBufP3f::test0(){
    RingBufP3f rBufP3f(999);
    rBufP3f.setTestData1();
    rBufP3f.getValidRange(99);
    rBufP3f.setCentroid();
    bool b = rBufP3f.isNotMoving(0.02);
    cout<<"RingBufP3f::test0(), b = "<<b<<endl;
}

bool RingBufInt::setHisto(){
    if (kStart==-1) return false;
    for (int i=0; i<=iMax-iMin; i++)
        histo[i]=0;
    float sm = 0.;
    for (int k=kStart,i=0; i<nDat; k--,i++){
        int iBin = vDat[k%capacity].data - iMin;
        histo[iBin] += 1.0;
        sm += 1.0;
    }
    //cout<<"setHisto(), nDat = "<<nDat<<endl;
    for (int i=0; i<=iMax-iMin; i++)
        histo[i] /= sm + 0.0001;
    
    return true;
}

bool ConvexHullGiftWrapping::tryAddData(int id_, const Point2f &p){
    for (auto pair: vPair)
        if (id_== pair.first)
            return false;
    vPair.push_back(std::pair<int,Point2f>(id_,p));
    return true;
}

bool ConvexHullGiftWrapping::findLeft(){
    if (vPair.size()==0) return false;
    auto left = vPair[0];
    for (int i=1; i<vPair.size(); i++)
        if (vPair[i].second.x < left.second.x)
            left = vPair[i];
    convexHull.clear();
    
    // pad the helper point above, to be removed when finished
    Point2f p0(left.second.x,left.second.y+1);
    convexHull.push_back(std::pair<int,Point2f>(-1,p0));
    convexHull.push_back(left);
    return true;
}

bool ConvexHullGiftWrapping::findNext(){
    if (vPair.size()<2) return false;
    int indx = -1;
    float csMin = 1.01;
    auto cur = convexHull.rbegin();
    auto prev = cur+1;
    if (convexHull.size()>2 && cur->first == convexHull[1].first){  //finished
        convexHull.erase(convexHull.begin());  // the helper point is removed
        return false;
    }
    for (int i=0; i<vPair.size(); i++){
        float cs =cosine(prev->second,cur->second,vPair[i].second);
        if (cs<csMin){
            csMin = cs;
            indx = i;
        }
    }
    //cout<<vPair[indx].first<<", "<<vPair[indx].second<<endl;
    convexHull.push_back(vPair[indx]);
    return true;
}

void ConvexHullGiftWrapping::removePointsClose2Line(float tol){
    Point2f *prev, *next;
    for (int i=0; i<convexHull.size(); ){
        if (i==0)
            prev = &convexHull.rbegin()->second;
        else
            prev = &convexHull[i-1].second;
        
        if (i==convexHull.size()-1)
            next = &convexHull.begin()->second;
        else
            next = &convexHull[i+1].second;
        
        float cs =cosine(*prev,convexHull[i].second,*next);
        if (cs<tol) convexHull.erase(convexHull.begin()+i);
        else i++;
    }
}

void ConvexHullGiftWrapping::test0(){
       ConvexHullGiftWrapping ch;
       ch.tryAddData(0, Point2f(0,0));
       ch.tryAddData(1, Point2f(1,1));
       ch.tryAddData(2, Point2f(2,1.5));
       ch.tryAddData(3, Point2f(3,2));
       ch.tryAddData(4, Point2f(2,1));
       ch.tryAddData(5, Point2f(0,1));
       
       ch.findLeft();
       while(ch.findNext())
           ;
   }
