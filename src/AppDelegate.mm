//
//  AppDelegate.m
//  iKit2Tuio
//
//  Created by Oriol Ferrer Mesià on 20/03/14.
//  Copyright (c) 2014 Oriol Ferrer Mesià. All rights reserved.
//

#import "AppDelegate.h"

#include <Carbon/Carbon.h>

#include "HID_Utilities.h"
#include "hid.h"
#include <stdio.h>


#ifdef NO_IKIT_DEBUG
float x = 200;
float y = 200;
#endif


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{

	for(int i = 0; i < MAX_TOUCHES; i++){
		cursors[i] = NULL;
	}
	started = false;
	HIDSetup();
	[self loadPrefs];
	[self setState: STEP_0_NOT_CALIBRATING];

	[self initCalibration];
	[self loadCalibrationData];

	[self startStop:nil];
	fullScreenWindow = nil;

	NSLog(@"Integer Math in %d bits",  8 * (int)sizeof(long) );
}


-(IBAction)nextStep:(id)sender{ //debug

	CalibrationStep step = (CalibrationStep)(calibrationStep + 1);
	if (step > STEP_3) step = STEP_0_NOT_CALIBRATING;
	[self setState: step];
}


-(void)initCalibration{

	//NSRect desktop = [self getDesktop];
	//desktop.size.width *= 2;
	screenPoint[0].x = 0.05 * DRIVER_RESOLUTION;
	screenPoint[0].y = 0.05 * DRIVER_RESOLUTION;

	screenPoint[1].x = 0.50 * DRIVER_RESOLUTION;
	screenPoint[1].y = 0.95 * DRIVER_RESOLUTION;

	screenPoint[2].x = 0.95 * DRIVER_RESOLUTION;
	screenPoint[2].y = 0.50 * DRIVER_RESOLUTION;

	[debugView setCalibrationScreenPoints: &screenPoint[0]];
}


-(POINT)getCalibrated:(POINT)p{ //TODO

	POINT calibratedP;
	if(isCalibrated){
		getDisplayPoint( &calibratedP, &p, &matrix ) ;
		return calibratedP;
	}else{
		return p;
	}
}


-(void)calcCalibration;{

	//setCalibrationMatrix( &calibPoint[0], &screenPoint[0], &matrix );
	setCalibrationMatrix( &screenPoint[0], &calibPoint[0], &matrix );
	isCalibrated = true;
	[self saveCalibrationData];
	[usingCalibrationField setStringValue:@"YES"];
	[debugView setDrawCalibratedOutput:YES];
}


-(void)touchesUpdated:(struct TouchData*)data{

#ifndef NO_IKIT_DEBUG

	if (calibrationStep != STEP_0_NOT_CALIBRATING){

		if (data->touched[0] && cursors[0] == NULL){

			switch (calibrationStep) {
				case STEP_1:
					calibPoint[calibrationStep].x = data->x[0];
					calibPoint[calibrationStep].y = data->y[0];
					NSLog(@"got calib point 1 : %li %li", calibPoint[calibrationStep].x, calibPoint[calibrationStep].y);
					[self nextStep:self];
					break;
				case STEP_2:
					calibPoint[calibrationStep].x = data->x[0];
					calibPoint[calibrationStep].y = data->y[0];
					NSLog(@"got calib point 2 : %li %li", calibPoint[calibrationStep].x, calibPoint[calibrationStep].y);
					[self nextStep:self];
					break;
				case STEP_3:
					calibPoint[calibrationStep].x = data->x[0];
					calibPoint[calibrationStep].y = data->y[0];
					NSLog(@"got calib point 3 : %li %li", calibPoint[calibrationStep].x, calibPoint[calibrationStep].y);
					[self setState: STEP_0_NOT_CALIBRATING];
					break;
			}
		}
	}

	for(int i = 0; i < MAX_TOUCHES; i++){
		if(data->touched[i]){
			POINT t;
			t.x = data->x[i];
			t.y = data->y[i];

			POINT p = [self getCalibrated: t];
			data->xCal[i] = (int)p.x; //fill in the calibrated output data to be able to draw calibrated if wanted
			data->yCal[i] = (int)p.y;
			if(cursors[i] == NULL){
				cursors[i] = server.addCursor(p.x, p.y);
				//NSLog(@"add cursor %d (%d)", i, cursors[i]->getCursorID());
			}else{
				server.updateCursor(cursors[i], p.x, p.y);
				//NSLog(@"update cursor %d (%d)", i, cursors[i]->getCursorID());
			}
		}else{
			if (cursors[i] != NULL){
				server.removeCursor(cursors[i]);
				//NSLog(@"remove cursor %d (%d)", i, cursors[i]->getCursorID());
				cursors[i] = NULL;
			}
		}
	}

#else
		//update our fake finger touch
		x += 10;
		if (x > DRIVER_RESOLUTION) x = 0;
		server.updateCursor(cursors[0],x,y);
#endif

	if([debugWindow isVisible] || fullScreenWindow != nil){
		[debugView setNeedsDisplay:YES];
	}
	server.run();
}


- (void)applicationWillTerminate:(NSNotification *)notification{

	NSLog(@"good bye!\n");
	//detach all fingers
	for(int i = 0; i < MAX_TOUCHES; i++){
		if(cursors[i]){
			server.removeCursor(cursors[i]);
		};
	}
	if(started){
		server.run();
	}
}


-(IBAction)startStop:(id)sender{

	NSLog(@"start!");
	started = true;
	[self savePrefs];

	server.setCanvasSize(DRIVER_RESOLUTION, DRIVER_RESOLUTION);

	server.setVerbose(false);
	server.start(
				 (char*)[[hostField stringValue] UTF8String],
				 (int)[portField intValue]
				 );

	//debug
	#ifdef NO_IKIT_DEBUG
	cursors[0] = server.addCursor(x,y); //add one fake touch, update over time
	[NSTimer scheduledTimerWithTimeInterval:1./15 target:self selector:@selector(touchesUpdated:) userInfo:nil repeats:YES];
	#endif
}


-(void)setState:(CalibrationStep)s{
	if(calibrationStep == STEP_3 && s == STEP_0_NOT_CALIBRATING){
		[debugWindow setContentView:debugView];
		[fullScreenWindow close];
		fullScreenWindow = nil;
		[self saveCalibrationData];
		[self calcCalibration];
	}

	calibrationStep = s;
	[debugView setCalibratingStep:s];
}


-(IBAction)selectedFrameType:(id)sender{
	frameType = (FrameType)([frameTypePopup indexOfSelectedItem]);
}


-(IBAction)startCalibrationProcess:(id)sender;{

	NSRect desktop = [self getDesktop];
	fullScreenWindow = [[NSWindow alloc] initWithContentRect: desktop
												   styleMask: NSBorderlessWindowMask
													 backing: NSBackingStoreBuffered
													   defer: NO
						];
	[fullScreenWindow setLevel:NSScreenSaverWindowLevel];
	[fullScreenWindow setContentView:debugView];
	[fullScreenWindow makeKeyAndOrderFront:self];

	[self setState: STEP_1];
	[debugView setNeedsDisplay:YES];
}


-(void)loadPrefs{

	NSUserDefaults * d = [NSUserDefaults standardUserDefaults];
	if([d objectForKey: @"lastUsedHost"] != nil){
		[hostField setStringValue: [d stringForKey:@"lastUsedHost"]];
	}

	if([d objectForKey: @"lastUsedPort"] != nil){
		int p = (int)[d integerForKey:@"lastUsedPort"];
		[portField setStringValue:[NSString stringWithFormat:@"%d", p]]; //dont ask me why
	}

	if([d objectForKey: @"frameType"] != nil){
		frameType = (FrameType)[d integerForKey:@"frameType"];
		[frameTypePopup selectItemAtIndex:(int)frameType];
	}

	isCalibrated = false;
}


-(void)loadCalibrationData{

	NSUserDefaults * def = [NSUserDefaults standardUserDefaults];

	BOOL hasData = FALSE;
	if([def objectForKey: @"hasCalibrationData"] != nil){
		hasData = [def boolForKey:@"hasCalibrationData"];
	}

	if(hasData){ //if there is calibration data saved

		for(int i = 0; i < 3; i++){
			NSString * xKey = [NSString stringWithFormat:@"calibPoint_%d.x", i];
			NSString * yKey = [NSString stringWithFormat:@"calibPoint_%d.y", i];
			float xx = [[def stringForKey:xKey] floatValue];
			float yy = [[def stringForKey:yKey] floatValue];
			calibPoint[i].x = xx;
			calibPoint[i].y = yy;
		}

		[self calcCalibration];

		[usingCalibrationField setStringValue:@"YES"];
		[debugView setDrawCalibratedOutput:YES];
		isCalibrated = true;
	}else{
		isCalibrated = false;
		[usingCalibrationField setStringValue:@"NO"];
		[debugView setDrawCalibratedOutput:NO];
	}
}


-(void)saveCalibrationData{

	NSUserDefaults * def = [NSUserDefaults standardUserDefaults];

	[def setBool:true forKey:@"hasCalibrationData"];

	//save touch points
	for(int i = 0; i < 3; i++){
		NSString * xKey = [NSString stringWithFormat:@"calibPoint_%d.x", i];
		NSString * yKey = [NSString stringWithFormat:@"calibPoint_%d.y", i];
		NSString * xx = [NSString stringWithFormat:@"%li", calibPoint[i].x];
		NSString * yy = [NSString stringWithFormat:@"%li", calibPoint[i].y];
		[def setObject: xx forKey: xKey];
		[def setObject: yy forKey: yKey];
	}
	[def synchronize];
}


-(IBAction)resetCalibrationData:(id)sender{
	NSUserDefaults * def = [NSUserDefaults standardUserDefaults];
	[def setBool:false forKey:@"hasCalibrationData"]; //invalidate defaults calib data
	isCalibrated = false;
	[usingCalibrationField setStringValue:@"NO"];
	[debugView setDrawCalibratedOutput:NO];
	[def synchronize];
}


-(void)savePrefs{
	NSUserDefaults * def = [NSUserDefaults standardUserDefaults];
	[def setObject: hostField.stringValue forKey: @"lastUsedHost"];
	[def setInteger:(int)[portField intValue]  forKey: @"lastUsedPort"];
	[def setInteger:(int)frameType forKey: @"frameType"];
	[def synchronize];
}


-(NSRect)getDesktop{

	NSRect total = NSMakeRect(0, 0, 0, 0);
	NSArray * screens = [NSScreen screens];
	for (int i = 0; i < [screens count]; i++){
		NSScreen * s = [screens objectAtIndex:i];
		NSRect f = [s frame];
		total = NSUnionRect(total, f);
		//NSLog(@"Rect %@", NSStringFromRect(total));
	}

	//total = [[NSScreen mainScreen] frame]; //test debug

	return total;
};

@end