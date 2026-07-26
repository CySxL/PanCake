#import <UIKit/UIKit.h>
#import <roothide.h>
#import <Foundation/Foundation.h>
#import <Cephei/HBPreferences.h>

#define PLIST_FILE jbroot(@"/var/mobile/Library/Preferences/com.anthopak.pancake.plist")

static inline id pref_getValue(NSString *key) {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PLIST_FILE];
    return dict[key];
}

static inline BOOL pref_getBool(NSString *key) {
    id val = pref_getValue(key);
    return val ? [val boolValue] : NO;
}

@interface _UINavigationInteractiveTransitionBase : NSObject
@property (assign,nonatomic) UIPanGestureRecognizer * gestureRecognizer;
-(void)handleNavigationTransition:(UIPanGestureRecognizer*)arg1 ;
-(void)startInteractiveTransition;
@end

@interface _UINavigationInteractiveTransition : _UINavigationInteractiveTransitionBase
@end

@interface UINavigationController (Custom)<UIGestureRecognizerDelegate>
@property (strong, nonatomic) _UINavigationInteractiveTransition * _cachedInteractionController;
// Holds the most recently popped view controller so it can be pushed back in.
@property (nonatomic, retain) UIViewController *pancake_poppedViewController;
+ (UIViewController*) topMostController;
- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)panGestureRecognizer;
- (void)pancake_handlePushBackGesture:(UIScreenEdgePanGestureRecognizer *)gesture;
-(void)_updateInteractiveTransition:(double)arg1 ;
-(void)_finishInteractiveTransition:(double)arg1 transitionContext:(id)arg2 ;
-(void)_cancelInteractiveTransition:(double)arg1 transitionContext:(id)arg2 ;
@end

@interface UIView (Custom)
// Namespaced (pancake_) to avoid colliding with other tweaks / app selectors on UIView.
@property (nonatomic, retain) UIPanGestureRecognizer *pancake_dismissPanGestureRecognizer;
@property (nonatomic, retain) UIScreenEdgePanGestureRecognizer *pancake_pushBackPoppedVCEdgePanGestureRecognizer;
@end
