#import <UIKit/UIKit.h>
#import <roothide.h>
#import <Foundation/Foundation.h>
#import <Cephei/HBPreferences.h>

#define PLIST_FILE jbroot(@"/var/mobile/Library/Preferences/com.anthopak.pancake.plist")

@interface _UINavigationInteractiveTransitionBase : NSObject
-(void)handleNavigationTransition:(UIPanGestureRecognizer*)arg1 ;
@end

@interface _UINavigationInteractiveTransition : _UINavigationInteractiveTransitionBase
@end

@interface UINavigationController (Custom)<UIGestureRecognizerDelegate>
@property (strong, nonatomic) _UINavigationInteractiveTransition * _cachedInteractionController;
@property (nonatomic, retain) UIViewController *pancake_poppedViewController;
- (void)pancake_handlePushBackGesture:(UIScreenEdgePanGestureRecognizer *)gesture;
-(void)_finishInteractiveTransition:(double)arg1 transitionContext:(id)arg2 ;
@end

// These land on UIView, which every app and tweak shares, hence the prefix.
@interface UIView (Custom)
@property (nonatomic, retain) UIPanGestureRecognizer *pancake_dismissPanGestureRecognizer;
@property (nonatomic, retain) UIScreenEdgePanGestureRecognizer *pancake_pushBackPoppedVCEdgePanGestureRecognizer;
@end
