#import "AppDelegate.h"
#import "SafariBridge.h"
#import "PopoverViewController.h"
#import "PlayerState.h"

@interface AppDelegate ()
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) SafariBridge *bridge;
@property (nonatomic, strong) NSPopover *popover;
@property (nonatomic, strong) PopoverViewController *popoverVC;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) PlayerState *lastState;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.bridge = [[SafariBridge alloc] init];
    self.lastState = [PlayerState emptyState];

    [self setupStatusItem];
    [self setupPopover];

    [self.bridge fetchState];
    [self refreshState];

    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.6
                                                  target:self
                                                selector:@selector(refreshState)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self.timer invalidate];
}

- (void)setupStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSStatusBarButton *button = self.statusItem.button;
    button.target = self;
    button.action = @selector(togglePopover:);
    [button sendActionOn:NSEventMaskLeftMouseUp];

    NSString *imagePath = [[NSBundle mainBundle] pathForResource:@"ytmusic_status" ofType:@"png"];
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:imagePath];
    if (!image) {
        image = [NSImage imageWithSystemSymbolName:@"music.note" accessibilityDescription:nil];
    }
    image.template = NO;
    image.size = NSMakeSize(16, 16);
    button.image = image;
    button.imagePosition = NSImageLeft;
    button.title = @"";
    [self tryLoadOfficialYouTubeMusicIcon];
}

- (void)setupPopover {
    self.popover = [[NSPopover alloc] init];
    self.popover.behavior = NSPopoverBehaviorTransient;
    self.popover.contentSize = NSMakeSize(380, 520);

    self.popoverVC = [[PopoverViewController alloc] initWithBridge:self.bridge];
    self.popover.contentViewController = self.popoverVC;
}

- (void)refreshState {
    PlayerState *state = [self.bridge fetchState];

    // Keep last known track text when a polling cycle fails to parse metadata.
    if (state.foundTab &&
        state.title.length == 0 &&
        state.artist.length == 0 &&
        self.lastState.foundTab &&
        (self.lastState.title.length > 0 || self.lastState.artist.length > 0)) {
        state.title = self.lastState.title ?: @"";
        state.artist = self.lastState.artist ?: @"";
    }

    self.lastState = state;

    NSStatusBarButton *button = self.statusItem.button;
    NSString *statusText = [state statusText];
    if (statusText.length > 0) {
        button.title = [NSString stringWithFormat:@" %@", statusText];
        button.toolTip = statusText;
    } else {
        button.title = @"";
        button.toolTip = @"YouTube Music 대기 중";
    }

    [self.popoverVC updateWithState:state];
}

- (void)togglePopover:(id)sender {
    NSStatusBarButton *button = self.statusItem.button;
    if (self.popover.isShown) {
        [self.popover performClose:sender];
    } else {
        [self.popoverVC updateWithState:self.lastState];
        [self.popover showRelativeToRect:button.bounds ofView:button preferredEdge:NSRectEdgeMinY];
        [self.popover.contentViewController.view.window makeKeyWindow];
    }
}

- (void)tryLoadOfficialYouTubeMusicIcon {
    NSURL *url = [NSURL URLWithString:@"https://music.youtube.com/img/favicon_144.png"];
    if (!url) {
        return;
    }
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error || !data) {
            return;
        }
        NSImage *image = [[NSImage alloc] initWithData:data];
        if (!image) {
            return;
        }
        image.template = NO;
        image.size = NSMakeSize(16, 16);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.statusItem.button.image = image;
            self.statusItem.button.imagePosition = NSImageLeft;
        });
    }] resume];
}

@end
