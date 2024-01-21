//
//  YYText.h
//  YYText
//
//  Created by Shuai on 2024/1/21.
//

#import <UIKit/UIKit.h>

#if __has_include(<YYText/YYText.h>)
FOUNDATION_EXPORT double YYTextVersionNumber;
FOUNDATION_EXPORT const unsigned char YYTextVersionString[];
#import <YYText/YYLabel.h>
#import <YYText/YYTextView.h>
#import <YYText/YYTextAttribute.h>
#import <YYText/YYTextArchiver.h>
#import <YYText/YYTextParser.h>
#import <YYText/YYTextRunDelegate.h>
#import <YYText/YYTextRubyAnnotation.h>
#import <YYText/YYTextLayout.h>
#import <YYText/YYTextLine.h>
#import <YYText/YYTextInput.h>
#import <YYText/YYTextDebugOption.h>
#import <YYText/YYTextKeyboardManager.h>
#import <YYText/YYTextUtilities.h>
#import <YYText/NSAttributedString+YYText.h>
#import <YYText/NSParagraphStyle+YYText.h>
#import <YYText/UIPasteboard+YYText.h>
#import <YYText/YYTextLazyViewAttachment.h>
#else
#import "YYLabel.h"
#import "YYTextView.h"
#import "YYTextAttribute.h"
#import "YYTextArchiver.h"
#import "YYTextParser.h"
#import "YYTextRunDelegate.h"
#import "YYTextRubyAnnotation.h"
#import "YYTextLayout.h"
#import "YYTextLine.h"
#import "YYTextInput.h"
#import "YYTextDebugOption.h"
#import "YYTextKeyboardManager.h"
#import "YYTextUtilities.h"
#import "NSAttributedString+YYText.h"
#import "NSParagraphStyle+YYText.h"
#import "UIPasteboard+YYText.h"
#import "YYTextLazyViewAttachment.h"
#endif
