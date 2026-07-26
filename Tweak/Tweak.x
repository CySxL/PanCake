#import "Tweak.h"

HBPreferences *preferences;
BOOL enabled;
BOOL backGestureOnWholePageEnabled;
BOOL restorePreviousVCEnabled;
BOOL hapticFeedbackEnabled;
BOOL springboardInjectionEnabled;
NSInteger hapticFeedbackStrength;
NSString *appName;
BOOL shouldRecognizeSimultaneousGestures;

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
    UIViewController *viewController = [self topViewController];
    if (!viewController || !viewController.viewLoaded) return;

    UIView *viewForGesture = viewController.view;
    BOOL isNotRootViewController = self.viewControllers.count > 0 && viewController != self.viewControllers[0];

    // --- Back gesture on whole page (interactive dismiss) ---
    if (backGestureOnWholePageEnabled && isNotRootViewController) {
        if (!viewForGesture.pancake_dismissPanGestureRecognizer) {
            if ([self._cachedInteractionController respondsToSelector:@selector(handleNavigationTransition:)]) {
                UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self._cachedInteractionController action:@selector(handleNavigationTransition:)];
                pan.delegate = self;
                viewForGesture.pancake_dismissPanGestureRecognizer = pan;
                [viewForGesture addGestureRecognizer:pan];
            }
        }
    }

    // --- Restore previous page (swipe back in from the trailing edge) ---
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

// Capture the popped controller so the restore gesture can push it back.
- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    UIViewController *popped = %orig;
    if (restorePreviousVCEnabled && popped) {
        self.pancake_poppedViewController = popped;
    }
    return popped;
}

// A normal push invalidates any stored popped controller (unless it is the restore itself).
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (viewController != self.pancake_poppedViewController) {
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
    if (shouldRecognizeSimultaneousGestures) {
        if (gestureRecognizer == gestureRecognizer.view.pancake_dismissPanGestureRecognizer) {
            if ([appName isEqualToString:@"com.facebook.Messenger"]) {
                return panGestureIsSwipingLeftToRight((UIPanGestureRecognizer *)gestureRecognizer.view.pancake_dismissPanGestureRecognizer);
            }
            return YES;
        }
    }
    return NO;
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (gestureRecognizer == gestureRecognizer.view.pancake_dismissPanGestureRecognizer) {
        if ([touch.view isKindOfClass:[UISlider class]]) return NO;
    }
    return YES;
}
%end

%hook UIView
%property (nonatomic, retain) UIPanGestureRecognizer *pancake_dismissPanGestureRecognizer;
%property (nonatomic, retain) UIScreenEdgePanGestureRecognizer *pancake_pushBackPoppedVCEdgePanGestureRecognizer;
%end

%hook UINavigationController
%property (nonatomic, retain) UIViewController *pancake_poppedViewController;
%end

%hook _UINavigationInteractiveTransitionBase
-(void)handleNavigationTransition:(UIPanGestureRecognizer*)arg1 {
    %orig;
}
%end
%end

%group HapticFeedback
%hook UINavigationController
-(void)_finishInteractiveTransition:(double)arg1 transitionContext:(id)arg2 {
    %orig;
    if (hapticFeedbackEnabled) {
        // Five distinct intensities (labels: Soft, Light, Rigid, Medium, Heavy).
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

    BOOL isApplication = [executablePath containsString:@"/Application/"] || [executablePath containsString:@"/Applications/"];
    BOOL isSpringBoard = [processName isEqualToString:@"SpringBoard"];
    BOOL isFileProvider = [[processName lowercaseString] containsString:@"fileprovider"];

    BOOL skip = [executablePath containsString:@".appex/"];
    if (!skip) {
        NSString *skipTargets[] = {@"AdSheet", @"CoreAuthUI", @"InCallService", @"MessagesNotificationViewService", @"PassbookUIService"};
        size_t skipCount = sizeof(skipTargets) / sizeof(skipTargets[0]);
        for (size_t i = 0; i < skipCount; i++) {
            if ([processName isEqualToString:skipTargets[i]]) {
                skip = YES;
                break;
            }
        }
    }
    return !isFileProvider && (isApplication || isSpringBoard) && !skip;
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
            appName = [[NSBundle mainBundle] bundleIdentifier];

            if ([appName isEqualToString:@"com.apple.springboard"] && !springboardInjectionEnabled) {
                return;
            }

            BOOL isBlacklisted = NO;
            NSFileManager *fileManager = [NSFileManager defaultManager];

            if (![fileManager fileExistsAtPath:PLIST_FILE]) {
                NSArray *defaultBlacklistedApps = @[
                    @"com.atebits.Tweetie2", @"com.burbn.instagram", @"com.facebook.Facebook",
                    @"com.christianselig.Apollo", @"ph.telegra.Telegraph", @"com.reddit.Reddit",
                    @"com.spotify.client", @"com.hegenberg.BetterTouchToolRemote", @"com.intsig.CamScanner"
                ];
                NSMutableDictionary *plistDict = [[NSMutableDictionary alloc] initWithCapacity:1];
                plistDict[@"blacklistedApps"] = defaultBlacklistedApps;
                [plistDict writeToFile:PLIST_FILE atomically:YES];
            } else {
                NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PLIST_FILE];
                if (dict) {
                    if (dict[@"blacklistedApps"]) {
                        NSArray *blacklisted = dict[@"blacklistedApps"];
                        if ([blacklisted containsObject:appName]) {
                            isBlacklisted = YES;
                        }
                    } else {
                        if (dict[appName] && [dict[appName] boolValue]) {
                            isBlacklisted = YES;
                        }
                    }
                }
            }

            // Only init the gesture group if not blacklisted and at least one gesture feature is on.
            if (appName && !isBlacklisted && (backGestureOnWholePageEnabled || restorePreviousVCEnabled)) {
                if ([appName isEqualToString:@"com.apple.MobileSMS"] || [appName isEqualToString:@"com.facebook.Messenger"]) {
                    shouldRecognizeSimultaneousGestures = YES;
                }
                %init(PanCake);
            }

            if (hapticFeedbackEnabled) {
                %init(HapticFeedback);
            }
        }
    }
}
