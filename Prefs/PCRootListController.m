#include <spawn.h>
#include <sys/wait.h>
#import "PCRootListController.h"
#import <roothide.h>

#define prefPath jbroot(@"/var/mobile/Library/Preferences/com.cysxl.pancake.plist")

#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
#define PACKAGE_SCHEME "roothide"
#elif defined(THEOS_PACKAGE_SCHEME_ROOTLESS)
#define PACKAGE_SCHEME "rootless"
#elif defined(THEOS_PACKAGE_SCHEME_ROOTFUL)
#define PACKAGE_SCHEME "rootful"
#else
#error theos defined no package scheme
#endif

static const CGFloat kPCIconSide = 80.0;
static const CGFloat kPCHeaderGap = 16.0;
static const CGFloat kPCNameSize = 34.0;
static const CGFloat kPCVersionSize = 15.0;
static const CGFloat kPCSchemeSize = 13.0;
static const CGFloat kPCNameToVersion = 24.0;
static const CGFloat kPCVersionToScheme = 19.0;
static const CGFloat kPCAvatarSide = 38.0;

static UIFont *pcHeaderNameFont(CGFloat size) {
    UIFontDescriptor *bold = [[UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleLargeTitle] fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    return [UIFont fontWithDescriptor:bold size:size];
}

// The name's baseline against the icon's middle, with the block centred on it, so a larger name grows upward only.
static CGFloat pcNameBaselineOffset(CGFloat scale) {
    UIFont *name = pcHeaderNameFont(kPCNameSize * scale);
    UIFont *scheme = [UIFont systemFontOfSize:kPCSchemeSize * scale];
    CGFloat height = name.ascender + (kPCNameToVersion + kPCVersionToScheme) * scale - scheme.descender;
    return name.ascender - height / 2.0;
}

// The row indents its text by the width of its image, so a symbol takes the same square as the avatar.
static UIImage *pcSymbol(NSString *name, CGFloat side) {
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:20.0 weight:UIImageSymbolWeightMedium];
    UIImage *symbol = [UIImage systemImageNamed:name withConfiguration:configuration] ?: [UIImage systemImageNamed:@"link" withConfiguration:configuration];
    if (!symbol) return nil;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side)];
    UIImage *padded = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [symbol drawInRect:CGRectMake((side - symbol.size.width) / 2.0, (side - symbol.size.height) / 2.0, symbol.size.width, symbol.size.height)];
    }];
    return [padded imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@interface PCHeaderCell : PSTableCell
@end

@implementation PCHeaderCell {
    UILabel *_name;
    UILabel *_version;
    UILabel *_scheme;
    UIStackView *_text;
    NSLayoutConstraint *_nameBaseline;
    CGFloat _scale;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:identifier specifier:specifier];
    if (!self) return nil;

    UIImage *image = [UIImage imageNamed:@"icon512" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
    UIImageView *icon = [[UIImageView alloc] initWithImage:image];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.clipsToBounds = YES;
    icon.layer.cornerCurve = kCACornerCurveContinuous;
    icon.layer.cornerRadius = kPCIconSide * 0.225;
    [self.contentView addSubview:icon];

    _name = [[UILabel alloc] init];
    _name.text = @"PanCake";
    // Upstream's wordmark colour, the top of the icon's gradient, and the gradient's bottom in dark mode, where the top is 2.3:1 on black.
    _name.textColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0x49 / 255.0 green:0x98 / 255.0 blue:0xa7 / 255.0 alpha:1.0]
            : [UIColor colorWithRed:0x31 / 255.0 green:0x4c / 255.0 blue:0x5d / 255.0 alpha:1.0];
    }];

    _version = [[UILabel alloc] init];
    _version.text = @"Version " PACKAGE_VERSION;
    _version.textColor = [UIColor systemGrayColor];

    _scheme = [[UILabel alloc] init];
    _scheme.text = @PACKAGE_SCHEME.capitalizedString;
    _scheme.textColor = [UIColor systemGrayColor];

    // Baseline to baseline, so the large name's own leading does not push the two lines under it away.
    _text = [[UIStackView alloc] initWithArrangedSubviews:@[_name, _version, _scheme]];
    _text.axis = UILayoutConstraintAxisVertical;
    _text.alignment = UIStackViewAlignmentLeading;
    _text.baselineRelativeArrangement = YES;
    _text.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_text];
    _nameBaseline = [_name.firstBaselineAnchor constraintEqualToAnchor:icon.centerYAnchor];
    [self applyTextScale:1.0];

    // Icon and text centred as one block, never past the leading margin.
    UILayoutGuide *margins = self.contentView.layoutMarginsGuide;
    UILayoutGuide *block = [[UILayoutGuide alloc] init];
    [self.contentView addLayoutGuide:block];
    NSLayoutConstraint *centred = [block.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor];
    centred.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [icon.widthAnchor constraintEqualToConstant:kPCIconSide],
        [icon.heightAnchor constraintEqualToConstant:kPCIconSide],
        [block.leadingAnchor constraintEqualToAnchor:icon.leadingAnchor],
        [block.trailingAnchor constraintEqualToAnchor:_text.trailingAnchor],
        [icon.leadingAnchor constraintGreaterThanOrEqualToAnchor:margins.leadingAnchor],
        centred,
        [icon.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_text.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:kPCHeaderGap],
        _nameBaseline
    ]];
    return self;
}

// Fonts and spacing scale together so the three lines keep their proportions; the icon never scales.
- (void)applyTextScale:(CGFloat)scale {
    if (scale == _scale) return;
    _scale = scale;
    _name.font = pcHeaderNameFont(kPCNameSize * scale);
    _version.font = [UIFont systemFontOfSize:kPCVersionSize * scale];
    _scheme.font = [UIFont systemFontOfSize:kPCSchemeSize * scale];
    [_text setCustomSpacing:kPCNameToVersion * scale afterView:_name];
    [_text setCustomSpacing:kPCVersionToScheme * scale afterView:_version];
    _nameBaseline.constant = pcNameBaselineOffset(scale);
}

- (void)layoutSubviews {
    CGFloat available = CGRectGetWidth(self.contentView.layoutMarginsGuide.layoutFrame) - kPCIconSide - kPCHeaderGap;
    CGFloat natural = [_name.text sizeWithAttributes:@{NSFontAttributeName: pcHeaderNameFont(kPCNameSize)}].width;
    [self applyTextScale:(available > 0 && natural > available) ? available / natural : 1.0];
    [super layoutSubviews];
}

- (void)setSeparatorStyle:(UITableViewCellSeparatorStyle)style {
    [super setSeparatorStyle:UITableViewCellSeparatorStyleNone];
}

- (void)setBackgroundColor:(UIColor *)color {
    [super setBackgroundColor:[UIColor clearColor]];
}

- (UITableViewCellSelectionStyle)selectionStyle {
    return UITableViewCellSelectionStyleNone;
}

@end

@interface PCCreditCell : PSTableCell
@end

// A row carrying pcBranch hangs off the row above it: a line from that row's avatar bends into it,
// and the row above, carrying pcBranchBelow, drops its separator and draws the top of the line.
@implementation PCCreditCell {
    UIImageView *_avatarView;
    CAShapeLayer *_branch;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier specifier:specifier];
    if (!self) return nil;
    self.detailTextLabel.text = [specifier propertyForKey:@"subtitle"] ?: @"";
    self.detailTextLabel.textColor = [UIColor systemGrayColor];
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    BOOL branch = [[specifier propertyForKey:@"pcBranch"] isEqual:@YES];
    if (branch || [[specifier propertyForKey:@"pcBranchBelow"] isEqual:@YES]) {
        _branch = [CAShapeLayer layer];
        _branch.fillColor = nil;
        _branch.lineWidth = 1.5;
        _branch.lineCap = kCALineCapRound;
        [self.contentView.layer addSublayer:_branch];
    }
    if (branch) {
        // An empty slot as wide as the avatar, so the text lines up with the name above.
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(kPCAvatarSide, 16.0), NO, [UIScreen mainScreen].scale);
        [specifier setProperty:UIGraphicsGetImageFromCurrentImageContext() forKey:@"iconImage"];
        UIGraphicsEndImageContext();
        UIImageSymbolConfiguration *small = [UIImageSymbolConfiguration configurationWithPointSize:11.0 weight:UIImageSymbolWeightSemibold];
        NSString *symbolName = [specifier propertyForKey:@"pcSymbol"];
        NSTextAttachment *mark = [[NSTextAttachment alloc] init];
        mark.image = [[UIImage systemImageNamed:symbolName withConfiguration:small] imageWithTintColor:[UIColor linkColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        NSMutableAttributedString *title = [[NSMutableAttributedString alloc] init];
        if (mark.image) [title appendAttributedString:[NSAttributedString attributedStringWithAttachment:mark]];
        [title appendAttributedString:[[NSAttributedString alloc] initWithString:[@"  " stringByAppendingString:specifier.name ?: @""]
            attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:13.0], NSForegroundColorAttributeName: [UIColor linkColor]}]];
        self.textLabel.attributedText = title;
        // nil rather than empty, so the subtitle style centres the one line.
        self.detailTextLabel.text = nil;
        return self;
    }
    UIImage *avatar = [specifier propertyForKey:@"pcAvatar"];
    if (![avatar isKindOfClass:[UIImage class]]) {
        self.imageView.tintColor = [UIColor secondaryLabelColor];
        return self;
    }
    // An empty image of the right size, so the row lays out before the avatar is drawn into it.
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(kPCAvatarSide, kPCAvatarSide), NO, [UIScreen mainScreen].scale);
    [specifier setProperty:UIGraphicsGetImageFromCurrentImageContext() forKey:@"iconImage"];
    UIGraphicsEndImageContext();
    _avatarView = [[UIImageView alloc] initWithFrame:self.imageView.bounds];
    _avatarView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _avatarView.contentMode = UIViewContentModeScaleAspectFill;
    _avatarView.clipsToBounds = YES;
    _avatarView.layer.cornerRadius = kPCAvatarSide * 0.5;
    _avatarView.layer.minificationFilter = kCAFilterTrilinear;
    _avatarView.image = avatar;
    [self.imageView addSubview:_avatarView];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!_branch) return;
    BOOL branch = [[self.specifier propertyForKey:@"pcBranch"] isEqual:@YES];
    BOOL below = [[self.specifier propertyForKey:@"pcBranchBelow"] isEqual:@YES];
    if (below) {
        for (UIView *view in self.subviews) {
            if ([NSStringFromClass([view class]) hasSuffix:@"SeparatorView"]) view.hidden = YES;
        }
    }
    _branch.strokeColor = [[UIColor systemGray3Color] resolvedColorWithTraitCollection:self.traitCollection].CGColor;
    CGRect slot = [self.contentView convertRect:self.imageView.bounds fromView:self.imageView];
    CGFloat x = round(CGRectGetMidX(slot));
    UIBezierPath *path = [UIBezierPath bezierPath];
    if (branch) {
        CGFloat y = round(CGRectGetMidY(slot)), r = 6.0;
        [path moveToPoint:CGPointMake(x, 0)];
        [path addLineToPoint:CGPointMake(x, y - r)];
        [path addQuadCurveToPoint:CGPointMake(x + r, y) controlPoint:CGPointMake(x, y)];
        [path addLineToPoint:CGPointMake(CGRectGetMaxX(slot), y)];
        // A branch with another below it carries the line on to the next one.
        if (below) {
            [path moveToPoint:CGPointMake(x, y - r)];
            [path addLineToPoint:CGPointMake(x, CGRectGetMaxY(self.contentView.bounds))];
        }
    } else {
        [path moveToPoint:CGPointMake(x, CGRectGetMaxY(slot) + 3.0)];
        [path addLineToPoint:CGPointMake(x, CGRectGetMaxY(self.contentView.bounds))];
    }
    _branch.path = path.CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    [self setNeedsLayout];
}

@end

@interface PCRootListController ()
@property (nonatomic, retain) UIBarButtonItem *respringButton;
@property (nonatomic, retain) NSMutableDictionary *respringBaseline;
@property (nonatomic, retain) NSMutableSet *pendingRespringKeys;
@property (nonatomic, retain) PSSpecifier *hapticSwitch;
@property (nonatomic, retain) NSMutableArray<PSSpecifier *> *hapticRows;
@end

@implementation PCRootListController

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSBundle bundleWithPath:jbroot(@"/Library/Frameworks/AltList.framework")] load];
        self.respringButton = [[UIBarButtonItem alloc] initWithTitle:@"Respring" style:UIBarButtonItemStylePlain target:self action:@selector(respring:)];
    }
    return self;
}

- (id)specifiers {
    if (_specifiers == nil) {
        NSMutableArray *specifiers = [[self loadSpecifiersFromPlistName:@"Prefs" target:self] mutableCopy];
        // The rows under the haptic switch show only while it is on; they follow it directly in the plist.
        self.hapticRows = [NSMutableArray array];
        for (PSSpecifier *specifier in specifiers) {
            NSString *key = [specifier propertyForKey:@"key"];
            if ([key isEqualToString:@"hapticFeedbackEnabled"]) self.hapticSwitch = specifier;
            else if ([key isEqualToString:@"hapticFeedbackStrength"] || [key isEqualToString:@"hapticInDisabledApps"]) [self.hapticRows addObject:specifier];
        }
        id haptic = [[[NSUserDefaults alloc] initWithSuiteName:@"com.cysxl.pancake"] objectForKey:@"hapticFeedbackEnabled"];
        if ([haptic isKindOfClass:[NSNumber class]] && ![haptic boolValue]) [specifiers removeObjectsInArray:self.hapticRows];
        // Prefs.plist opens with a group, so the header gets a section of its own.
        PSSpecifier *header = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:NULL get:NULL detail:nil cell:PSStaticTextCell edit:nil];
        [header setProperty:[PCHeaderCell class] forKey:@"cellClass"];
        [header setProperty:@142 forKey:@"height"];
        [specifiers insertObject:header atIndex:0];
        [self addCreditsTo:specifiers];
        _specifiers = specifiers;
    }
    return _specifiers;
}

- (void)addCreditsTo:(NSMutableArray *)specifiers {
    PSSpecifier *credits = [PSSpecifier preferenceSpecifierNamed:@"Credits" target:self set:NULL get:NULL detail:nil cell:PSGroupCell edit:nil];
    [credits setProperty:@"© CySxL 2026" forKey:@"footerText"];
    [specifiers addObject:credits];
    // name, subtitle, link, picture, symbol; a row with a symbol is a branch of the row above it
    NSArray *rows = @[
        @[@"AnthoPak", @"Original Developer", @"https://github.com/AnthoPakPak", @"", @""],
        @[@"Source Code", @"", @"https://github.com/AnthoPakPak/PanCake", @"", @"chevron.left.forwardslash.chevron.right"],
        @[@"Donate", @"", @"https://bit.ly/AnthoPakDonate", @"", @"heart"],
        @[@"CySxL", @"Maintainer · roothide Port", @"https://github.com/CySxL", @"avatar", @""]
    ];
    PSSpecifier *previous = nil;
    for (NSArray *row in rows) {
        PSSpecifier *credit = [PSSpecifier preferenceSpecifierNamed:row[0] target:self set:NULL get:NULL detail:nil cell:PSLinkCell edit:nil];
        [credit setProperty:[PCCreditCell class] forKey:@"cellClass"];
        [credit setProperty:row[1] forKey:@"subtitle"];
        [credit setProperty:row[2] forKey:@"url"];
        NSString *picture = row[3];
        if ([row[4] length]) {
            [credit setProperty:@YES forKey:@"pcBranch"];
            [credit setProperty:row[4] forKey:@"pcSymbol"];
            [credit setProperty:@34 forKey:@"height"];
            [previous setProperty:@YES forKey:@"pcBranchBelow"];
        } else {
            UIImage *avatar = picture.length ? [UIImage imageNamed:picture inBundle:[NSBundle bundleForClass:[self class]] withConfiguration:nil] : nil;
            if (avatar) [credit setProperty:avatar forKey:@"pcAvatar"];
            else [credit setProperty:pcSymbol(@"chevron.left.forwardslash.chevron.right", kPCAvatarSide) forKey:@"iconImage"];
        }
        credit->action = @selector(openCredit:);
        [specifiers addObject:credit];
        previous = credit;
    }
}

- (void)openCredit:(PSSpecifier *)specifier {
    NSURL *url = [NSURL URLWithString:[specifier propertyForKey:@"url"]];
    if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)respring:(id)sender {
    // jbroot() has no C-string form here, so translate as NSString first.
    const char *killallPath = [jbroot(@"/usr/bin/killall") fileSystemRepresentation];
    const char *argv[] = {"killall", "-9", "SpringBoard", NULL};
    pid_t pid = 0;
    if (posix_spawn(&pid, killallPath, NULL, NULL, (char *const *)argv, NULL) != 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Respring Failed" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    waitpid(pid, NULL, 0);
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];

    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) return;

    if (specifier == self.hapticSwitch && self.hapticRows.count) {
        BOOL on = [value isKindOfClass:[NSNumber class]] && [value boolValue];
        BOOL shown = [_specifiers containsObject:self.hapticRows.firstObject];
        if (on && !shown) [self insertContiguousSpecifiers:self.hapticRows afterSpecifier:specifier animated:YES];
        else if (!on && shown) [self removeContiguousSpecifiers:self.hapticRows animated:YES];
    }

    NSDictionary *existingPrefs = [NSDictionary dictionaryWithContentsOfFile:prefPath];
    NSUInteger capacity = existingPrefs ? existingPrefs.count + 1 : 1;
    NSMutableDictionary *preferences = [[NSMutableDictionary alloc] initWithCapacity:capacity];

    if (existingPrefs) {
        [preferences addEntriesFromDictionary:existingPrefs];
    }

    [self updateRespringButtonForKey:key value:value previous:existingPrefs[key] specifier:specifier];

    preferences[key] = value;
    [preferences writeToFile:prefPath atomically:YES];

    CFStringRef post = (CFStringRef)CFBridgingRetain(specifier.properties[@"PostNotification"]);
    if (post) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), post, NULL, NULL, YES);
        CFRelease(post);
    }
}

// Only these three are read at load time. The button stays while any of them
// differs from what it was when the page opened, and goes once they all match.
- (void)updateRespringButtonForKey:(NSString *)key value:(id)value previous:(id)previous specifier:(PSSpecifier *)specifier {
    if (![@[@"enabled", @"hapticFeedbackEnabled", @"hapticInDisabledApps"] containsObject:key]) return;

    if (!self.respringBaseline) self.respringBaseline = [NSMutableDictionary dictionary];
    if (!self.pendingRespringKeys) self.pendingRespringKeys = [NSMutableSet set];

    if (!self.respringBaseline[key]) {
        id baseline = previous ?: [specifier propertyForKey:@"default"];
        self.respringBaseline[key] = baseline ?: [NSNull null];
    }

    id baseline = self.respringBaseline[key];
    if (![baseline isEqual:[NSNull null]] && [value isEqual:baseline]) {
        [self.pendingRespringKeys removeObject:key];
    } else {
        [self.pendingRespringKeys addObject:key];
    }

    self.navigationItem.rightBarButtonItem = self.pendingRespringKeys.count > 0 ? self.respringButton : nil;
}

@end
