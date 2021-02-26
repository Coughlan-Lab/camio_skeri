//
//  OpenCvWrapper.m
//  CamIo3rd
//
//  Created by Huiying Shen on 2/15/19.
//  Copyright © 2019 Huiying Shen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#import "OpenCvWrapper.h"
#import "markerArray.h"
#import "camio.h"

using namespace std;
using namespace cv;

@interface CamIoWrapper()
@property CamIO *camio;
@end


@implementation CamIoWrapper
- (id) init {
    if (self = [super init]) {
        aruco::PREDEFINED_DICTIONARY_NAME dictName = aruco::DICT_5X5_250;
        self.camio = new CamIO(dictName);
    } return self;
}

- (void) dealloc {
    delete self.camio;
}

- (void) clear {
    self.camio->clear();
}

- (void)newRegion:(NSString*)s
{
    self.camio->newRegionWithXyz(string([s cStringUsingEncoding:NSUTF8StringEncoding]));
}


- (bool)setCameraCalib:(NSString*)calibStr
{
    return self.camio->setIntrinsic(string([calibStr cStringUsingEncoding:NSUTF8StringEncoding]));
}

-(bool) setCurrentNameDescription:(NSString*)name with:(NSString*)description
{
    return self.camio->setCurrentNameDescription(string([name cStringUsingEncoding:NSUTF8StringEncoding]),
                                                 string([description cStringUsingEncoding:NSUTF8StringEncoding]));
}
-(void) setCurrent:(int) i
{
    self.camio->setCurrent(i);
}
-(void) setAudioGuidance:(bool) b
{
    self.camio->setAudioGuidance(b);
}
//- (void ) setRectBase:(int)id1st markerLengthInMeter:(float)l rWidth2markerLength:(float)nx rHeight2markerLength:(float)ny {
//    self.camio->setRectBase(id1st,l,nx,ny);
//}

//- (NSString*) getRectBaseString
//{
//    return [NSString stringWithCString:self.camio->getSkiBoardString().c_str() encoding:NSUTF8StringEncoding];
//}

- (void)loadModel:(NSString*)modelJson
{
    self.camio->loadModel(string([modelJson cStringUsingEncoding:NSUTF8StringEncoding]));
}

- (NSString*) getModelString
{
    return [NSString stringWithCString:self.camio->getObjJson().c_str() encoding:NSUTF8StringEncoding];
}

- (NSString*) getCurrentNameDescription
{
    return [NSString stringWithCString:self.camio->getCurrentNameDescription().c_str() encoding:NSUTF8StringEncoding];
}

-(void) initCalib{
    self.camio->initCalib();
}

- (NSString*) doCalib{
    return [NSString stringWithCString:self.camio->doCalib().c_str() encoding:NSUTF8StringEncoding];
}
- (bool)isCameraCovered{
    return self.camio->isCameraCovered();
}
-(bool) tryAdd4Calib: (UIImage *) image {
    Mat rgba,gray;
    UIImageToMat(image, rgba);
    cvtColor(rgba, gray, CV_RGBA2GRAY);
    return self.camio->tryAddImage4Calib(gray);
}

-(UIImage *) procImage: (UIImage *) image {
    Mat rgba,bgr;
    UIImageToMat(image, rgba);
    cvtColor(rgba, bgr, CV_RGBA2BGR);
    
    self.camio->do1timeStep(bgr);
    
    cvtColor(bgr, rgba, CV_BGR2RGBA);
    return MatToUIImage(rgba);
}
- (NSString*) getState
{
    return [NSString stringWithCString:self.camio->getState().c_str() encoding:NSUTF8StringEncoding];
}

-(NSString*) getRegionNames
{
    return [NSString stringWithCString:self.camio->getRegionNames().c_str() encoding:NSUTF8StringEncoding];
}

- (int) getStateIdx
{
    return self.camio->iState;
}

-(bool) isNewRegion {
    return self.camio->isNewRegion();
}
-(bool) isExploring{
    return self.camio->isExploring();
}
-(bool) locationCaptured{
    return self.camio->locationCaptured();
}

-(void) setNewRegion {
    self.camio->setNewRegion();
}
-(void) setAdd2Region {
    self.camio->setAdd2Region();
}
-(void) setSelectRegion {
    self.camio->setSelectRegion();
}
-(void) deleteCurrentRegion{
    self.camio->deleteCurrentRegion();
}
-(bool) isActionDone{
    return self.camio->isActionDone();
}
-(bool) isStylusVisible{
    return self.camio->isStylusVisible();
}
-(int) getCurrentRegion{
    return self.camio->getCurrentRegion();
}
@end
