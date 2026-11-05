#import "Tweak.h"

static BOOL enabled;
static BOOL backGestureOnWholePageEnabled;
static BOOL restorePreviousVCEnabled;
static BOOL hapticFeedbackEnabled;
static BOOL hapticInDisabledApps;
static BOOL appIsDisabled;
static NSInteger hapticFeedbackStrength;
static BOOL shouldRecognizeSimultaneousGestures;
static BOOL appIsMessenger;

static BOOL panGestureIsSwipingLeftToRight(UIPanGestureRecognizer *panGest) {
    CGPoint velocity = [panGest velocityInView:panGest.view];
    if (fabs(velocity.x) > fabs(velocity.y)) {
        BOOL deviceIsRTL = [UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
        if ((!deviceIsRTL && velocity.x > 0) || (deviceIsRTL && velocity.x < 0)) {
            return YES;
        }
    }
    return NO;
}

@implementation PanCakeGestureDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)panGestureRecognizer {
    UIView *view = panGestureRecognizer.view;
    if (panGestureRecognizer == view.pancake_dismissPanGestureRecognizer) {
        // Switched off mid-session, a recognizer already attached stays attached.
        // Refusing to begin is what makes the off position take effect there.
        if (!enabled || !backGestureOnWholePageEnabled) return NO;
        return panGestureIsSwipingLeftToRight(panGestureRecognizer);
    }
    if (panGestureRecognizer == view.pancake_pushBackPoppedVCEdgePanGestureRecognizer) {
        if (!enabled || !restorePreviousVCEnabled) return NO;
        return self.navigationController.pancake_poppedViewController != nil;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (!shouldRecognizeSimultaneousGestures) return NO;

    UIPanGestureRecognizer *dismissPan = gestureRecognizer.view.pancake_dismissPanGestureRecognizer;
    if (gestureRecognizer != dismissPan) return NO;

    // Messenger has its own horizontal pan on the same view.
    return appIsMessenger ? panGestureIsSwipingLeftToRight(dismissPan) : YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // Ordered so that a touch anywhere but a slider costs no associated-object read.
    if (![touch.view isKindOfClass:[UISlider class]]) return YES;
    return gestureRecognizer != gestureRecognizer.view.pancake_dismissPanGestureRecognizer;
}

@end

static PanCakeGestureDelegate *gestureDelegateFor(UINavigationController *navigationController) {
    PanCakeGestureDelegate *gestureDelegate = navigationController.pancake_gestureDelegate;
    if (!gestureDelegate) {
        gestureDelegate = [[PanCakeGestureDelegate alloc] init];
        gestureDelegate.navigationController = navigationController;
        navigationController.pancake_gestureDelegate = gestureDelegate;
    }
    return gestureDelegate;
}

static void clearPoppedViewController(UINavigationController *navigationController) {
    if (navigationController.pancake_poppedViewController) {
        navigationController.pancake_poppedViewController = nil;
    }
}

%group PanCake
%hook UINavigationController
-(void)_layoutTopViewController {
    %orig;
    if (!enabled || (!backGestureOnWholePageEnabled && !restorePreviousVCEnabled)) return;

    UIViewController *viewController = [self topViewController];
    if (!viewController || !viewController.viewLoaded) return;

    UIView *viewForGesture = viewController.view;

    if (backGestureOnWholePageEnabled) {
        NSArray *stack = self.viewControllers;
        BOOL isNotRootViewController = stack.count > 0 && viewController != stack[0];
        if (isNotRootViewController && !viewForGesture.pancake_dismissPanGestureRecognizer) {
            if ([self._cachedInteractionController respondsToSelector:@selector(handleNavigationTransition:)]) {
                UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self._cachedInteractionController action:@selector(handleNavigationTransition:)];
                pan.delegate = gestureDelegateFor(self);
                viewForGesture.pancake_dismissPanGestureRecognizer = pan;
                [viewForGesture addGestureRecognizer:pan];
            }
        }
    }

    if (restorePreviousVCEnabled) {
        if (!viewForGesture.pancake_pushBackPoppedVCEdgePanGestureRecognizer) {
            UIScreenEdgePanGestureRecognizer *edge = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(pancake_handlePushBackGesture:)];
            BOOL deviceIsRTL = [UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
            edge.edges = deviceIsRTL ? UIRectEdgeLeft : UIRectEdgeRight;
            edge.delegate = gestureDelegateFor(self);
            viewForGesture.pancake_pushBackPoppedVCEdgePanGestureRecognizer = edge;
            [viewForGesture addGestureRecognizer:edge];
        }
    }
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    UIViewController *popped = %orig;
    if (restorePreviousVCEnabled && popped) {
        self.pancake_poppedViewController = popped;
    }
    return popped;
}

// A stack that changes by anything but a single pop leaves nothing worth pushing
// back, and holding the controller past that point retains a page no stack owns.
- (NSArray<UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated {
    NSArray<UIViewController *> *popped = %orig;
    if (popped.count > 0) {
        clearPoppedViewController(self);
    }
    return popped;
}

- (NSArray<UIViewController *> *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated {
    NSArray<UIViewController *> *popped = %orig;
    if (popped.count > 0) {
        clearPoppedViewController(self);
    }
    return popped;
}

- (void)setViewControllers:(NSArray<UIViewController *> *)viewControllers {
    %orig;
    clearPoppedViewController(self);
}

- (void)setViewControllers:(NSArray<UIViewController *> *)viewControllers animated:(BOOL)animated {
    %orig;
    clearPoppedViewController(self);
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    UIViewController *popped = self.pancake_poppedViewController;
    if (popped && viewController != popped) {
        self.pancake_poppedViewController = nil;
    }
    %orig;
}

%new
- (void)pancake_handlePushBackGesture:(UIScreenEdgePanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIViewController *popped = self.pancake_poppedViewController;
        if (popped) {
            self.pancake_poppedViewController = nil; // cleared before push so pushViewController: doesn't re-nil it
            [self pushViewController:popped animated:YES];
        }
    }
}

%end

%hook UIView
%property (nonatomic, retain) UIPanGestureRecognizer *pancake_dismissPanGestureRecognizer;
%property (nonatomic, retain) UIScreenEdgePanGestureRecognizer *pancake_pushBackPoppedVCEdgePanGestureRecognizer;
%end

%hook UINavigationController
%property (nonatomic, retain) UIViewController *pancake_poppedViewController;
%property (nonatomic, retain) PanCakeGestureDelegate *pancake_gestureDelegate;
%end
%end

// Its own group so that it can still run in apps that are blacklisted for gestures.
%group HapticFeedback
%hook UINavigationController
-(void)_finishInteractiveTransition:(double)arg1 transitionContext:(id)arg2 {
    %orig;
    // Also gated on the gesture switch: with that off the only thing finishing an
    // interactive transition is Apple's own edge swipe, which is not ours to change.
    if (enabled && hapticFeedbackEnabled && backGestureOnWholePageEnabled && (!appIsDisabled || hapticInDisabledApps)) {
        UIImpactFeedbackStyle style = UIImpactFeedbackStyleLight;
        switch (hapticFeedbackStrength) {
            case 0: style = UIImpactFeedbackStyleSoft;   break;
            case 1: style = UIImpactFeedbackStyleLight;  break;
            case 2: style = UIImpactFeedbackStyleRigid;  break;
            case 3: style = UIImpactFeedbackStyleMedium; break;
            case 4: style = UIImpactFeedbackStyleHeavy;  break;
            default: style = UIImpactFeedbackStyleLight; break;
        }
        [[[UIImpactFeedbackGenerator alloc] initWithStyle:style] impactOccurred];
    }
}
%end
%end

static BOOL tweakShouldLoad(void) {
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    if (args.count == 0) return NO;

    NSString *executablePath = args[0];
    NSString *processName = [executablePath lastPathComponent];

    // Every process that links UIKit runs this, so the processes we want nothing to
    // do with leave before the string work the rest of the test needs.
    BOOL isApplication = [executablePath containsString:@"/Application/"] || [executablePath containsString:@"/Applications/"];
    if (!isApplication) return NO;

    if ([executablePath containsString:@".appex/"]) return NO;
    if ([[processName lowercaseString] containsString:@"fileprovider"]) return NO;

    NSString *skipTargets[] = {@"AdSheet", @"CoreAuthUI", @"InCallService", @"MessagesNotificationViewService", @"PassbookUIService"};
    size_t skipCount = sizeof(skipTargets) / sizeof(skipTargets[0]);
    for (size_t i = 0; i < skipCount; i++) {
        if ([processName isEqualToString:skipTargets[i]]) return NO;
    }
    return YES;
}

static NSDictionary *readPrefs(void) {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PLIST_FILE];
    return [dict isKindOfClass:[NSDictionary class]] ? dict : nil;
}

static BOOL prefBool(NSDictionary *dict, NSString *key, BOOL fallback) {
    id value = dict[key];
    return ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]]) ? [value boolValue] : fallback;
}

static NSInteger prefInteger(NSDictionary *dict, NSString *key, NSInteger fallback) {
    id value = dict[key];
    return ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]]) ? [value integerValue] : fallback;
}

// A missing key takes the default; a missing file is the caller's call.
static void applyPrefs(NSDictionary *dict) {
    enabled = prefBool(dict, @"enabled", YES);
    backGestureOnWholePageEnabled = prefBool(dict, @"backGestureOnWholePageEnabled", YES);
    restorePreviousVCEnabled = prefBool(dict, @"restorePreviousVCEnabled", NO);
    hapticFeedbackEnabled = prefBool(dict, @"hapticFeedbackEnabled", YES);
    hapticFeedbackStrength = prefInteger(dict, @"hapticFeedbackStrength", 0);
    hapticInDisabledApps = prefBool(dict, @"hapticInDisabledApps", YES);
}

// The settings page writes the file itself before posting, so it is current here;
// cfprefsd's own copy reaches the file about two seconds later.
static void reloadPrefs(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *dict = readPrefs();
        if (dict) applyPrefs(dict);
    });
}

static BOOL observingPrefs;

__attribute__((destructor)) static void stopObservingPrefs(void) {
    if (!observingPrefs) return;
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), &observingPrefs, CFSTR("com.cysxl.pancake/ReloadPrefs"), NULL);
}

static BOOL appIsBlacklisted(NSDictionary *dict, NSString *bundleID) {
    if (!bundleID || !dict) return NO;

    id blacklisted = dict[@"blacklistedApps"];
    if (blacklisted) {
        return [blacklisted isKindOfClass:[NSArray class]] && [blacklisted containsObject:bundleID];
    }

    // Before 2.7 each bundle id was its own key.
    id legacy = dict[bundleID];
    if ([legacy isKindOfClass:[NSNumber class]] || [legacy isKindOfClass:[NSString class]]) {
        return [legacy boolValue];
    }
    return NO;
}

static NSDictionary *writeDefaultBlacklist(void) {
    NSArray *defaultBlacklistedApps = @[
        @"com.atebits.Tweetie2", @"com.burbn.instagram", @"com.facebook.Facebook",
        @"com.christianselig.Apollo", @"ph.telegra.Telegraph", @"com.reddit.Reddit",
        @"com.spotify.client", @"com.hegenberg.BetterTouchToolRemote", @"com.intsig.CamScanner"
    ];
    NSDictionary *dict = @{@"blacklistedApps": defaultBlacklistedApps};
    [dict writeToFile:PLIST_FILE atomically:YES];
    return dict;
}

%ctor {
    @autoreleasepool {
        if (!tweakShouldLoad()) return;

        NSDictionary *prefs = readPrefs();
        applyPrefs(prefs);

        if (enabled) {
            NSString *appName = [[NSBundle mainBundle] bundleIdentifier];

            // Only a file that is not there gets the defaults. An unreadable one is
            // left alone, or every switch in it would be lost.
            if (![[NSFileManager defaultManager] fileExistsAtPath:PLIST_FILE]) {
                prefs = writeDefaultBlacklist();
            }
            appIsDisabled = appIsBlacklisted(prefs, appName);

            BOOL hooked = NO;
            if (appName && !appIsDisabled && (backGestureOnWholePageEnabled || restorePreviousVCEnabled)) {
                appIsMessenger = [appName isEqualToString:@"com.facebook.Messenger"];
                shouldRecognizeSimultaneousGestures = appIsMessenger || [appName isEqualToString:@"com.apple.MobileSMS"];
                %init(PanCake);
                hooked = YES;
            }

            if (hapticFeedbackEnabled && (!appIsDisabled || hapticInDisabledApps)) {
                %init(HapticFeedback);
                hooked = YES;
            }

            if (hooked && !observingPrefs) {
                CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), &observingPrefs, reloadPrefs, CFSTR("com.cysxl.pancake/ReloadPrefs"), NULL, CFNotificationSuspensionBehaviorCoalesce);
                observingPrefs = YES;
            }
        }
    }
}
