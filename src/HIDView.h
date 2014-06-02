//
//  HIDView.h
//  HIDDraw
//
//  Created by Jeremy Weatherford on 4/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "TouchDataStruct.h"
#import "hid.h"
#include "calibrate.h"

@interface HIDView : NSView{

	NSColor *colors[MAX_TOUCHES];
	BOOL calibrating;
	CalibrationStep step;
	POINT * screenPoints;
	NSDictionary * textAttributes;

	bool drawCalibrated;
}

-(void)setDrawCalibratedOutput:(BOOL)b;
-(void)setCalibratingStep:(CalibrationStep) step;
-(void)setCalibrationScreenPoints:(POINT *) screenPts; //assumes array of 3!

@end
