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
@property (nonatomic, strong) NSTimer *bootstrapTimer;
@property (nonatomic, strong) PlayerState *lastState;
@property (nonatomic, assign) BOOL isRefreshingState;
@property (nonatomic, assign) NSInteger bootstrapRetriesRemaining;
@property (nonatomic, assign) CGFloat frozenStatusItemLength;
@property (nonatomic, assign) BOOL statusItemLengthFrozen;
@end

@implementation AppDelegate

static const CGFloat kFixedPopoverWidth = 400.0;
static const CGFloat kFixedPopoverHeight = 540.0;

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.bridge = [[SafariBridge alloc] init];
    self.lastState = [PlayerState emptyState];
    self.isRefreshingState = NO;
    self.bootstrapRetriesRemaining = 8;
    self.frozenStatusItemLength = 0;
    self.statusItemLengthFrozen = NO;

    [self setupStatusItem];
    [self setupPopover];

    [self refreshState];

    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.6
                                                  target:self
                                                selector:@selector(refreshState)
                                                userInfo:nil
                                                 repeats:YES];
    self.bootstrapTimer = [NSTimer scheduledTimerWithTimeInterval:0.8
                                                           target:self
                                                         selector:@selector(onBootstrapRetryTick)
                                                         userInfo:nil
                                                          repeats:YES];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self.timer invalidate];
    [self.bootstrapTimer invalidate];
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
    self.popover.contentSize = NSMakeSize(kFixedPopoverWidth, kFixedPopoverHeight);

    self.popoverVC = [[PopoverViewController alloc] initWithBridge:self.bridge];
    self.popoverVC.preferredContentSize = NSMakeSize(kFixedPopoverWidth, kFixedPopoverHeight);
    self.popover.contentViewController = self.popoverVC;
}

- (void)refreshState {
    if (self.isRefreshingState) {
        return;
    }
    self.isRefreshingState = YES;

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        PlayerState *state = [weakSelf.bridge fetchState];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }

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
            button.title = @"";
            button.toolTip = statusText.length > 0 ? statusText : @"YouTube Music 대기 중";

            [self.popoverVC updateWithState:state];
            if (self.popover.isShown) {
                [self enforceFixedPopoverFrameWithRightMargin:10 topInset:8];
            }
            self.isRefreshingState = NO;
        });
    });
}

- (void)onBootstrapRetryTick {
    if (self.bootstrapRetriesRemaining <= 0) {
        [self.bootstrapTimer invalidate];
        self.bootstrapTimer = nil;
        return;
    }
    if (self.lastState.albumArtURL.length > 0) {
        [self.bootstrapTimer invalidate];
        self.bootstrapTimer = nil;
        return;
    }

    self.bootstrapRetriesRemaining -= 1;
    [self refreshState];
}

- (void)togglePopover:(id)sender {
    NSStatusBarButton *button = self.statusItem.button;
    if (self.popover.isShown) {
        [self.popover performClose:sender];
        [self unfreezeStatusItemLength];
        [self refreshState];
    } else {
        [self freezeStatusItemLength];
        [self.popoverVC updateWithState:self.lastState];
        self.popover.contentSize = NSMakeSize(kFixedPopoverWidth, kFixedPopoverHeight);
        self.popoverVC.preferredContentSize = NSMakeSize(kFixedPopoverWidth, kFixedPopoverHeight);
        [self.popover showRelativeToRect:button.bounds ofView:button preferredEdge:NSRectEdgeMinY];
        [self.popover.contentViewController.view.window makeKeyWindow];
        [self enforceFixedPopoverFrameWithRightMargin:10 topInset:8];
        [self schedulePopoverFrameEnforcement];
    }
}

- (void)freezeStatusItemLength {
    if (self.statusItemLengthFrozen) {
        return;
    }
    NSStatusBarButton *button = self.statusItem.button;
    CGFloat width = NSWidth(button.frame);
    if (width < 24) {
        width = 24;
    }
    self.frozenStatusItemLength = width;
    self.statusItem.length = width;
    self.statusItemLengthFrozen = YES;
}

- (void)unfreezeStatusItemLength {
    if (!self.statusItemLengthFrozen) {
        return;
    }
    self.statusItem.length = NSVariableStatusItemLength;
    self.statusItemLengthFrozen = NO;
    self.frozenStatusItemLength = 0;
}

- (void)enforceFixedPopoverFrameWithRightMargin:(CGFloat)rightMargin topInset:(CGFloat)topInset {
    NSWindow *popoverWindow = self.popover.contentViewController.view.window;
    if (!popoverWindow) {
        return;
    }
    NSScreen *screen = self.statusItem.button.window.screen ?: NSScreen.mainScreen;
    if (!screen) {
        return;
    }

    NSRect visibleFrame = screen.visibleFrame;
    CGFloat x = NSMaxX(visibleFrame) - rightMargin - kFixedPopoverWidth;
    CGFloat y = NSMaxY(visibleFrame) - topInset - kFixedPopoverHeight;
    NSRect fixedFrame = NSMakeRect(x, y, kFixedPopoverWidth, kFixedPopoverHeight);
    [popoverWindow setFrame:fixedFrame display:YES];
}

- (void)schedulePopoverFrameEnforcement {
    NSArray<NSNumber *> *delays = @[@0.02, @0.08, @0.16, @0.3, @0.5];
    for (NSNumber *delay in delays) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.popover.isShown) {
                [self enforceFixedPopoverFrameWithRightMargin:10 topInset:8];
            }
        });
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
