#import "PopoverViewController.h"
#import "SafariBridge.h"
#import "PlayerState.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

@interface YTMControlButton : NSButton
@property (nonatomic, strong) NSColor *baseColor;
@property (nonatomic, strong) NSColor *hoverColor;
@property (nonatomic, strong) NSColor *pressedColor;
@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, assign) BOOL hovered;
@property (nonatomic, strong) NSTrackingArea *trackingArea;
- (void)applyCurrentAppearance;
@end

@implementation YTMControlButton

- (instancetype)init {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        self.bordered = NO;
        self.bezelStyle = NSBezelStyleRegularSquare;
        self.wantsLayer = YES;
        self.baseColor = [NSColor colorWithWhite:1 alpha:0.08];
        self.hoverColor = [NSColor colorWithWhite:1 alpha:0.14];
        self.pressedColor = [NSColor colorWithWhite:1 alpha:0.2];
        self.cornerRadius = 12;
    }
    return self;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (self.trackingArea) {
        [self removeTrackingArea:self.trackingArea];
    }
    self.trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                     options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp | NSTrackingInVisibleRect
                                                       owner:self
                                                    userInfo:nil];
    [self addTrackingArea:self.trackingArea];
}

- (void)mouseEntered:(NSEvent *)event {
    self.hovered = YES;
    [self applyCurrentAppearance];
}

- (void)mouseExited:(NSEvent *)event {
    self.hovered = NO;
    [self applyCurrentAppearance];
}

- (void)highlight:(BOOL)flag {
    [super highlight:flag];
    [self applyCurrentAppearance];
}

- (void)applyCurrentAppearance {
    NSColor *bg = self.baseColor;
    if (self.isHighlighted) {
        bg = self.pressedColor ?: bg;
    } else if (self.hovered) {
        bg = self.hoverColor ?: bg;
    }
    self.layer.cornerRadius = self.cornerRadius;
    self.layer.backgroundColor = bg.CGColor;
}

@end

@interface PopoverViewController ()
@property (nonatomic, strong) SafariBridge *bridge;
@property (nonatomic, strong) NSImageView *albumImageView;
@property (nonatomic, strong) NSSlider *progressSlider;
@property (nonatomic, strong) NSTextField *currentTimeLabel;
@property (nonatomic, strong) NSTextField *durationTimeLabel;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *artistLabel;
@property (nonatomic, strong) NSTextView *lyricsTextView;
@property (nonatomic, strong) NSScrollView *lyricsScrollView;
@property (nonatomic, strong) YTMControlButton *prevButton;
@property (nonatomic, strong) YTMControlButton *playPauseButton;
@property (nonatomic, strong) YTMControlButton *nextButton;
@property (nonatomic, strong) NSView *nowPlayingCard;
@property (nonatomic, strong) NSView *lyricsCard;
@property (nonatomic, strong) NSButton *quitButton;
@property (nonatomic, strong) NSTimer *lyricsScrollIdleTimer;
@property (nonatomic, assign) BOOL isUserScrollingLyrics;
@property (nonatomic, copy) NSString *pendingLyricsText;
@property (nonatomic, strong) NSColor *pendingLyricsColor;
@property (nonatomic, assign) BOOL isUserDraggingSlider;
@property (nonatomic, copy) NSString *lastAlbumArtURL;
@property (nonatomic, copy) NSString *pendingAlbumArtURL;
@property (nonatomic, assign) NSTimeInterval lastAlbumArtAttemptTime;
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
    NSVisualEffectView *effectView = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, 400, 540)];
    effectView.material = NSVisualEffectMaterialHUDWindow;
    effectView.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    effectView.state = NSVisualEffectStateActive;
    self.view = effectView;
    [self setupUI];
}

- (void)updateWithState:(PlayerState *)state {
    if (!self.isViewLoaded) {
        (void)self.view;
    }

    self.titleLabel.stringValue = [self displayTitleFromState:state];
    self.artistLabel.stringValue = state.artist ?: @"";
    if (!self.isUserDraggingSlider) {
        self.progressSlider.doubleValue = [state progress] * 100.0;
    }
    self.currentTimeLabel.stringValue = [self formattedTime:state.currentSeconds];
    self.durationTimeLabel.stringValue = state.durationSeconds > 0 ? [self formattedTime:state.durationSeconds] : @"--:--";

    NSString *lyricsText = state.lyrics.length > 0
        ? state.lyrics
        : @"가사를 불러오지 못했습니다.\nYouTube Music 가사 탭을 열어두면 인식률이 올라갑니다.";
    NSColor *lyricsColor = state.lyrics.length > 0 ? [NSColor labelColor] : [NSColor tertiaryLabelColor];
    [self updateLyricsIfNeeded:lyricsText textColor:lyricsColor];

    [self updatePlaybackIconsForPlaying:state.isPlaying];

    [self loadAlbumArt:state.albumArtURL];
}

- (void)updateLyricsIfNeeded:(NSString *)text textColor:(NSColor *)textColor {
    NSString *nextText = text ?: @"";
    BOOL textChanged = ![self.lyricsTextView.string isEqualToString:nextText];
    BOOL colorChanged = ![self.lyricsTextView.textColor isEqual:textColor];
    if (!textChanged && !colorChanged) {
        return;
    }

    if (self.isUserScrollingLyrics && textChanged) {
        self.pendingLyricsText = nextText;
        self.pendingLyricsColor = textColor;
        return;
    }

    NSScrollView *scrollView = self.lyricsScrollView ?: self.lyricsTextView.enclosingScrollView;
    NSPoint previousOrigin = scrollView.contentView.bounds.origin;

    if (textChanged) {
        self.lyricsTextView.string = nextText;
    }
    if (colorChanged) {
        self.lyricsTextView.textColor = textColor;
    }

    if (textChanged && scrollView) {
        [self.lyricsTextView.layoutManager ensureLayoutForTextContainer:self.lyricsTextView.textContainer];
        CGFloat documentHeight = NSHeight(scrollView.documentView.bounds);
        CGFloat visibleHeight = NSHeight(scrollView.contentView.bounds);
        CGFloat maxY = MAX(0, documentHeight - visibleHeight);
        NSPoint clamped = NSMakePoint(previousOrigin.x, MIN(previousOrigin.y, maxY));
        [scrollView.contentView scrollToPoint:clamped];
        [scrollView reflectScrolledClipView:scrollView.contentView];
    }
}

- (void)setupUI {
    NSStackView *root = [[NSStackView alloc] init];
    root.translatesAutoresizingMaskIntoConstraints = NO;
    root.orientation = NSUserInterfaceLayoutOrientationVertical;
    root.spacing = 12;
    root.edgeInsets = NSEdgeInsetsMake(16, 16, 16, 16);

    self.nowPlayingCard = [self makeCardViewWithCornerRadius:14];
    NSStackView *nowPlayingStack = [self makeVerticalStack];
    nowPlayingStack.edgeInsets = NSEdgeInsetsMake(12, 12, 12, 12);
    nowPlayingStack.spacing = 10;

    self.albumImageView = [[NSImageView alloc] init];
    self.albumImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.albumImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    self.albumImageView.wantsLayer = YES;
    self.albumImageView.layer.cornerRadius = 12;
    self.albumImageView.layer.masksToBounds = YES;
    self.albumImageView.image = [NSImage imageWithSystemSymbolName:@"music.note" accessibilityDescription:nil];

    NSView *albumWrap = [[NSView alloc] init];
    albumWrap.translatesAutoresizingMaskIntoConstraints = NO;
    [albumWrap addSubview:self.albumImageView];
    [NSLayoutConstraint activateConstraints:@[
        [self.albumImageView.centerXAnchor constraintEqualToAnchor:albumWrap.centerXAnchor],
        [self.albumImageView.topAnchor constraintEqualToAnchor:albumWrap.topAnchor],
        [self.albumImageView.bottomAnchor constraintEqualToAnchor:albumWrap.bottomAnchor],
        [self.albumImageView.widthAnchor constraintEqualToConstant:176],
        [self.albumImageView.heightAnchor constraintEqualToConstant:176]
    ]];

    self.titleLabel = [NSTextField labelWithString:@""];
    self.titleLabel.font = [NSFont systemFontOfSize:22 weight:NSFontWeightSemibold];
    self.titleLabel.alignment = NSTextAlignmentCenter;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.titleLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    self.artistLabel = [NSTextField labelWithString:@""];
    self.artistLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightRegular];
    self.artistLabel.textColor = [NSColor secondaryLabelColor];
    self.artistLabel.alignment = NSTextAlignmentCenter;

    self.progressSlider = [[NSSlider alloc] init];
    self.progressSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressSlider.minValue = 0;
    self.progressSlider.maxValue = 100;
    self.progressSlider.doubleValue = 0;
    self.progressSlider.continuous = YES;
    self.progressSlider.target = self;
    self.progressSlider.action = @selector(onSeekSliderChanged:);
    self.progressSlider.controlSize = NSControlSizeSmall;

    self.currentTimeLabel = [NSTextField labelWithString:@"00:00"];
    self.currentTimeLabel.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];
    self.currentTimeLabel.textColor = [NSColor tertiaryLabelColor];

    self.durationTimeLabel = [NSTextField labelWithString:@"--:--"];
    self.durationTimeLabel.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];
    self.durationTimeLabel.textColor = [NSColor tertiaryLabelColor];
    self.durationTimeLabel.alignment = NSTextAlignmentRight;

    NSStackView *timeRow = [[NSStackView alloc] init];
    timeRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    timeRow.distribution = NSStackViewDistributionFill;
    timeRow.alignment = NSLayoutAttributeCenterY;
    [timeRow addArrangedSubview:self.currentTimeLabel];
    [timeRow addArrangedSubview:[NSView new]];
    [timeRow addArrangedSubview:self.durationTimeLabel];

    NSStackView *controls = [[NSStackView alloc] init];
    controls.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    controls.spacing = 12;
    controls.distribution = NSStackViewDistributionFill;
    controls.alignment = NSLayoutAttributeCenterY;
    controls.detachesHiddenViews = YES;

    self.prevButton = [self makeIconButton:@"backward.fill" fallbackTitle:@"이전" action:@selector(onPrevious) size:44 accent:NO];
    self.playPauseButton = [self makeIconButton:@"play.fill" fallbackTitle:@"재생" action:@selector(onPlayPause) size:52 accent:YES];
    self.nextButton = [self makeIconButton:@"forward.fill" fallbackTitle:@"다음" action:@selector(onNext) size:44 accent:NO];

    [controls addArrangedSubview:[NSView new]];

    [controls addArrangedSubview:self.prevButton];
    [controls addArrangedSubview:self.playPauseButton];
    [controls addArrangedSubview:self.nextButton];
    [controls addArrangedSubview:[NSView new]];

    NSTextField *lyricsTitle = [NSTextField labelWithString:@"가사"];
    lyricsTitle.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
    lyricsTitle.textColor = [NSColor labelColor];

    self.lyricsTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 340, 210)];
    self.lyricsTextView.editable = NO;
    self.lyricsTextView.font = [NSFont systemFontOfSize:14 weight:NSFontWeightRegular];
    self.lyricsTextView.string = @"가사를 불러오는 중...";
    self.lyricsTextView.drawsBackground = NO;
    self.lyricsTextView.textContainerInset = NSMakeSize(6, 8);
    self.lyricsTextView.textColor = [NSColor labelColor];
    NSMutableParagraphStyle *lyricsParagraph = [[NSMutableParagraphStyle alloc] init];
    lyricsParagraph.lineSpacing = 4;
    self.lyricsTextView.defaultParagraphStyle = lyricsParagraph;

    self.lyricsScrollView = [[NSScrollView alloc] init];
    self.lyricsScrollView.hasVerticalScroller = YES;
    self.lyricsScrollView.borderType = NSNoBorder;
    self.lyricsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.lyricsScrollView.drawsBackground = NO;
    self.lyricsScrollView.automaticallyAdjustsContentInsets = YES;
    self.lyricsScrollView.documentView = self.lyricsTextView;
    self.lyricsScrollView.contentView.postsBoundsChangedNotifications = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onLyricsScrollBoundsChanged:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:self.lyricsScrollView.contentView];

    [NSLayoutConstraint activateConstraints:@[
        [self.lyricsScrollView.heightAnchor constraintEqualToConstant:210]
    ]];

    self.lyricsCard = [self makeCardViewWithCornerRadius:14];
    NSStackView *lyricsStack = [self makeVerticalStack];
    lyricsStack.edgeInsets = NSEdgeInsetsMake(12, 12, 12, 12);
    lyricsStack.spacing = 8;
    [lyricsStack addArrangedSubview:lyricsTitle];
    [lyricsStack addArrangedSubview:self.lyricsScrollView];
    [self.lyricsCard addSubview:lyricsStack];

    [NSLayoutConstraint activateConstraints:@[
        [lyricsStack.leadingAnchor constraintEqualToAnchor:self.lyricsCard.leadingAnchor],
        [lyricsStack.trailingAnchor constraintEqualToAnchor:self.lyricsCard.trailingAnchor],
        [lyricsStack.topAnchor constraintEqualToAnchor:self.lyricsCard.topAnchor],
        [lyricsStack.bottomAnchor constraintEqualToAnchor:self.lyricsCard.bottomAnchor]
    ]];

    [nowPlayingStack addArrangedSubview:albumWrap];
    [nowPlayingStack addArrangedSubview:self.titleLabel];
    [nowPlayingStack addArrangedSubview:self.artistLabel];
    [nowPlayingStack addArrangedSubview:self.progressSlider];
    [nowPlayingStack addArrangedSubview:timeRow];
    [nowPlayingStack addArrangedSubview:controls];

    [self.nowPlayingCard addSubview:nowPlayingStack];
    [NSLayoutConstraint activateConstraints:@[
        [nowPlayingStack.leadingAnchor constraintEqualToAnchor:self.nowPlayingCard.leadingAnchor],
        [nowPlayingStack.trailingAnchor constraintEqualToAnchor:self.nowPlayingCard.trailingAnchor],
        [nowPlayingStack.topAnchor constraintEqualToAnchor:self.nowPlayingCard.topAnchor],
        [nowPlayingStack.bottomAnchor constraintEqualToAnchor:self.nowPlayingCard.bottomAnchor]
    ]];

    self.quitButton = [NSButton buttonWithTitle:@"앱 종료" target:self action:@selector(onQuit)];
    self.quitButton.bordered = NO;
    self.quitButton.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    self.quitButton.contentTintColor = [NSColor secondaryLabelColor];
    self.quitButton.bezelStyle = NSBezelStyleRegularSquare;
    self.quitButton.alignment = NSTextAlignmentRight;
    self.quitButton.translatesAutoresizingMaskIntoConstraints = NO;

    [root addArrangedSubview:self.nowPlayingCard];
    [root addArrangedSubview:self.lyricsCard];
    [root addArrangedSubview:self.quitButton];
    [self.quitButton.heightAnchor constraintEqualToConstant:24].active = YES;

    [self.view addSubview:root];

    [NSLayoutConstraint activateConstraints:@[
        [root.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [root.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [root.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [root.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.lyricsScrollIdleTimer invalidate];
}

- (void)onLyricsScrollBoundsChanged:(NSNotification *)notification {
    self.isUserScrollingLyrics = YES;
    [self.lyricsScrollIdleTimer invalidate];
    self.lyricsScrollIdleTimer = [NSTimer scheduledTimerWithTimeInterval:0.35
                                                                   target:self
                                                                 selector:@selector(onLyricsScrollDidSettle)
                                                                 userInfo:nil
                                                                  repeats:NO];
}

- (void)onLyricsScrollDidSettle {
    self.isUserScrollingLyrics = NO;
    [self.lyricsScrollIdleTimer invalidate];
    self.lyricsScrollIdleTimer = nil;

    if (self.pendingLyricsText.length > 0 || self.pendingLyricsColor != nil) {
        NSString *text = self.pendingLyricsText ?: self.lyricsTextView.string;
        NSColor *color = self.pendingLyricsColor ?: self.lyricsTextView.textColor;
        self.pendingLyricsText = nil;
        self.pendingLyricsColor = nil;
        [self updateLyricsIfNeeded:text textColor:color];
    }
}

- (NSView *)makeCardViewWithCornerRadius:(CGFloat)radius {
    NSView *card = [[NSView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.wantsLayer = YES;
    card.layer.cornerRadius = radius;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [NSColor colorWithWhite:1 alpha:0.12].CGColor;
    card.layer.backgroundColor = [NSColor colorWithWhite:1 alpha:0.08].CGColor;
    card.layer.masksToBounds = YES;
    return card;
}

- (NSStackView *)makeVerticalStack {
    NSStackView *stack = [[NSStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeCenterX;
    stack.distribution = NSStackViewDistributionFill;
    return stack;
}

- (YTMControlButton *)makeIconButton:(NSString *)symbolName
                        fallbackTitle:(NSString *)fallbackTitle
                               action:(SEL)action
                                 size:(CGFloat)size
                               accent:(BOOL)isAccent {
    YTMControlButton *button = [[YTMControlButton alloc] init];
    button.target = self;
    button.action = action;
    button.translatesAutoresizingMaskIntoConstraints = NO;

    if (isAccent) {
        NSColor *accent = [NSColor colorWithRed:1.0 green:0.0 blue:0.28 alpha:1.0];
        button.baseColor = accent;
        button.hoverColor = [accent blendedColorWithFraction:0.16 ofColor:[NSColor whiteColor]];
        button.pressedColor = [accent blendedColorWithFraction:0.2 ofColor:[NSColor blackColor]];
        button.cornerRadius = size / 2.0;
        button.contentTintColor = [NSColor whiteColor];
    } else {
        button.baseColor = [NSColor colorWithWhite:1 alpha:0.08];
        button.hoverColor = [NSColor colorWithWhite:1 alpha:0.14];
        button.pressedColor = [NSColor colorWithWhite:1 alpha:0.2];
        button.cornerRadius = 12;
        button.contentTintColor = [NSColor labelColor];
    }

    NSImage *image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:fallbackTitle];
    if (image) {
        image.size = NSMakeSize(isAccent ? 20 : 16, isAccent ? 20 : 16);
        button.image = image;
        button.imagePosition = NSImageOnly;
        button.title = @"";
    } else {
        button.title = fallbackTitle;
    }

    button.toolTip = fallbackTitle;
    [button.heightAnchor constraintEqualToConstant:size].active = YES;
    [button.widthAnchor constraintEqualToConstant:size].active = YES;
    [button applyCurrentAppearance];
    return button;
}

- (void)updatePlaybackIconsForPlaying:(BOOL)isPlaying {
    NSString *symbol = isPlaying ? @"pause.fill" : @"play.fill";
    NSString *title = isPlaying ? @"일시정지" : @"재생";
    NSImage *image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:title];
    if (image) {
        image.size = NSMakeSize(20, 20);
        CATransition *transition = [CATransition animation];
        transition.type = kCATransitionFade;
        transition.duration = 0.1;
        [self.playPauseButton.layer addAnimation:transition forKey:@"ytm-playpause-fade"];
        self.playPauseButton.image = image;
        self.playPauseButton.imagePosition = NSImageOnly;
        self.playPauseButton.title = @"";
    } else {
        self.playPauseButton.title = title;
    }
    self.playPauseButton.toolTip = title;
}

- (void)viewDidAppear {
    [super viewDidAppear];
    [self animateCardsOnOpen];
}

- (void)animateCardsOnOpen {
    [self animateCard:self.nowPlayingCard delay:0.0];
    [self animateCard:self.lyricsCard delay:0.03];
}

- (void)animateCard:(NSView *)card delay:(NSTimeInterval)delay {
    card.wantsLayer = YES;
    card.alphaValue = 0.0;
    card.layer.transform = CATransform3DMakeTranslation(0, 8, 0);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.12;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            card.animator.alphaValue = 1.0;
        } completionHandler:nil];

        CABasicAnimation *slide = [CABasicAnimation animationWithKeyPath:@"transform"];
        slide.fromValue = [NSValue valueWithCATransform3D:CATransform3DMakeTranslation(0, 8, 0)];
        slide.toValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
        slide.duration = 0.12;
        slide.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [card.layer addAnimation:slide forKey:@"ytm-card-slide"];
        card.layer.transform = CATransform3DIdentity;
    });
}

- (NSString *)displayTitleFromState:(PlayerState *)state {
    NSString *title = state.title.length > 0 ? state.title : @"Not Playing";
    if (title.length > 24) {
        return [[title substringToIndex:24] stringByAppendingString:@"…"];
    }
    return title;
}

- (NSString *)formattedTime:(double)seconds {
    if (seconds < 0 || !isfinite(seconds)) {
        return @"00:00";
    }
    NSInteger total = (NSInteger)llround(seconds);
    NSInteger hours = total / 3600;
    NSInteger minutes = (total % 3600) / 60;
    NSInteger secs = total % 60;
    if (hours > 0) {
        return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)hours, (long)minutes, (long)secs];
    }
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)secs];
}

- (void)loadAlbumArt:(NSString *)urlString {
    NSString *normalizedURL = urlString ?: @"";
    if (normalizedURL.length == 0) {
        self.lastAlbumArtURL = @"";
        self.pendingAlbumArtURL = nil;
        self.lastAlbumArtAttemptTime = 0;
        self.albumImageView.image = [NSImage imageWithSystemSymbolName:@"music.note" accessibilityDescription:nil];
        return;
    }
    if ([self.lastAlbumArtURL isEqualToString:normalizedURL]) {
        return;
    }

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if ([self.pendingAlbumArtURL isEqualToString:normalizedURL] &&
        (now - self.lastAlbumArtAttemptTime) < 2.0) {
        return;
    }

    if ([normalizedURL hasPrefix:@"data:image/"]) {
        NSImage *inlineImage = [self imageFromDataURL:normalizedURL];
        if (inlineImage) {
            self.albumImageView.image = inlineImage;
            self.lastAlbumArtURL = normalizedURL;
            self.pendingAlbumArtURL = nil;
            return;
        }
    }

    if ([normalizedURL hasPrefix:@"blob:"]) {
        return;
    }

    if ([normalizedURL hasPrefix:@"/"]) {
        normalizedURL = [@"https://music.youtube.com" stringByAppendingString:normalizedURL];
    }

    NSURL *url = [NSURL URLWithString:normalizedURL];
    if (!url) {
        return;
    }
    self.pendingAlbumArtURL = normalizedURL;
    self.lastAlbumArtAttemptTime = now;

    NSString *requestedURL = [normalizedURL copy];
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error || !data) {
            return;
        }
        NSImage *image = [[NSImage alloc] initWithData:data];
        if (!image) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![self.pendingAlbumArtURL isEqualToString:requestedURL]) {
                return;
            }
            self.albumImageView.image = image;
            self.lastAlbumArtURL = requestedURL;
            self.pendingAlbumArtURL = nil;
        });
    }] resume];
}

- (NSImage *)imageFromDataURL:(NSString *)dataURL {
    NSRange comma = [dataURL rangeOfString:@","];
    if (comma.location == NSNotFound || comma.location + 1 >= dataURL.length) {
        return nil;
    }
    NSString *meta = [dataURL substringToIndex:comma.location];
    NSString *payload = [dataURL substringFromIndex:(comma.location + 1)];
    NSData *data = nil;

    if ([meta rangeOfString:@";base64"].location != NSNotFound) {
        data = [[NSData alloc] initWithBase64EncodedString:payload options:NSDataBase64DecodingIgnoreUnknownCharacters];
    } else {
        NSString *decoded = [payload stringByRemovingPercentEncoding] ?: payload;
        data = [decoded dataUsingEncoding:NSUTF8StringEncoding];
    }
    if (!data) {
        return nil;
    }
    return [[NSImage alloc] initWithData:data];
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
