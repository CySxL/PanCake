#include <spawn.h>
#include <sys/wait.h>
#import "Preferences.h"
#import <roothide.h>

#define prefPath jbroot(@"/var/mobile/Library/Preferences/com.anthopak.pancake.plist")
#define headerColor [UIColor colorWithRed:0.192 green:0.298 blue:0.365 alpha:1]

static NSInteger headerPaddingTopBottom = 40;
static NSInteger headerPaddingLeftRight = 10;

@interface PCPrefsListController ()
@property (nonatomic, retain) UIColor *savedTintColor;
@end

@implementation PCPrefsListController

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSBundle bundleWithPath:jbroot(@"/Library/Frameworks/AltList.framework")] load];
        [self setupNavigationTitleView];
        [self setupNavigationRespringButton];
    }
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    [self setupHeaderView];
    self.table.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    
    if (@available(iOS 15.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = [self getHeaderColorFromColor:headerColor];
        appearance.shadowColor = [UIColor clearColor];
        
        self.navigationItem.standardAppearance = appearance;
        self.navigationItem.scrollEdgeAppearance = appearance;
        self.navigationItem.compactAppearance = appearance;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    CGRect frame = self.table.bounds;
    frame.origin.y = -frame.size.height;

    UINavigationBar *navBar = self.navigationController.navigationController.navigationBar ?: self.navigationController.navigationBar;
    
    if (navBar) {
        self.savedTintColor = navBar.tintColor;
        navBar.tintColor = [UIColor whiteColor];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    UINavigationBar *navBar = self.navigationController.navigationController.navigationBar ?: self.navigationController.navigationBar;
    if (navBar && self.savedTintColor) {
        navBar.tintColor = self.savedTintColor;
    }
}

- (id)specifiers {
    if(_specifiers == nil) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Prefs" target:self];
    }
    return _specifiers;
}

- (void)respring:(id)sender {
    // Resolve killall through the NSString jbroot() variant, then hand posix_spawn a
    // guaranteed-valid C path via fileSystemRepresentation (avoids relying on a
    // C-string jbroot() overload existing in the SDK).
    const char *killallPath = [jbroot(@"/usr/bin/killall") fileSystemRepresentation];
    const char *argv[] = {"killall", "-9", "SpringBoard", NULL};
    pid_t pid = 0;
    if (posix_spawn(&pid, killallPath, NULL, NULL, (char *const *)argv, NULL) == 0) {
        waitpid(pid, NULL, 0);
    }
}

-(void)setupNavigationTitleView {
    self.navigationItem.titleView = [UIView new];
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0,0,10,10)];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = @"PanCake";
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.navigationItem.titleView addSubview:self.titleLabel];

    self.iconView = [[UIImageView alloc] initWithFrame:CGRectMake(0,0,10,10)];
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.image = [UIImage imageWithContentsOfFile:jbroot(@"/Library/PreferenceBundles/PanCakePrefs.bundle/icon_transparent.png")];    
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.alpha = 0.0;
    [self.navigationItem.titleView addSubview:self.iconView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.navigationItem.titleView.topAnchor],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.navigationItem.titleView.leadingAnchor],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.navigationItem.titleView.trailingAnchor],
        [self.titleLabel.bottomAnchor constraintEqualToAnchor:self.navigationItem.titleView.bottomAnchor],
        [self.iconView.topAnchor constraintEqualToAnchor:self.navigationItem.titleView.topAnchor],
        [self.iconView.leadingAnchor constraintEqualToAnchor:self.navigationItem.titleView.leadingAnchor],
        [self.iconView.trailingAnchor constraintEqualToAnchor:self.navigationItem.titleView.trailingAnchor],
        [self.iconView.bottomAnchor constraintEqualToAnchor:self.navigationItem.titleView.bottomAnchor],
    ]];
}

-(void)setupNavigationRespringButton {
    self.respringButton = [[UIBarButtonItem alloc] initWithTitle:@"Respring" style:UIBarButtonItemStylePlain target:self action:@selector(respring:)];
    self.respringButton.tintColor = [UIColor whiteColor];
}

-(void)setupHeaderView {
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0,0,200,200)];
    self.headerImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0,0,200,200)];
    self.headerImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.headerImageView.image = [UIImage imageWithContentsOfFile:jbroot(@"/Library/PreferenceBundles/PanCakePrefs.bundle/header.png")];
    self.headerImageView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.headerView addSubview:self.headerImageView];
    [NSLayoutConstraint activateConstraints:@[
        [self.headerImageView.topAnchor constraintEqualToAnchor:self.headerView.topAnchor constant:headerPaddingTopBottom],
        [self.headerImageView.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor constant:headerPaddingLeftRight],
        [self.headerImageView.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor constant:-headerPaddingLeftRight],
        [self.headerImageView.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:-headerPaddingTopBottom],
    ]];

    self.table.tableHeaderView = self.headerView;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat offsetY = scrollView.contentOffset.y;
    if (offsetY > 70) {
        [UIView animateWithDuration:0.2 animations:^{
            self.iconView.alpha = 1.0;
            self.titleLabel.alpha = 0.0;
        }];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            self.iconView.alpha = 0.0;
            self.titleLabel.alpha = 1.0;
        }];
    }
    
    if (offsetY > -headerPaddingTopBottom/2) offsetY = -headerPaddingTopBottom/2;
    self.headerImageView.frame = CGRectMake(headerPaddingLeftRight, offsetY + 64 + headerPaddingTopBottom, self.headerView.frame.size.width - headerPaddingLeftRight*2, 200 - offsetY - 64 - headerPaddingTopBottom*2);
}

- (double)tableView:(UITableView*)tableView heightForHeaderInSection:(NSInteger)section {
    // Sections: 0 top-spacer, 1 back-gesture, 2 restore, 3 blacklist, 4 haptic,
    //           5 springboard, 6 my-other-tweaks, 7 empty-spacer (before social).
    if (section == 0 || section == 7) return 0;
    if (section == 6) return 60;
    return 45;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];
    
    NSDictionary *existingPrefs = [NSDictionary dictionaryWithContentsOfFile:prefPath];
    NSUInteger capacity = existingPrefs ? existingPrefs.count + 1 : 1;
    NSMutableDictionary *preferences = [[NSMutableDictionary alloc] initWithCapacity:capacity];
    
    if (existingPrefs) {
        [preferences addEntriesFromDictionary:existingPrefs];
    }

    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"enabled"] || [key isEqualToString:@"hapticFeedbackEnabled"]) {
        self.navigationItem.rightBarButtonItem = self.respringButton;
    }

    preferences[key] = value;
    [preferences writeToFile:prefPath atomically:YES];
    
    CFStringRef post = (CFStringRef)CFBridgingRetain(specifier.properties[@"PostNotification"]);
    if (post) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), post, NULL, NULL, YES);
        CFRelease(post);
    }
}

-(UIColor*)getHeaderColorFromColor:(UIColor*)fromColor {
    CGFloat a1 = 0.85;
    UIColor *backgroundColor = [UIColor whiteColor];
    CGFloat r2 = 0.0, g2 = 0.0, b2 = 0.0, a2 = 0.0;
    [backgroundColor getRed:&r2 green:&g2 blue:&b2 alpha:&a2];

    CGFloat r3 = 0.0, g3 = 0.0, b3 = 0.0, a3 = 0.0;
    [fromColor getRed:&r3 green:&g3 blue:&b3 alpha:&a3];

    CGFloat r1 = (r3 - r2 + r2 * a1) / a1;
    CGFloat g1 = (g3 - g2 + g2 * a1) / a1;
    CGFloat b1 = (b3 - b2 + b2 * a1) / a1;

    return [UIColor colorWithRed:r1 green:g1 blue:b1 alpha:1];
}
@end
