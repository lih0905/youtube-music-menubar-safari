#import <Cocoa/Cocoa.h>
@class SafariBridge;
@class PlayerState;

@interface PopoverViewController : NSViewController
- (instancetype)initWithBridge:(SafariBridge *)bridge;
- (void)updateWithState:(PlayerState *)state;
@end
