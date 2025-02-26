//
//  YYTextAsyncLayer.m
//  YYText <https://github.com/ibireme/YYText>
//
//  Created by ibireme on 15/4/11.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "YYTextAsyncLayer.h"
#import <libkern/OSAtomic.h>
#import <stdatomic.h>


/// Global display queue, used for content rendering.
static dispatch_queue_t YYTextAsyncLayerGetDisplayQueue(void) {
#define MAX_QUEUE_COUNT 16
    static int queueCount;
    static dispatch_queue_t queues[MAX_QUEUE_COUNT];
    static dispatch_once_t onceToken;
    static atomic_int counter;
    
    dispatch_once(&onceToken, ^{
        atomic_init(&counter, 0);
        queueCount = (int)[NSProcessInfo processInfo].activeProcessorCount;
        queueCount = queueCount < 1 ? 1 : queueCount > MAX_QUEUE_COUNT ? MAX_QUEUE_COUNT : queueCount;
        if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0) {
            for (NSUInteger i = 0; i < queueCount; i++) {
                dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
                queues[i] = dispatch_queue_create("com.ibireme.text.render", attr);
            }
        } else {
            for (NSUInteger i = 0; i < queueCount; i++) {
                queues[i] = dispatch_queue_create("com.ibireme.text.render", DISPATCH_QUEUE_SERIAL);
                dispatch_set_target_queue(queues[i], dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
            }
        }
    });
    atomic_fetch_add(&counter, 1);
    return queues[counter % queueCount];
#undef MAX_QUEUE_COUNT
}

static dispatch_queue_t YYTextAsyncLayerGetReleaseQueue(void) {
#ifdef YYDispatchQueuePool_h
    return YYDispatchQueueGetForQOS(NSQualityOfServiceDefault);
#else
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
#endif
}


/// a thread safe incrementing counter.
@interface _YYTextSentinel : NSObject
/// Returns the current value of the counter.
@property (atomic, readonly) int32_t value;
/// Increase the value atomically. @return The new value.
- (int32_t)increase;
@end

@implementation _YYTextSentinel {
    atomic_int _value;
}
- (int32_t)value {
    return _value;
}
- (int32_t)increase {
    atomic_fetch_add(&_value, 1);
    return _value;
}
@end


@implementation YYTextAsyncLayerDisplayTask
@end


@implementation YYTextAsyncLayer {
    _YYTextSentinel *_sentinel;
}

#pragma mark - Override

+ (id)defaultValueForKey:(NSString *)key {
    if ([key isEqualToString:@"displaysAsynchronously"]) {
        return @(YES);
    } else {
        return [super defaultValueForKey:key];
    }
}

- (instancetype)init {
    self = [super init];
    static CGFloat scale; //global
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        scale = [UIScreen mainScreen].scale;
    });
    self.contentsScale = scale;
    _sentinel = [_YYTextSentinel new];
    _displaysAsynchronously = YES;
    return self;
}

- (void)dealloc {
    [_sentinel increase];
}

- (void)setNeedsDisplay {
    [self _cancelAsyncDisplay];
    [super setNeedsDisplay];
}

- (void)display {
    super.contents = super.contents;
    [self _displayAsync:_displaysAsynchronously];
}

#pragma mark - Private

- (void)_displayAsync:(BOOL)async {
    __strong id<YYTextAsyncLayerDelegate> delegate = (id)self.delegate;
    YYTextAsyncLayerDisplayTask *task = [delegate newAsyncDisplayTask];
    if (!task.display) {
        if (task.willDisplay) task.willDisplay(self);
        self.contents = nil;
        if (task.didDisplay) task.didDisplay(self, YES);
        return;
    }
    
    if (async) {
        if (task.willDisplay) task.willDisplay(self);
        _YYTextSentinel *sentinel = _sentinel;
        int32_t value = sentinel.value;
        BOOL (^isCancelled)(void) = ^BOOL() {
            return value != sentinel.value;
        };
        CGSize size = self.bounds.size;
        BOOL opaque = self.opaque;
        CGFloat scale = self.contentsScale;
        CGColorRef backgroundColor = (opaque && self.backgroundColor) ? CGColorRetain(self.backgroundColor) : NULL;
        if (size.width < 1 || size.height < 1) {
            CGImageRef image = (__bridge_retained CGImageRef)(self.contents);
            self.contents = nil;
            if (image) {
                dispatch_async(YYTextAsyncLayerGetReleaseQueue(), ^{
                    CFRelease(image);
                });
            }
            if (task.didDisplay) task.didDisplay(self, YES);
            CGColorRelease(backgroundColor);
            return;
        }
        
        dispatch_async(YYTextAsyncLayerGetDisplayQueue(), ^{
            if (isCancelled()) {
                CGColorRelease(backgroundColor);
                return;
            }
            
            UIGraphicsImageRendererFormat *format = [[UIGraphicsImageRendererFormat alloc] init];
            format.scale = scale;
            format.opaque = opaque;
            UIGraphicsImageRenderer *render = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
            UIImage *image = [render imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
                CGContextRef context = rendererContext.CGContext;
                
                if (opaque && context) {
                    CGContextSaveGState(context); {
                        if (!backgroundColor || CGColorGetAlpha(backgroundColor) < 1) {
                            CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
                            CGContextAddRect(context, CGRectMake(0, 0, size.width * scale, size.height * scale));
                            CGContextFillPath(context);
                        }
                        if (backgroundColor) {
                            CGContextSetFillColorWithColor(context, backgroundColor);
                            CGContextAddRect(context, CGRectMake(0, 0, size.width * scale, size.height * scale));
                            CGContextFillPath(context);
                        }
                    } CGContextRestoreGState(context);
                    CGColorRelease(backgroundColor);
                }
                task.display(context, size, isCancelled);
                if (isCancelled()) {
                    UIGraphicsEndImageContext();
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (task.didDisplay) task.didDisplay(self, NO);
                    });
                    return;
                }
            }];
            UIGraphicsEndImageContext();
            if (isCancelled()) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (task.didDisplay) task.didDisplay(self, NO);
                });
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (isCancelled()) {
                    if (task.didDisplay) task.didDisplay(self, NO);
                } else {
                    self.contents = (__bridge id)(image.CGImage);
                    if (task.didDisplay) task.didDisplay(self, YES);
                }
            });
        });
    } else {
        [_sentinel increase];
        if (task.willDisplay) task.willDisplay(self);
        
        UIGraphicsImageRendererFormat *format = [[UIGraphicsImageRendererFormat alloc] init];
        format.scale = self.contentsScale;
        format.opaque = self.opaque;
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:self.bounds format:format];
        
        UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
            CGContextRef context = rendererContext.CGContext;
            if (self.opaque && context) {
                CGSize size = self.bounds.size;
                size.width *= self.contentsScale;
                size.height *= self.contentsScale;
                CGContextSaveGState(context); {
                    if (!self.backgroundColor || CGColorGetAlpha(self.backgroundColor) < 1) {
                        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
                        CGContextAddRect(context, CGRectMake(0, 0, size.width, size.height));
                        CGContextFillPath(context);
                    }
                    if (self.backgroundColor) {
                        CGContextSetFillColorWithColor(context, self.backgroundColor);
                        CGContextAddRect(context, CGRectMake(0, 0, size.width, size.height));
                        CGContextFillPath(context);
                    }
                } CGContextRestoreGState(context);
            }
            task.display(context, self.bounds.size, ^{return NO;});
        }];
        self.contents = (__bridge id)(image.CGImage);
        if (task.didDisplay) task.didDisplay(self, YES);
    }
}

- (void)_cancelAsyncDisplay {
    [_sentinel increase];
}

@end
