#import <Cocoa/Cocoa.h>

static NSImage *drawIcon(CGFloat size) {
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(size, size)];
    [image lockFocus];

    [[NSColor clearColor] setFill];
    NSRectFill(NSMakeRect(0, 0, size, size));

    CGFloat margin = size * 0.09;
    NSRect circleRect = NSMakeRect(margin, margin, size - margin * 2, size - margin * 2);
    NSBezierPath *outer = [NSBezierPath bezierPathWithOvalInRect:circleRect];
    [[NSColor colorWithCalibratedRed:0.95 green:0.12 blue:0.15 alpha:1.0] setFill];
    [outer fill];

    CGFloat innerMargin = size * 0.13;
    NSRect innerRect = NSMakeRect(innerMargin, innerMargin, size - innerMargin * 2, size - innerMargin * 2);
    NSBezierPath *inner = [NSBezierPath bezierPathWithOvalInRect:innerRect];
    [[NSColor colorWithCalibratedRed:0.85 green:0.08 blue:0.12 alpha:1.0] setFill];
    [inner fill];

    NSBezierPath *play = [NSBezierPath bezierPath];
    CGFloat cx = size * 0.52;
    CGFloat cy = size * 0.50;
    CGFloat triW = size * 0.20;
    CGFloat triH = size * 0.24;
    [play moveToPoint:NSMakePoint(cx - triW * 0.45, cy - triH / 2.0)];
    [play lineToPoint:NSMakePoint(cx - triW * 0.45, cy + triH / 2.0)];
    [play lineToPoint:NSMakePoint(cx + triW * 0.55, cy)];
    [play closePath];
    [[NSColor whiteColor] setFill];
    [play fill];

    [image unlockFocus];
    return image;
}

static BOOL writePNG(NSImage *image, NSString *path) {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:[image TIFFRepresentation]];
    NSData *pngData = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return [pngData writeToFile:path atomically:YES];
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *outputDir = @".";
        if (argc > 1) {
            outputDir = [NSString stringWithUTF8String:argv[1]];
        }

        [[NSFileManager defaultManager] createDirectoryAtPath:outputDir withIntermediateDirectories:YES attributes:nil error:nil];

        NSImage *appIcon = drawIcon(1024);
        NSImage *statusIcon = drawIcon(18);

        NSString *appPath = [outputDir stringByAppendingPathComponent:@"ytmusic_1024.png"];
        NSString *statusPath = [outputDir stringByAppendingPathComponent:@"ytmusic_status.png"];

        if (!writePNG(appIcon, appPath) || !writePNG(statusIcon, statusPath)) {
            return 1;
        }
    }
    return 0;
}
