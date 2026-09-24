//
//  YYTextKeyboardManager.m
//  YYText <https://github.com/ibireme/YYText>
//
//  Created by ibireme on 15/6/3.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "YYTextKeyboardManager.h"
#import "YYTextUtilities.h"



@implementation YYTextKeyboardManager {
    NSHashTable *_observers;
    
    CGRect _fromFrame;
    BOOL _fromVisible;
    CGRect _notificationFromFrame;
    CGRect _notificationToFrame;
    NSTimeInterval _notificationDuration;
    UIViewAnimationCurve _notificationCurve;
    BOOL _hasNotification;
}

- (instancetype)init {
    @throw [NSException exceptionWithName:@"YYTextKeyboardManager init error" reason:@"Use 'defaultManager' to get instance." userInfo:nil];
    return [super init];
}

- (instancetype)_init {
    self = [super init];
    _fromFrame = CGRectNull;
    _notificationFromFrame = CGRectNull;
    _notificationToFrame = CGRectNull;
    _observers = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory|NSPointerFunctionsObjectPointerPersonality capacity:0];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_keyboardFrameWillChangeNotification:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (instancetype)defaultManager {
    static YYTextKeyboardManager *mgr = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!YYTextIsAppExtension()) {
            mgr = [[self alloc] _init];
        }
    });
    return mgr;
}

+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self defaultManager];
    });
}

- (void)addObserver:(id<YYTextKeyboardObserver>)observer {
    if (!observer) return;
    [_observers addObject:observer];
}

- (void)removeObserver:(id<YYTextKeyboardObserver>)observer {
    if (!observer) return;
    [_observers removeObject:observer];
}

- (BOOL)isKeyboardVisible {
    for (UIScreen *screen in UIScreen.screens) {
        CGRect rect = CGRectIntersection(screen.bounds, _notificationToFrame);
        if (!CGRectIsNull(rect) && !CGRectIsEmpty(rect)) return YES;
    }
    return NO;
}

- (CGRect)keyboardFrame {
    return _notificationToFrame;
}

- (void)_keyboardFrameWillChangeNotification:(NSNotification *)notif {
    if (![notif.name isEqualToString:UIKeyboardWillChangeFrameNotification]) return;
    NSDictionary *info = notif.userInfo;
    if (!info) return;
    
    NSValue *beforeValue = info[UIKeyboardFrameBeginUserInfoKey];
    NSValue *afterValue = info[UIKeyboardFrameEndUserInfoKey];
    NSNumber *curveNumber = info[UIKeyboardAnimationCurveUserInfoKey];
    NSNumber *durationNumber = info[UIKeyboardAnimationDurationUserInfoKey];
    
    CGRect before = beforeValue.CGRectValue;
    CGRect after = afterValue.CGRectValue;
    UIViewAnimationCurve curve = curveNumber.integerValue;
    NSTimeInterval duration = durationNumber.doubleValue;
    
    // ignore zero end frame
    if (after.size.width <= 0 && after.size.height <= 0) return;
    
    _notificationFromFrame = before;
    _notificationToFrame = after;
    _notificationCurve = curve;
    _notificationDuration = duration;
    _hasNotification = YES;
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_notifyAllObservers) object:nil];
    if (duration == 0) {
        [self performSelector:@selector(_notifyAllObservers) withObject:nil afterDelay:0 inModes:@[NSRunLoopCommonModes]];
    } else {
        [self _notifyAllObservers];
    }
}

- (void)_notifyAllObservers {
    YYTextKeyboardTransition trans = {0};
    
    // from
    if (CGRectIsNull(_fromFrame)) { // first notify
        _fromFrame = _notificationFromFrame;
    }
    trans.fromFrame = _fromFrame;
    trans.fromVisible = _fromVisible;
    
    // to
    if (_hasNotification) {
        trans.toFrame = _notificationToFrame;
        trans.animationDuration = _notificationDuration;
        trans.animationCurve = _notificationCurve;
        trans.animationOption = _notificationCurve << 16;
        
    }
    
    if (trans.toFrame.size.width > 0 && trans.toFrame.size.height > 0) {
        for (UIScreen *screen in UIScreen.screens) {
            CGRect rect = CGRectIntersection(screen.bounds, trans.toFrame);
            if (!CGRectIsNull(rect) && !CGRectIsEmpty(rect)) {
                trans.toVisible = YES;
                break;
            }
        }
    }
    
    if (!CGRectEqualToRect(trans.toFrame, _fromFrame)) {
        for (id<YYTextKeyboardObserver> observer in _observers.copy) {
            if ([observer respondsToSelector:@selector(keyboardChangedWithTransition:)]) {
                [observer keyboardChangedWithTransition:trans];
            }
        }
    }
    
    _hasNotification = NO;
    _fromFrame = trans.toFrame;
    _fromVisible = trans.toVisible;
}

- (CGRect)convertRect:(CGRect)rect toView:(UIView *)view {
    if (CGRectIsNull(rect)) return rect;
    if (CGRectIsInfinite(rect)) return rect;
    if (!view) return rect;
    UIWindow *window = [view isKindOfClass:UIWindow.class] ? (UIWindow *)view : view.window;
    if (!window) return rect;
    rect = [window convertRect:rect fromWindow:nil];
    return view == window ? rect : [view convertRect:rect fromView:window];
}

@end
