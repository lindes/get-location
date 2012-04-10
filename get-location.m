#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

///// Delegate interface
@interface MyLocationFinder : NSObject <CLLocationManagerDelegate> {
    CLLocationManager *locationManager;
    CLLocation *foundLocation;
    BOOL logging;
}

@property (nonatomic, retain) CLLocationManager *locationManager;
@property (nonatomic, retain) CLLocation *foundLocation;

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation;

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error;

- (CLLocation *)found;
- (CLLocation *)latestOnly;

@end

///// Delegate implementation

@implementation MyLocationFinder

@synthesize locationManager;
@synthesize foundLocation;

- (id) init {
    self = [super init];
    if(self)
    {
        self.foundLocation = nil;
        logging = NO; // TODO: make this configurable

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

    if(logging)
        NSLog(@"Now at %@ (was %@)", [newLocation description], [oldLocation description]);

    if(++hits > 1) // don't store the first hit, as it may be stale
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

    for(i = 0; i < 30; ++i)
    {
        CLLocation *loc;

        if(debug)
            NSLog(@"Running NSRunLoop loop, pass #%d", i);

        [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
        if((loc = [finder latestOnly]))
        {
            if(logging)
                NSLog(@"Final location: %@", [loc description]);
            else
                printf("Final location: %s\n", [[loc description] UTF8String]);

            [pool drain];
            return(0);
        }
    }

    NSLog(@"Giving up.");

    [pool drain];

    return 1;
}
