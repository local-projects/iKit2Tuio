//
//  AppDelegate.h
//  iKit2Tuio
//
//  Created by Oriol Ferrer Mesià on 20/03/14.
//  Copyright (c) 2014 Oriol Ferrer Mesià. All rights reserved.
//

#import "TouchDataStruct.h"
#import <Cocoa/Cocoa.h>
#include "ofxTuioServer.h"
#include "HIDView.h"
#include "calibrate.h"


@interface AppDelegate : NSObject <NSApplicationDelegate>{

	@public

	IBOutlet NSTextField * hostField;
	IBOutlet NSTextField * portField;
	IBOutlet NSWindow * debugWindow;
	IBOutlet HIDView * debugView;
	IBOutlet NSPopUpButton * frameTypePopup;
	IBOutlet NSTextField * usingCalibrationField;


	NSWindow *			fullScreenWindow;
	FrameType			frameType; //the two frames I got access to behave differetly!

	bool				started;
	ofxTuioServer		server;
	TuioCursor*			cursors[MAX_TOUCHES];


	// calibration ////////////////////////////////////////////

	bool				isCalibrated; //we can run calibrated or non-calibrated

	CalibrationStep		calibrationStep;
	POINT				screenPoint[3];	//where the points are drawn on screen for user to touch
	POINT				calibPoint[3];  //raw input from the sensor of where user was asked to touch

	MATRIX				matrix; //calibration data

}

@property (assign) IBOutlet NSWindow *window;

-(void)touchesUpdated:(struct TouchData*)data;

-(IBAction)startStop:(id)sender;

-(IBAction)selectedFrameType:(id)sender;

-(IBAction)startCalibrationProcess:(id)sender;
-(IBAction)resetCalibrationData:(id)sender;

-(IBAction)nextStep:(id)sender; //debug menu

-(POINT)getCalibrated:(POINT)p;

-(void)setState:(CalibrationStep)s;

-(void)calcCalibration;

-(NSRect)getDesktop;

-(void)savePrefs;
-(void)loadPrefs;

-(void)initCalibration;

@end
