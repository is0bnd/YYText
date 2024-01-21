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

@property (strong, nonnull, readonly) UIView *view;

@end

NS_ASSUME_NONNULL_END
