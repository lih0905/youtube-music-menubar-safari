#import "PopoverViewController.h"
#import "SafariBridge.h"
#import "PlayerState.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static const NSTimeInterval kAlbumArtRetryInterval = 2.0;

@interface PopoverViewController ()
@property (nonatomic, strong) SafariBridge *bridge;
@property (nonatomic, strong) NSImageView *albumImageView;
@property (nonatomic, strong) NSSlider *progressSlider;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *artistLabel;
@property (nonatomic, strong) NSTextField *elapsedLabel;
@property (nonatomic, strong) NSTextField *durationLabel;
@property (nonatomic, strong) NSTextView *lyricsTextView;
@property (nonatomic, strong) NSScrollView *lyricsScrollView;
@property (nonatomic, strong) NSView *lyricsContainerView;
@property (nonatomic, strong) NSButton *quitButton;
@property (nonatomic, strong) NSButton *prevButton;
@property (nonatomic, strong) NSButton *playPauseButton;
@property (nonatomic, strong) NSButton *nextButton;
@property (nonatomic, assign) BOOL isUserDraggingSlider;
@property (nonatomic, copy) NSString *lastAlbumArtURL;
@property (nonatomic, strong) NSImage *lastAlbumArtImage;
@property (nonatomic, assign) BOOL lastAlbumArtLoaded;
@property (nonatomic, strong) NSDate *lastAlbumArtAttemptAt;
@property (nonatomic, copy) NSString *lastLyricsText;
@end

@implementation PopoverViewController

- (instancetype)initWithBridge:(SafariBridge *)bridge {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _bridge = bridge;
    }
    return self;
}

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 392, 560)];
    [self setupUI];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    [self applyVisualTheme];
}

- (void)updateWithState:(PlayerState *)state {
    self.titleLabel.stringValue = state.title.length > 0 ? state.title : @"Not Playing";
    self.artistLabel.stringValue = state.artist ?: @"";
    if (!self.isUserDraggingSlider) {
        self.progressSlider.doubleValue = [state progress] * 100.0;
    }
    self.progressSlider.enabled = state.durationSeconds > 0.5;
    self.elapsedLabel.stringValue = [self formatTime:state.currentSeconds];
    self.durationLabel.stringValue = state.durationSeconds > 0 ? [self formatTime:state.durationSeconds] : @"--:--";

    NSString *lyricsText = state.lyrics.length > 0
        ? state.lyrics
        : @"가사를 불러오지 못했습니다. YouTube Music 가사 탭을 열어두면 인식률이 올라갑니다.";
    if (![self.lastLyricsText isEqualToString:lyricsText]) {
        [self applyLyricsText:lyricsText];
        self.lastLyricsText = [lyricsText copy];
    }

    [self updatePlaybackIconsForPlaying:state.isPlaying];

    [self loadAlbumArt:state.albumArtURL];
}

- (void)setupUI {
    self.view.wantsLayer = YES;
    self.view.layer.cornerRadius = 16.0;
    self.view.layer.masksToBounds = YES;

    NSStackView *root = [[NSStackView alloc] initWithFrame:self.view.bounds];
    root.translatesAutoresizingMaskIntoConstraints = NO;
    root.orientation = NSUserInterfaceLayoutOrientationVertical;
    root.spacing = 12.0;
    root.edgeInsets = NSEdgeInsetsMake(20, 20, 20, 20);

    NSView *playerCard = [[NSView alloc] init];
    playerCard.translatesAutoresizingMaskIntoConstraints = NO;
    playerCard.wantsLayer = YES;
    playerCard.layer.cornerRadius = 16.0;
    playerCard.layer.masksToBounds = YES;
    playerCard.layer.borderWidth = 1.0;

    NSStackView *playerStack = [[NSStackView alloc] init];
    playerStack.translatesAutoresizingMaskIntoConstraints = NO;
    playerStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    playerStack.spacing = 10.0;
    playerStack.edgeInsets = NSEdgeInsetsMake(16, 16, 16, 16);
    [playerCard addSubview:playerStack];
    [NSLayoutConstraint activateConstraints:@[
        [playerStack.leadingAnchor constraintEqualToAnchor:playerCard.leadingAnchor],
        [playerStack.trailingAnchor constraintEqualToAnchor:playerCard.trailingAnchor],
        [playerStack.topAnchor constraintEqualToAnchor:playerCard.topAnchor],
        [playerStack.bottomAnchor constraintEqualToAnchor:playerCard.bottomAnchor]
    ]];

    NSView *albumShadowWrap = [[NSView alloc] init];
    albumShadowWrap.translatesAutoresizingMaskIntoConstraints = NO;
    albumShadowWrap.wantsLayer = YES;
    albumShadowWrap.layer.shadowColor = [NSColor blackColor].CGColor;
    albumShadowWrap.layer.shadowOpacity = 0.12;
    albumShadowWrap.layer.shadowOffset = NSMakeSize(0, -2);
    albumShadowWrap.layer.shadowRadius = 12.0;
    albumShadowWrap.layer.cornerRadius = 14.0;

    self.albumImageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 168, 168)];
    self.albumImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.albumImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    self.albumImageView.wantsLayer = YES;
    self.albumImageView.layer.cornerRadius = 14.0;
    self.albumImageView.layer.masksToBounds = YES;
    self.albumImageView.image = [NSImage imageWithSystemSymbolName:@"music.note" accessibilityDescription:nil];
    if (self.lastAlbumArtLoaded && self.lastAlbumArtImage) {
        self.albumImageView.image = self.lastAlbumArtImage;
    }
    [albumShadowWrap addSubview:self.albumImageView];
    [NSLayoutConstraint activateConstraints:@[
        [self.albumImageView.leadingAnchor constraintEqualToAnchor:albumShadowWrap.leadingAnchor],
        [self.albumImageView.trailingAnchor constraintEqualToAnchor:albumShadowWrap.trailingAnchor],
        [self.albumImageView.topAnchor constraintEqualToAnchor:albumShadowWrap.topAnchor],
        [self.albumImageView.bottomAnchor constraintEqualToAnchor:albumShadowWrap.bottomAnchor],
        [albumShadowWrap.widthAnchor constraintEqualToConstant:168],
        [albumShadowWrap.heightAnchor constraintEqualToConstant:168]
    ]];

    NSView *albumWrap = [[NSView alloc] init];
    albumWrap.translatesAutoresizingMaskIntoConstraints = NO;
    [albumWrap addSubview:albumShadowWrap];
    [NSLayoutConstraint activateConstraints:@[
        [albumShadowWrap.centerXAnchor constraintEqualToAnchor:albumWrap.centerXAnchor],
        [albumShadowWrap.topAnchor constraintEqualToAnchor:albumWrap.topAnchor],
        [albumShadowWrap.bottomAnchor constraintEqualToAnchor:albumWrap.bottomAnchor]
    ]];

    self.titleLabel = [NSTextField labelWithString:@""];
    self.titleLabel.font = [NSFont systemFontOfSize:17 weight:NSFontWeightSemibold];
    self.titleLabel.alignment = NSTextAlignmentCenter;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.usesSingleLineMode = YES;

    self.artistLabel = [NSTextField labelWithString:@""];
    self.artistLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    self.artistLabel.textColor = [NSColor secondaryLabelColor];
    self.artistLabel.alignment = NSTextAlignmentCenter;
    self.artistLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.artistLabel.usesSingleLineMode = YES;

    self.elapsedLabel = [NSTextField labelWithString:@"0:00"];
    self.elapsedLabel.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightMedium];
    self.elapsedLabel.textColor = [NSColor tertiaryLabelColor];
    self.durationLabel = [NSTextField labelWithString:@"--:--"];
    self.durationLabel.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightMedium];
    self.durationLabel.textColor = [NSColor secondaryLabelColor];

    NSStackView *timeRow = [[NSStackView alloc] init];
    timeRow.translatesAutoresizingMaskIntoConstraints = NO;
    timeRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    timeRow.spacing = 8.0;
    NSView *timeSpacer = [[NSView alloc] init];
    [timeSpacer setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [timeRow addArrangedSubview:self.elapsedLabel];
    [timeRow addArrangedSubview:timeSpacer];
    [timeRow addArrangedSubview:self.durationLabel];

    self.progressSlider = [[NSSlider alloc] init];
    self.progressSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressSlider.minValue = 0;
    self.progressSlider.maxValue = 100;
    self.progressSlider.doubleValue = 0;
    self.progressSlider.continuous = YES;
    self.progressSlider.controlSize = NSControlSizeSmall;
    self.progressSlider.target = self;
    self.progressSlider.action = @selector(onSeekSliderChanged:);

    NSStackView *controls = [[NSStackView alloc] init];
    controls.translatesAutoresizingMaskIntoConstraints = NO;
    controls.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    controls.spacing = 16;

    self.prevButton = [self makeIconButton:@"backward.fill"
                              fallbackTitle:@"이전"
                                   diameter:44
                                  isPrimary:NO
                                     action:@selector(onPrevious)];
    self.playPauseButton = [self makeIconButton:@"play.fill"
                                   fallbackTitle:@"재생"
                                       diameter:52
                                      isPrimary:YES
                                          action:@selector(onPlayPause)];
    self.nextButton = [self makeIconButton:@"forward.fill"
                              fallbackTitle:@"다음"
                                   diameter:44
                                  isPrimary:NO
                                     action:@selector(onNext)];

    [controls addArrangedSubview:self.prevButton];
    [controls addArrangedSubview:self.playPauseButton];
    [controls addArrangedSubview:self.nextButton];

    NSView *controlsWrap = [[NSView alloc] init];
    controlsWrap.translatesAutoresizingMaskIntoConstraints = NO;
    [controlsWrap addSubview:controls];
    [NSLayoutConstraint activateConstraints:@[
        [controls.centerXAnchor constraintEqualToAnchor:controlsWrap.centerXAnchor],
        [controls.topAnchor constraintEqualToAnchor:controlsWrap.topAnchor],
        [controls.bottomAnchor constraintEqualToAnchor:controlsWrap.bottomAnchor]
    ]];

    NSTextField *lyricsTitle = [NSTextField labelWithString:@"가사"];
    lyricsTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];

    self.lyricsContainerView = [[NSView alloc] init];
    self.lyricsContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.lyricsContainerView.wantsLayer = YES;
    self.lyricsContainerView.layer.cornerRadius = 12.0;
    self.lyricsContainerView.layer.masksToBounds = YES;
    self.lyricsContainerView.layer.borderWidth = 1.0;

    self.lyricsTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 340, 220)];
    self.lyricsTextView.editable = NO;
    self.lyricsTextView.selectable = YES;
    self.lyricsTextView.drawsBackground = NO;
    self.lyricsTextView.textContainerInset = NSMakeSize(12, 12);
    self.lyricsTextView.textContainer.lineFragmentPadding = 0.0;
    self.lyricsTextView.textContainer.widthTracksTextView = YES;
    self.lyricsTextView.verticallyResizable = YES;
    self.lyricsTextView.horizontallyResizable = NO;
    self.lyricsTextView.minSize = NSMakeSize(0, 0);
    self.lyricsTextView.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    NSString *initialLyricsText = @"가사를 불러오는 중...";
    [self applyLyricsText:initialLyricsText];
    self.lastLyricsText = initialLyricsText;

    self.lyricsScrollView = [[NSScrollView alloc] init];
    self.lyricsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.lyricsScrollView.hasVerticalScroller = YES;
    self.lyricsScrollView.borderType = NSNoBorder;
    self.lyricsScrollView.drawsBackground = NO;
    self.lyricsScrollView.documentView = self.lyricsTextView;
    [self.lyricsContainerView addSubview:self.lyricsScrollView];

    [NSLayoutConstraint activateConstraints:@[
        [self.lyricsContainerView.heightAnchor constraintEqualToConstant:220],
        [self.lyricsScrollView.leadingAnchor constraintEqualToAnchor:self.lyricsContainerView.leadingAnchor],
        [self.lyricsScrollView.trailingAnchor constraintEqualToAnchor:self.lyricsContainerView.trailingAnchor],
        [self.lyricsScrollView.topAnchor constraintEqualToAnchor:self.lyricsContainerView.topAnchor],
        [self.lyricsScrollView.bottomAnchor constraintEqualToAnchor:self.lyricsContainerView.bottomAnchor]
    ]];

    self.quitButton = [self makeQuitButton:@"앱 종료" action:@selector(onQuit)];
    NSStackView *quitRow = [[NSStackView alloc] init];
    quitRow.translatesAutoresizingMaskIntoConstraints = NO;
    quitRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    quitRow.spacing = 8.0;
    NSView *quitSpacer = [[NSView alloc] init];
    [quitSpacer setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [quitRow addArrangedSubview:quitSpacer];
    [quitRow addArrangedSubview:self.quitButton];

    [playerStack addArrangedSubview:albumWrap];
    [playerStack addArrangedSubview:self.titleLabel];
    [playerStack addArrangedSubview:self.artistLabel];
    [playerStack addArrangedSubview:timeRow];
    [playerStack addArrangedSubview:self.progressSlider];
    [playerStack addArrangedSubview:controlsWrap];
    [playerStack setCustomSpacing:12.0 afterView:albumWrap];
    [playerStack setCustomSpacing:4.0 afterView:self.titleLabel];
    [playerStack setCustomSpacing:2.0 afterView:self.artistLabel];
    [playerStack setCustomSpacing:4.0 afterView:timeRow];
    [playerStack setCustomSpacing:12.0 afterView:self.progressSlider];

    [root addArrangedSubview:playerCard];
    [root addArrangedSubview:lyricsTitle];
    [root addArrangedSubview:self.lyricsContainerView];
    [root addArrangedSubview:quitRow];
    [root setCustomSpacing:16.0 afterView:playerCard];
    [root setCustomSpacing:8.0 afterView:lyricsTitle];
    [NSLayoutConstraint activateConstraints:@[
        [playerCard.widthAnchor constraintEqualToAnchor:root.widthAnchor constant:-40.0],
        [lyricsTitle.widthAnchor constraintEqualToAnchor:root.widthAnchor constant:-40.0],
        [self.lyricsContainerView.widthAnchor constraintEqualToAnchor:root.widthAnchor constant:-40.0],
        [quitRow.widthAnchor constraintEqualToAnchor:root.widthAnchor constant:-40.0]
    ]];

    [self.view addSubview:root];

    [NSLayoutConstraint activateConstraints:@[
        [root.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [root.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [root.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [root.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self applyVisualTheme];
}

- (NSButton *)makeQuitButton:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.bordered = NO;
    button.bezelStyle = NSBezelStyleRegularSquare;
    button.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    button.contentTintColor = [NSColor secondaryLabelColor];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button.heightAnchor constraintEqualToConstant:24].active = YES;
    [button.widthAnchor constraintGreaterThanOrEqualToConstant:52].active = YES;
    return button;
}

- (NSButton *)makeIconButton:(NSString *)symbolName
               fallbackTitle:(NSString *)fallbackTitle
                    diameter:(CGFloat)diameter
                   isPrimary:(BOOL)isPrimary
                      action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:@"" target:self action:action];
    button.bezelStyle = NSBezelStyleTexturedRounded;
    button.bordered = NO;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.wantsLayer = YES;
    button.layer.cornerRadius = diameter * 0.5;
    button.layer.masksToBounds = YES;
    button.contentTintColor = isPrimary ? [NSColor controlAccentColor] : [NSColor labelColor];

    NSImage *image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:fallbackTitle];
    if (image) {
        CGFloat iconSize = isPrimary ? 17.0 : 16.0;
        image.size = NSMakeSize(iconSize, iconSize);
        button.image = image;
        button.imagePosition = NSImageOnly;
        button.title = @"";
    } else {
        button.title = fallbackTitle;
    }

    button.toolTip = fallbackTitle;
    [button.heightAnchor constraintEqualToConstant:diameter].active = YES;
    [button.widthAnchor constraintEqualToConstant:diameter].active = YES;
    return button;
}

- (void)applyVisualTheme {
    CGFloat scale = self.view.window.screen.backingScaleFactor;
    if (scale <= 0) {
        scale = NSScreen.mainScreen.backingScaleFactor;
    }
    if (scale <= 0) {
        scale = 2.0;
    }

    NSColor *baseColor = [NSColor windowBackgroundColor];
    NSColor *overlayColor = [baseColor blendedColorWithFraction:0.04 ofColor:[NSColor whiteColor]] ?: baseColor;
    self.view.layer.backgroundColor = overlayColor.CGColor;
    self.view.layer.borderColor = [[NSColor separatorColor] colorWithAlphaComponent:0.40].CGColor;
    self.view.layer.borderWidth = 1.0 / scale;

    NSColor *secondaryButtonColor = [[NSColor controlColor] colorWithAlphaComponent:0.75];
    NSColor *primaryButtonColor = [[NSColor controlAccentColor] colorWithAlphaComponent:0.16];
    self.prevButton.layer.backgroundColor = secondaryButtonColor.CGColor;
    self.playPauseButton.layer.backgroundColor = primaryButtonColor.CGColor;
    self.nextButton.layer.backgroundColor = secondaryButtonColor.CGColor;

    self.lyricsContainerView.layer.backgroundColor = [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.92].CGColor;
    self.lyricsContainerView.layer.borderColor = [[NSColor separatorColor] colorWithAlphaComponent:0.18].CGColor;
}

- (void)applyLyricsText:(NSString *)text {
    NSString *safeText = text ?: @"";
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.minimumLineHeight = 20.0;
    paragraph.maximumLineHeight = 20.0;
    paragraph.paragraphSpacing = 6.0;
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;

    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:14 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor labelColor],
        NSParagraphStyleAttributeName: paragraph
    };
    NSAttributedString *styled = [[NSAttributedString alloc] initWithString:safeText attributes:attributes];
    [self.lyricsTextView.textStorage setAttributedString:styled];
}

- (NSString *)formatTime:(NSTimeInterval)seconds {
    if (!isfinite(seconds) || seconds < 0) {
        seconds = 0;
    }
    NSInteger total = (NSInteger)floor(seconds);
    NSInteger hour = total / 3600;
    NSInteger minute = (total % 3600) / 60;
    NSInteger second = total % 60;
    if (hour > 0) {
        return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)hour, (long)minute, (long)second];
    }
    return [NSString stringWithFormat:@"%ld:%02ld", (long)minute, (long)second];
}

- (void)updatePlaybackIconsForPlaying:(BOOL)isPlaying {
    NSString *symbol = isPlaying ? @"pause.fill" : @"play.fill";
    NSString *title = isPlaying ? @"일시정지" : @"재생";
    NSImage *image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:title];
    if (image) {
        image.size = NSMakeSize(17, 17);
        self.playPauseButton.image = image;
        self.playPauseButton.imagePosition = NSImageOnly;
        self.playPauseButton.title = @"";
    } else {
        self.playPauseButton.title = title;
    }
    self.playPauseButton.toolTip = title;
}

- (void)loadAlbumArt:(NSString *)urlString {
    NSString *normalizedURL = urlString ?: @"";
    BOOL isSameURL = [self.lastAlbumArtURL isEqualToString:normalizedURL];
    if (!isSameURL) {
        self.lastAlbumArtURL = normalizedURL;
        self.lastAlbumArtImage = nil;
        self.lastAlbumArtLoaded = NO;
        self.lastAlbumArtAttemptAt = nil;
    }

    if (normalizedURL.length == 0) {
        self.lastAlbumArtImage = nil;
        self.lastAlbumArtLoaded = NO;
        self.albumImageView.image = [NSImage imageWithSystemSymbolName:@"music.note" accessibilityDescription:nil];
        return;
    }

    if (isSameURL) {
        if (self.lastAlbumArtLoaded) {
            if (self.lastAlbumArtImage) {
                self.albumImageView.image = self.lastAlbumArtImage;
            }
            return;
        }
        if (self.lastAlbumArtAttemptAt &&
            [[NSDate date] timeIntervalSinceDate:self.lastAlbumArtAttemptAt] < kAlbumArtRetryInterval) {
            return;
        }
    }

    NSURL *url = [NSURL URLWithString:normalizedURL];
    if (!url) {
        self.lastAlbumArtImage = nil;
        self.lastAlbumArtLoaded = NO;
        self.albumImageView.image = [NSImage imageWithSystemSymbolName:@"music.note" accessibilityDescription:nil];
        return;
    }
    NSString *requestedURL = [normalizedURL copy];
    self.lastAlbumArtAttemptAt = [NSDate date];
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error || !data) {
            return;
        }
        NSImage *image = [[NSImage alloc] initWithData:data];
        if (!image) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![self.lastAlbumArtURL isEqualToString:requestedURL]) {
                return;
            }
            self.lastAlbumArtImage = image;
            self.albumImageView.image = image;
            self.lastAlbumArtLoaded = YES;
        });
    }] resume];
}

- (void)onPrevious {
    [self.bridge sendCommand:PlaybackCommandPrevious];
    [self refreshSoon];
}

- (void)onPlayPause {
    [self.bridge sendCommand:PlaybackCommandPlayPause];
    [self refreshSoon];
}

- (void)onNext {
    [self.bridge sendCommand:PlaybackCommandNext];
    [self refreshSoon];
}

- (void)onQuit {
    [NSApplication.sharedApplication terminate:nil];
}

- (void)onSeekSliderChanged:(NSSlider *)sender {
    self.isUserDraggingSlider = YES;
    double progress = sender.doubleValue / 100.0;
    [self.bridge seekToProgress:progress];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(300 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        self.isUserDraggingSlider = NO;
        [self refreshSoon];
    });
}

- (void)refreshSoon {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(120 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            PlayerState *state = [self.bridge fetchState];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateWithState:state];
            });
        });
    });
}

@end
