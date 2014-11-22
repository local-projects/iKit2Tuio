//
//  HIDView.m
//  HIDDraw
//
//  Created by Jeremy Weatherford on 4/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//


#import "HIDView.h"

@implementation HIDView


- (id)initWithFrame:(NSRect)frame {
	self = [super initWithFrame:frame];
	if(self){
		//[NSCursor hide];
		colors[0] = [NSColor redColor];
		colors[1] = [NSColor greenColor];
		colors[2] = [NSColor blueColor];
		colors[3] = [NSColor whiteColor];
		colors[4] = [NSColor orangeColor];
		colors[5] = [NSColor purpleColor];
		colors[6] = [NSColor magentaColor];
		colors[7] = [NSColor yellowColor];
		colors[8] = [NSColor cyanColor];
		colors[9] = [NSColor brownColor];
	}
	calibrating = false;

	NSArray * objs = [NSArray  arrayWithObjects:
		[[NSFontManager sharedFontManager] fontWithFamily:@"helvetica"
                                                   traits:(NSUnboldFontMask | NSUnitalicFontMask)
                                                   weight:7
                                                     size:40],
		[NSColor whiteColor],
		nil
		];
	NSArray * keys = [NSArray  arrayWithObjects: (id)NSFontAttributeName,(id)NSForegroundColorAttributeName, nil ];
	textAttributes = [[NSDictionary dictionaryWithObjects:objs forKeys: keys] retain];

	drawCalibrated = false;
	return self;
}

-(void)setDrawCalibratedOutput:(BOOL)d{
	drawCalibrated = d;
	[self setNeedsDisplay:YES];
}

- (BOOL)isOpaque {
	return YES;
}


-(void)setCalibrationScreenPoints:(POINT *) screenPts;{
	screenPoints = screenPts;
}


-(void)setCalibratingStep:(CalibrationStep) step_{
	step = step_;
	[self setNeedsDisplay:true];
}


- (void) drawRect:(NSRect) rect {

	[[NSColor blackColor] set];
	NSRectFill(rect);

	float scaleMax = DRIVER_RESOLUTION; // touch data is 0-4094
	float width = rect.size.width;
	float height = rect.size.height;

	struct TouchData * touchData = getCoords();
	float radius = 8;

	if (step == STEP_0_NOT_CALIBRATING){

		for(int i = 0; i < MAX_TOUCHES; i++){
			if(touchData->touched[i]){
				NSPoint p;
				if (drawCalibrated){
					p = NSMakePoint((touchData->xCal[i] / scaleMax) * width,
									height - ((touchData->yCal[i] / scaleMax) * height));
				}else{
					p = NSMakePoint((touchData->x[i] / scaleMax) * width,
									height - ((touchData->y[i] / scaleMax) * height));
				}

				// use color for this touch #
				[colors[i] set];

				// draw crosshairs through point p
				NSBezierPath * path = [NSBezierPath bezierPath];
				[path moveToPoint:NSMakePoint(p.x, 0)];
				[path lineToPoint:NSMakePoint(p.x, height)];
				[path moveToPoint:NSMakePoint(0, p.y)];
				[path lineToPoint:NSMakePoint(width, p.y)];
				[path stroke];
			}
		}

		NSPoint center = NSMakePoint(NSMidX(rect), NSMidY(rect));
		center.x -= 529 * 0.5; //string width, to real center
		NSString * msg = [NSString stringWithFormat:@"Drawing Calibrated Data: %@", drawCalibrated ? @"YES" : @"NO"];
		[msg  drawAtPoint:center withAttributes:textAttributes];
	}else{

		NSPoint center = NSMakePoint(NSMidX(rect), NSMidY(rect));
		center.x -= 529 * 0.5; //string width, to real center

		NSString * msg = [NSString stringWithFormat:@"Calibration in Process\nTouch the spot (%d of 3)", 1 + (int)step];
		[[msg uppercaseString] drawAtPoint:center withAttributes:textAttributes];

		NSBezierPath * path = [NSBezierPath bezierPathWithOvalInRect:
							   NSMakeRect(width * screenPoints[step].x / DRIVER_RESOLUTION - radius,
										  height - height * screenPoints[step].y / DRIVER_RESOLUTION - radius,
										  radius * 2,
										  radius * 2)
							   ];
		[colors[step] set];
		[path fill];
	}
}


- (void)mouseDown:(NSEvent *)theEvent{

	//this is left in to debug when no ikit is available

//	TouchData tempData;
//	float xp = 0.25 + 0.5 * [theEvent locationInWindow].x / [self frame].size.width;
//	float yp = [theEvent locationInWindow].y / [self frame].size.height;
//
//	tempData.x[0] = DRIVER_RESOLUTION * xp;
//	tempData.y[0] = DRIVER_RESOLUTION * (1.0 - yp);
//	tempData.touched[0] = true;
//	
//	[[NSApp delegate] touchesUpdated: &tempData];
}

@end