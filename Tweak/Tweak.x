#import "Tweak.h"

HBPreferences *preferences;
BOOL enabled;
BOOL backGestureOnWholePageEnabled;
BOOL restorePreviousVCEnabled;
BOOL hapticFeedbackEnabled;
BOOL springboardInjectionEnabled;
NSInteger hapticFeedbackStrength;
BOOL shouldRecognizeSimultaneousGestures;
BOOL appIsMessenger;

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

%group PanCake
%hook UINavigationController
-(void)_layoutTopViewController {
    %orig;
    if (!backGestureOnWholePageEnabled && !restorePreviousVCEnabled) return;

    UIViewController *viewController = [self topViewController];
    if (!viewController || !viewController.viewLoaded) return;

    UIView *viewForGesture = viewController.view;

    if (backGestureOnWholePageEnabled) {
        NSArray *stack = self.viewControllers;
        BOOL isNotRootViewController = stack.count > 0 && viewController != stack[0];
        if (isNotRootViewController && !viewForGesture.pancake_dismissPanGestureRecognizer) {
            if ([self._cachedInteractionController respondsToSelector:@selector(handleNavigationTransition:)]) {
                UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self._cachedInteractionController action:@selector(handleNavigationTransition:)];
                pan.delegate = self;
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
            edge.delegate = self;
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

%new
- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)panGestureRecognizer {
    UIView *view = panGestureRecognizer.view;
    if (panGestureRecognizer == view.pancake_dismissPanGestureRecognizer) {
        return panGestureIsSwipingLeftToRight(panGestureRecognizer);
    }
    if (panGestureRecognizer == view.pancake_pushBackPoppedVCEdgePanGestureRecognizer) {
        return self.pancake_poppedViewController != nil;
    }
    return YES;
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (!shouldRecognizeSimultaneousGestures) return NO;

    UIPanGestureRecognizer *dismissPan = gestureRecognizer.view.pancake_dismissPanGestureRecognizer;
    if (gestureRecognizer != dismissPan) return NO;

    // Messenger has its own horizontal pan on the same view.
    return appIsMessenger ? panGestureIsSwipingLeftToRight(dismissPan) : YES;
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // Ordered so that a touch anywhere but a slider costs no associated-object read.
    if (![touch.view isKindOfClass:[UISlider class]]) return YES;
    return gestureRecognizer != gestureRecognizer.view.pancake_dismissPanGestureRecognizer;
}
%end

%hook UIView
%property (nonatomic, retain) UIPanGestureRecognizer *pancake_dismissPanGestureRecognizer;
%property (nonatomic, retain) UIScreenEdgePanGestureRecognizer *pancake_pushBackPoppedVCEdgePanGestureRecognizer;
%end

%hook UINavigationController
%property (nonatomic, retain) UIViewController *pancake_poppedViewController;
%end
%end

// Its own group so that it still runs in apps that are blacklisted for gestures.
%group HapticFeedback
%hook UINavigationController
-(void)_finishInteractiveTransition:(double)arg1 transitionContext:(id)arg2 {
    %orig;
    // Also gated on the gesture switch: with that off the only thing finishing an
    // interactive transition is Apple's own edge swipe, which is not ours to change.
    if (hapticFeedbackEnabled && backGestureOnWholePageEnabled) {
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
    if (!isApplication && ![processName isEqualToString:@"SpringBoard"]) return NO;

    if ([executablePath containsString:@".appex/"]) return NO;
    if ([[processName lowercaseString] containsString:@"fileprovider"]) return NO;

    NSString *skipTargets[] = {@"AdSheet", @"CoreAuthUI", @"InCallService", @"MessagesNotificationViewService", @"PassbookUIService"};
    size_t skipCount = sizeof(skipTargets) / sizeof(skipTargets[0]);
    for (size_t i = 0; i < skipCount; i++) {
        if ([processName isEqualToString:skipTargets[i]]) return NO;
    }
    return YES;
}

static BOOL appIsBlacklisted(NSString *bundleID) {
    if (!bundleID) return NO;

    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PLIST_FILE];
    if (![dict isKindOfClass:[NSDictionary class]]) return NO;

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

static void writeDefaultBlacklist(void) {
    NSArray *defaultBlacklistedApps = @[
        @"com.atebits.Tweetie2", @"com.burbn.instagram", @"com.facebook.Facebook",
        @"com.christianselig.Apollo", @"ph.telegra.Telegraph", @"com.reddit.Reddit",
        @"com.spotify.client", @"com.hegenberg.BetterTouchToolRemote", @"com.intsig.CamScanner"
    ];
    [@{@"blacklistedApps": defaultBlacklistedApps} writeToFile:PLIST_FILE atomically:YES];
}

%ctor {
    @autoreleasepool {
        if (!tweakShouldLoad()) return;

        preferences = [[HBPreferences alloc] initWithIdentifier:@"com.anthopak.pancake"];
        [preferences registerBool:&enabled default:YES forKey:@"enabled"];
        [preferences registerBool:&backGestureOnWholePageEnabled default:YES forKey:@"backGestureOnWholePageEnabled"];
        [preferences registerBool:&restorePreviousVCEnabled default:NO forKey:@"restorePreviousVCEnabled"];
        [preferences registerBool:&hapticFeedbackEnabled default:YES forKey:@"hapticFeedbackEnabled"];
        [preferences registerInteger:&hapticFeedbackStrength default:0 forKey:@"hapticFeedbackStrength"];
        [preferences registerBool:&springboardInjectionEnabled default:NO forKey:@"springboardInjectionEnabled"];

        if (enabled) {
            NSString *appName = [[NSBundle mainBundle] bundleIdentifier];

            if ([appName isEqualToString:@"com.apple.springboard"] && !springboardInjectionEnabled) {
                return;
            }

            if (![[NSFileManager defaultManager] fileExistsAtPath:PLIST_FILE]) {
                writeDefaultBlacklist();
            }
            BOOL isBlacklisted = appIsBlacklisted(appName);

            if (appName && !isBlacklisted && (backGestureOnWholePageEnabled || restorePreviousVCEnabled)) {
                appIsMessenger = [appName isEqualToString:@"com.facebook.Messenger"];
                shouldRecognizeSimultaneousGestures = appIsMessenger || [appName isEqualToString:@"com.apple.MobileSMS"];
                %init(PanCake);
            }

            if (hapticFeedbackEnabled) {
                %init(HapticFeedback);
            }
        }
    }
}
