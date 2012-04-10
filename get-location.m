// get-location.m -- simple command-line interface to CoreLocation framework in MacOS

// Copyright 2012 by David Lindes.  All rights reserved.
// Distributed under the MIT license.  See LICENSE.txt for details.

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

///// Delegate interface for CoreLocation to talk to:
@interface MyLocationFinder : NSObject <CLLocationManagerDelegate> {
    CLLocationManager *locationManager;
    CLLocation *foundLocation;
    NSInteger logging; // used as a boolean
    NSInteger hitsRequired; // how many results do we need before advertising them?
}

@property (nonatomic, retain) CLLocationManager *locationManager;
@property (nonatomic, retain) CLLocation *foundLocation;
@property (assign) NSInteger logging;
@property (assign) NSInteger hitsRequired;

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation;

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error;

- (CLLocation *)found;       // location that we've gotten
- (CLLocation *)latestOnly;  // returns location, then clears it
                             // (thus, one can check for updates)

@end

///// Delegate implementation:

@implementation MyLocationFinder

@synthesize locationManager;
@synthesize foundLocation;
@synthesize logging, hitsRequired;

- (id) init {
    self = [super init];
    if(self)
    {
        self.foundLocation = nil;
        self.logging = NO;

        self.locationManager = [[[CLLocationManager alloc] init] autorelease];
        self.locationManager.delegate = self;
        self.locationManager.distanceFilter = kCLDistanceFilterNone;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers; // whatever I can get
        [self.locationManager startUpdatingLocation];
    }
    return self;
}

- (CLLocation *)found
{
    return self.foundLocation;
}

- (CLLocation *)latestOnly;
{
    CLLocation *loc = [self.foundLocation retain];
    self.foundLocation = nil;
    return [loc autorelease];
}

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
    static int hits = 0;

    if(self.logging)
        NSLog(@"Now at %@ (was %@)", [newLocation description], [oldLocation description]);

    // don't necessarily store the first hit, as it may be stale.
    if(++hits > self.hitsRequired)
        // FIXME: make this configurable
    {
        self.foundLocation = [newLocation retain];
    }
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error
{
    NSLog(@"location search failed with error: %@", [error description]);
}

- (void)dealloc
{
    [self.locationManager release];
    [self.foundLocation release];
    [super dealloc];
}

@end

///// main loop

int main(int argc, char *argv[])
{
    int i;
    BOOL logging = NO, verbose = NO, debug = NO; // TODO: make configurable, and probably handle differently
    NSInteger hitsRequired = 1; // TODO: make configurable

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSRunLoop *runLoop = [NSRunLoop mainRunLoop];
    MyLocationFinder *finder;

    if(![CLLocationManager locationServicesEnabled])
    {
        NSLog(@"Sorry, Location Services not available.");
        return(1);
    }

    if(verbose)
        NSLog(@"Initiating location search...");

    finder = [[MyLocationFinder alloc] init];
    finder.logging = logging;
    finder.hitsRequired = hitsRequired;

    for(i = 0; i < 30; ++i)
    {
        CLLocation *loc;

        if(debug)
            NSLog(@"Running NSRunLoop loop, pass #%d", i);

        [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
        if((loc = [finder latestOnly]))
        {
            if(logging)
                NSLog(@"Location: %@", [loc description]);
            else
                printf("Location: %s\n", [[loc description] UTF8String]);

            [pool drain];
            return(0);
        }
    }

    NSLog(@"Giving up.");

    [pool drain];

    return 1;
}
