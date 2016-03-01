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

#import "ProwlKit.h"

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
    printf("usb: ");
		for(int i = 0; i < reportlen; i++){
			printf("%x", p[i]);
		}
		printf("\n");
	#endif

//	switch (appDelegate->frameType) {
//		case ZENITH_IKIT_FRAME:
//			if(reportlen != 64 || p[0] != 0x0f || p[reportlen - 1] == 0x00){
//                printf("Not a ZENITH frame.\n");
//				return; // not a multitouch report
//			}
//			break;
//
//		case OFFICE_IKIT_FRAME:
//			if(reportlen != 64 || p[0] != 0x0f /* || p[reportlen - 1] == 0x00*/){
//                printf("Not an OFFICE frame.\n");
//				return; // not a multitouch report
//			}
//			break;
//	}

	// skip report ID
	p = p + 1;

	for(int i = 0; i < MAX_TOUCHES; i++){
		int x = p[0] << 8 | p[1];
		int y = p[2] << 8 | p[3];
		//int thick = p[4] << 8 | p[5];

		touchData.x[i] = x;
		touchData.y[i] = y;
        
        printf("touchData: %x,%x\n", x, y);
        
		//touchData.thick[i] = thick;
		touchData.touched[i] = (x != (4095)); // x=y=4095 if no touch
		p += 6;
	}

    printf("Sending touchesUpdated with new touchData.\n");
	[appDelegate touchesUpdated: &touchData]; //let the app know!
}

static void hid_device_removal_callback(void *context, IOReturn result,
                                        void *sender){
	IOHIDDeviceRef dev = (IOHIDDeviceRef) context;
	NSLog(@"device disconnected!");

	NSString * msg = [NSString stringWithFormat:@"Device Disconnected! %@ %@", [[NSHost currentHost] name], [NSDate date]];
	/*BOOL success = [[ProwlKit sharedProwl] sendMessage:msg
										forApplication:@"iKit2Tuio"
												 event:nil
											   withURL:nil
												forKey:@"332c105bbefe4914c9a14bba4162b9430f1de1b5"
											  priority:ProwlPriorityNormal
												 error:nil];*/
}


BOOL HIDSetup(void){

	CFIndex reportSize = 256;
	CFIndex idx, cnt;
	uint8_t * report;
	CFSetRef devCFSetRef;
	CFStringRef tCFStringRef;
	IOReturn tIOReturn;
	BOOL ret = TRUE;

	for(int i = 0; i < MAX_TOUCHES; i++){
		touchData.touched[i] = false;
	}

	appDelegate = (AppDelegate*)[NSApp delegate];
	IOHIDManagerRef gIOHIDManagerRef;

	// create the manager
	gIOHIDManagerRef = IOHIDManagerCreate(kCFAllocatorDefault, 0L);
	if(!gIOHIDManagerRef){
		NSLog(@"IOHIDManagerCreate failed");
		ret = NO;
		goto notifyAndExit;
	}

	tIOReturn = IOHIDManagerOpen(gIOHIDManagerRef, 0L);
	if(kIOReturnSuccess != tIOReturn){
		NSLog(@"Couldn’t open IOHIDManager.");
		ret = NO;
		goto notifyAndExit;
	}

	// get device list
	IOHIDManagerSetDeviceMatching(gIOHIDManagerRef, NULL);
	devCFSetRef = IOHIDManagerCopyDevices(gIOHIDManagerRef);
	if(!devCFSetRef){
		NSLog(@"IOHIDManagerCopyDevices failed");
		ret = NO;
		goto notifyAndExit;
	}

	gDeviceCFArrayRef = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
	CFSetApplyFunction(devCFSetRef, CFSetApplierFunctionCopyToCFArray, gDeviceCFArrayRef);

	NSLog(@"## Device List ##################");
	// list and match devices
	cnt = CFArrayGetCount(gDeviceCFArrayRef);
	for(idx = 0; idx < cnt; idx++){
		IOHIDDeviceRef tIOHIDDeviceRef = (IOHIDDeviceRef)CFArrayGetValueAtIndex(gDeviceCFArrayRef, idx);
		if(tIOHIDDeviceRef){
			tCFStringRef = Copy_DeviceName(tIOHIDDeviceRef);
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
		ret = NO;
		goto notifyAndExit;
	}

	// empty touches array
	for(int i = 0; i < MAX_TOUCHES; i++){
		touchData.touched[i] = NO;
	}

	// register callback
	report = (uint8_t *)malloc(reportSize);

	IOHIDDeviceRegisterRemovalCallback(gCurrentIOHIDDeviceRef, hid_device_removal_callback, (void *)gCurrentIOHIDDeviceRef);

	IOHIDDeviceRegisterInputReportCallback(gCurrentIOHIDDeviceRef, report, reportSize,
		Handle_IOInputReport, (void *)gCurrentIOHIDDeviceRef);

	// add HIDManager to Cocoa run loop so we get callbacks
	IOHIDManagerScheduleWithRunLoop(gIOHIDManagerRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

	////////////////////////////////////////////////////////////////////////////////////////////////
	notifyAndExit:
	////////////////////////////////////////////////////////////////////////////////////////////////

	NSString * msg = [NSString stringWithFormat:@"Device is %@ at startup. %@ %@", ret ? @"OK" : @"KO",  [[NSHost currentHost] name], [NSDate date]];
/*	BOOL success = [[ProwlKit sharedProwl] sendMessage:msg
										forApplication:@"iKit2Tuio"
												 event:nil
											   withURL:nil
												forKey:@"332c105bbefe4914c9a14bba4162b9430f1de1b5"
											  priority:ProwlPriorityNormal
												 error:nil];*/


	return ret;
}


struct TouchData * getCoords(void){
	return &touchData;
}


