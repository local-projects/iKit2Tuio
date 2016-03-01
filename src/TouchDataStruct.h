//
//  TouchDataStruct.h
//  iKit2Tuio
//
//  Created by Oriol Ferrer Mesià on 20/03/14.
//  Copyright (c) 2014 Oriol Ferrer Mesià. All rights reserved.
//

#ifndef iKit2Tuio_TouchDataStruct_h
#define iKit2Tuio_TouchDataStruct_h

//define this line below when no ikit is present
//#define NO_IKIT_DEBUG
#define DEBUG_USB_DATA		true /*print on stdout*/

enum FrameType{
	ZENITH_IKIT_FRAME = 0,
	OFFICE_IKIT_FRAME
};

#define MAX_TOUCHES					10
#define DRIVER_RESOLUTION			4094

struct TouchData{
    bool touched[MAX_TOUCHES];
    unsigned int x[MAX_TOUCHES];
    unsigned int y[MAX_TOUCHES];
	unsigned int xCal[MAX_TOUCHES];
    unsigned int yCal[MAX_TOUCHES];
    unsigned int thick[MAX_TOUCHES];
};


enum CalibrationStep{
	STEP_0_NOT_CALIBRATING = -1, STEP_1 = 0, STEP_2 = 1, STEP_3 = 2
};

#endif
