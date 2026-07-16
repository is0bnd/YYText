//
//  YYTextLazyViewAttachment.h
//  YYTextDemo
//
//  Created by admin on 2023/12/13.
//  Copyright © 2023 ibireme. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol YYTextLazyViewAttachment <NSObject>

/// Returns the attachment view associated with a specific rendering target.
- (UIView *)viewForTargetView:(UIView *)targetView;

/// Removes the attachment view associated with a specific rendering target.
- (void)removeViewForTargetView:(UIView *)targetView;

/// Removes all attachment views created by this provider.
- (void)removeAllViews;

@end

NS_ASSUME_NONNULL_END
