#import <UIKit/UIKit.h>
#import <roothide.h>
#import <Foundation/Foundation.h>

#define PLIST_FILE jbroot(@"/var/mobile/Library/Preferences/com.cysxl.pancake.plist")

@interface _UINavigationInteractiveTransitionBase : NSObject
-(void)handleNavigationTransition:(UIPanGestureRecognizer*)arg1 ;
@end

@interface _UINavigationInteractiveTransition : _UINavigationInteractiveTransitionBase
@end

// The gestures get their own delegate rather than the navigation controller, or an
// app's own UINavigationController subclass shadows the delegate methods and the
// direction filter silently stops running there.
@interface PanCakeGestureDelegate : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UINavigationController *navigationController;
@end

@interface UINavigationController (Custom)
@property (strong, nonatomic) _UINavigationInteractiveTransition * _cachedInteractionController;
@property (nonatomic, retain) UIViewController *pancake_poppedViewController;
@property (nonatomic, retain) PanCakeGestureDelegate *pancake_gestureDelegate;
- (void)pancake_handlePushBackGesture:(UIScreenEdgePanGestureRecognizer *)gesture;
-(void)_finishInteractiveTransition:(double)arg1 transitionContext:(id)arg2 ;
@end

// These land on UIView, which every app and tweak shares, hence the prefix.
@interface UIView (Custom)
@property (nonatomic, retain) UIPanGestureRecognizer *pancake_dismissPanGestureRecognizer;
@property (nonatomic, retain) UIScreenEdgePanGestureRecognizer *pancake_pushBackPoppedVCEdgePanGestureRecognizer;
@end
