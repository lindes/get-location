// get-location.m -- simple command-line interface to CoreLocation framework in MacOS

// Copyright 2012 by David Lindes.  All rights reserved.
// Distributed under the MIT license.  See LICENSE.txt for details.

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#include <sysexits.h> // for EX_USAGE

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

//// outputter functions

typedef void (*locationPrinter)(CLLocation *);

void defaultLogger(CLLocation *loc)
{
    NSLog(@"Location: %@", [loc description]);
}

void defaultPrinter(CLLocation *loc)
{
    printf("Location: %s\n", [[loc description] UTF8String]);
}

void gmlPrinter(CLLocation *loc)
{
    printf("<gml:Point srsDimension=\"2\" srsName=\"http://www.opengis.net/def/crs/EPSG/0/4326\">\n"
           "    <gml:pos>%.8f %.8f</gml:pos>\n"
           "</gml:Point>\n",
           loc.coordinate.latitude, loc.coordinate.longitude);
}

void jsonPrinter(CLLocation *loc)
{
    printf("{ \"type\": \"Point\", \"coordinates\": [ %.8f, %.8f ] }\n",
           loc.coordinate.latitude,
           loc.coordinate.longitude);
}

void _lispPrinter(CLLocation *loc, BOOL quote, BOOL comments)
{
    char *quote1 = quote ? "\"" : "";
    char *quote2 = quote ? "\\" : "";

    printf("%s((%.8f %.8f %g) %s(%.1f %g) %s(%g %g) %s(%s\"%s%s\" %g))%s%s\n",
           quote1,

           loc.coordinate.latitude,
           loc.coordinate.longitude,
           loc.horizontalAccuracy,
           comments ? "  ; lat, lon, accuracy (meters)\n " : "",

           loc.altitude,
           loc.verticalAccuracy,
           comments ? "  ; altitude, accurace (both meters)\n " : "",

           loc.speed,
           loc.course,
           comments ? "  ; speed (k/h), course (degrees)\n " : "",

           quote2,
           [[loc.timestamp description] UTF8String],
           quote2,
           -[loc.timestamp timeIntervalSinceNow],
           comments ? "  ; gathered date, age at time printed" : "",

           quote1);
}
void lispPrinter(CLLocation *loc)           { _lispPrinter(loc, NO, NO);  }
void lispPrinter_quoted(CLLocation *loc)    { _lispPrinter(loc, YES, NO); }
void lispPrinter_commented(CLLocation *loc) { _lispPrinter(loc, NO, YES); }

void plistPrinter(CLLocation *loc)
{
    printf("(:latitude %.8f :longitude %.8f :altitude %g"
           " :horizontal-accuracy %g :vertical-accuracy %g"
           " :speed %g :course %g :timestamp \"%s\" :age %g)\n",

           loc.coordinate.latitude,
           loc.coordinate.longitude,
           loc.altitude,
           loc.horizontalAccuracy,
           loc.verticalAccuracy,
           loc.speed,
           loc.course,
           [[loc.timestamp description] UTF8String],
           -[loc.timestamp timeIntervalSinceNow]);
}

struct {
    char *name;
    locationPrinter printer;
    char *description;
} formats[] = {
    { "default",      defaultPrinter,       "the result of calling description on the CLLocation object [default]"  },
    { "logging",      defaultLogger,        "as above, but use NSLog to report it [default with -l]" },
    { "gml",          gmlPrinter,           "GML - http://en.wikipedia.org/wiki/Geography_Markup_Language" },
    { "json",         jsonPrinter,          "a JSON object, as per http://www.geojson.org/" },
    { "lisp",         lispPrinter,          "a lisp S-expression (suitable for (read))" },
    { "quoted-lisp",  lispPrinter_quoted,   "as lisp, but quote it (suitable for (read-from-string ...))" },
    { "commented-lisp",
                      lispPrinter_commented,"as lisp, but with newlines and comments (read)" },
    { "lisp-plist",   plistPrinter,         "a lisp properties list, suitable for (read)" },
};

#define FORMAT_COUNT (sizeof(formats) / sizeof(*formats))

void usage(const char *fmt, ...)
{
    va_list args;
    int i;

    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);

    fprintf(stderr, "Usage:\n"
            "  get-location [-ldv] [-r <results>] [-f format]\n"
            "\n"
            "    -l: use NSLog to log and print data (more data than just -f loging)\n"
            "    -v: more verbosity\n"
            "    -d: some debugging\n"
            "\n"
            "    -r <results>:  Wait for at least <results> results before finishing\n"
            "                   (caveat: we do give up eventually, so use (0 <= results <= about 2)\n"
            "                   (0 is the first, probably-cached result, 1 is the first subsequent, ...)\n"
            "\n"
            "    -f format:     use one of the following formats for printing:\n");

    for(i = 0; i < FORMAT_COUNT; ++i)
        fprintf(stderr, "%20s:   %s\n", formats[i].name, formats[i].description);

    exit(EX_USAGE);
}

///// main loop

int main(int argc, char *argv[])
{
    // for loops and things:
    int i, ch;

    // run-time flags:
    BOOL logging = NO, verbose = NO, debug = NO; // TODO: make configurable, and probably handle differently
    NSInteger hitsRequired = 0; // TODO: make configurable

    locationPrinter printer = defaultPrinter;
    locationPrinter newPrinter = NULL; // for option processing, and as a flag for if that was used

    //// parse args

    while((ch = getopt(argc, argv, "dlvf:r:")) != -1)
    {
        switch(ch)
        {
        case 'd': debug = YES; break;
        case 'l': logging = YES; break;
        case 'v': verbose = YES; break;

        case 'r':
            hitsRequired = atoi(optarg);
            break;

        case 'f':
            for(i = 0; i < FORMAT_COUNT; ++i)
            {
                if(strcmp(optarg, formats[i].name) == 0)
                {
                    newPrinter = formats[i].printer;
                    break;
                }
            }

            if(newPrinter)
                printer = newPrinter;
            else
                usage("Unknown output format: %s\n", optarg);

            break;
        default:
            usage("Unknown option: %c\n", ch);
            break;
        }
    }

    if(logging && !newPrinter)
        printer = defaultLogger;

    //// go!

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
            (*printer)(loc);

            [pool drain];
            return(0);
        }
    }

    NSLog(@"Giving up.");

    [pool drain];

    return 1;
}
