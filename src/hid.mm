//
//  main.c
//  HelloHID
//
//  Created by Jeremy Weatherford on 4/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#include <stdio.h>
#include <Carbon/Carbon.h>

#include "HID_Utilities.h"
#include "hid.h"
#import "AppDelegate.h"


IOHIDDeviceRef gCurrentIOHIDDeviceRef;
TouchData touchData;
AppDelegate * appDelegate;

static void CFSetApplierFunctionCopyToCFArray(const void * value, void * context){
	CFArrayAppendValue((CFMutableArrayRef)context, value);
}   // CFSetApplierFunctionCopyToCFArray


// Copy_DeviceName from HID Explorer source
// generate human-readable device name from device info
static CFStringRef Copy_DeviceName(IOHIDDeviceRef inDeviceRef){
	CFStringRef result = NULL;
	if(inDeviceRef){
		CFStringRef manCFStringRef = IOHIDDevice_GetManufacturer(inDeviceRef);
		if(manCFStringRef){
			// make a copy that we can CFRelease later
			CFMutableStringRef tCFStringRef = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, manCFStringRef);
			// trim off any trailing spaces
			while(CFStringHasSuffix(tCFStringRef, CFSTR(" "))){
				CFIndex cnt = CFStringGetLength(tCFStringRef);
				if(!cnt){
					break;
				}
				CFStringDelete(tCFStringRef, CFRangeMake(cnt - 1, 1));
			}
			manCFStringRef = tCFStringRef;
		} else{
			// try the vendor ID source
			manCFStringRef = IOHIDDevice_GetVendorIDSource(inDeviceRef);
		}
		if(!manCFStringRef){
			// use the vendor ID to make a manufacturer string
			long vendorID = IOHIDDevice_GetVendorID(inDeviceRef);
			manCFStringRef = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("vendor: %li"), vendorID);
		}

		CFStringRef prodCFStringRef = IOHIDDevice_GetProduct(inDeviceRef);
		if(prodCFStringRef){
			// make a copy that we can CFRelease later
			prodCFStringRef = CFStringCreateCopy(kCFAllocatorDefault, prodCFStringRef);
		} else{
			// use the product ID
			long productID = IOHIDDevice_GetProductID(inDeviceRef);
			// to make a product string
			prodCFStringRef = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@ - product id %li"), manCFStringRef, productID);
		}
		assert(prodCFStringRef);

		// if the product name begins with the manufacturer string...
		if(CFStringHasPrefix(prodCFStringRef, manCFStringRef)){
			// then just use the product name
			result = CFStringCreateCopy(kCFAllocatorDefault, prodCFStringRef);
		} else{     // otherwise
			// append the product name to the manufacturer
			result = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@ - %@"), manCFStringRef, prodCFStringRef);
		}

		if(manCFStringRef){
			CFRelease(manCFStringRef);
		}
		if(prodCFStringRef){
			CFRelease(prodCFStringRef);
		}
	}
	return result;
}   // Copy_DeviceName


// HID Input Report callback
static void Handle_IOInputReport(void * inContext, IOReturn inResult, void * inSender,
								 IOHIDReportType inType, uint32_t inReportID,
								 uint8_t * inReport, CFIndex reportlen){
	uint8_t * p = inReport;

	#if DEBUG_USB_DATA
		//print whole report
		for(int i = 0; i < reportlen; i++){
			printf("%x", p[i]);
		}
		printf("\n");
	#endif

	switch (appDelegate->frameType) {
		case ZENITH_IKIT_FRAME:
			if(reportlen != 64 || p[0] != 0x0f || p[reportlen - 1] == 0x00){
				return; // not a multitouch report
			}
			break;

		case OFFICE_IKIT_FRAME:
			if(reportlen != 64 || p[0] != 0x0f /* || p[reportlen - 1] == 0x00*/){
				return; // not a multitouch report
			}
			break;
	}

	// skip report ID
	p = p + 1;

	for(int i = 0; i < MAX_TOUCHES; i++){
		int x = p[0] << 8 | p[1];
		int y = p[2] << 8 | p[3];
		//int thick = p[4] << 8 | p[5];

		touchData.x[i] = x;
		touchData.y[i] = y;
		//touchData.thick[i] = thick;
		touchData.touched[i] = (x != (4095)); // x=y=4095 if no touch
		p += 6;
	}

	[appDelegate touchesUpdated: &touchData]; //let the app know!
}


BOOL HIDSetup(void){

	for(int i = 0; i < MAX_TOUCHES; i++){
		touchData.touched[i] = false;
	}

	appDelegate = [NSApp delegate];
	IOHIDManagerRef gIOHIDManagerRef;

	// create the manager
	gIOHIDManagerRef = IOHIDManagerCreate(kCFAllocatorDefault, 0L);
	if(!gIOHIDManagerRef){
		NSLog(@"IOHIDManagerCreate failed");
		return NO;
	}

	IOReturn tIOReturn = IOHIDManagerOpen(gIOHIDManagerRef, 0L);
	if(kIOReturnSuccess != tIOReturn){
		NSLog(@"Couldn’t open IOHIDManager.");
		return NO;
	}

	// get device list
	IOHIDManagerSetDeviceMatching(gIOHIDManagerRef, NULL);
	CFSetRef devCFSetRef = IOHIDManagerCopyDevices(gIOHIDManagerRef);
	if(!devCFSetRef){
		NSLog(@"IOHIDManagerCopyDevices failed");
		return NO;
	}

	gDeviceCFArrayRef = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
	CFSetApplyFunction(devCFSetRef, CFSetApplierFunctionCopyToCFArray, gDeviceCFArrayRef);

	NSLog(@"## Device List ##################");
	// list and match devices
	CFIndex idx, cnt = CFArrayGetCount(gDeviceCFArrayRef);
	for(idx = 0; idx < cnt; idx++){
		IOHIDDeviceRef tIOHIDDeviceRef = (IOHIDDeviceRef)CFArrayGetValueAtIndex(gDeviceCFArrayRef, idx);
		if(tIOHIDDeviceRef){
			CFStringRef tCFStringRef = Copy_DeviceName(tIOHIDDeviceRef);
			NSLog(@"dev[%ld]: %@\n", idx, tCFStringRef);

			// match Baanto interface
			if(CFStringFind(tCFStringRef, CFSTR("Baanto"), 0).location != kCFNotFound){
				gCurrentIOHIDDeviceRef = tIOHIDDeviceRef;
				NSLog(@" - matched\n");
			}
		}
	}
	NSLog(@"################################");

	if(!gCurrentIOHIDDeviceRef){
		NSLog(@"no device matched! You will not get TUIO events");
		return NO;
	}

	// empty touches array
	for(int i = 0; i < MAX_TOUCHES; i++){
		touchData.touched[i] = NO;
	}

	// register callback
	CFIndex reportSize = 256;
	uint8_t * report = (uint8_t *)malloc(reportSize);

	IOHIDDeviceRegisterInputReportCallback(gCurrentIOHIDDeviceRef, report, reportSize,
		Handle_IOInputReport, (void *)gCurrentIOHIDDeviceRef);

	// add HIDManager to Cocoa run loop so we get callbacks
	IOHIDManagerScheduleWithRunLoop(gIOHIDManagerRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

	return YES;
}


struct TouchData * getCoords(void){
	return &touchData;
}


