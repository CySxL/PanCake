#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>

@interface PCPrefsListController : PSListController

@property (nonatomic, retain) UILabel *titleLabel;
@property (nonatomic, retain) UIImageView *iconView;
@property (nonatomic, retain) UIBarButtonItem *respringButton;
@property (nonatomic, retain) UIView *headerView;
@property (nonatomic, retain) UIImageView *headerImageView;

- (void)respring:(id)sender;
- (void)openLink:(PSSpecifier *)specifier;

@end

// Stands in for CepheiPrefs' HBLinkTableCell, which this bundle stopped linking.
@interface PCLinkTableCell : PSTableCell
@end