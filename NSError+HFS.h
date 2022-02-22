//
//  NSError+HFS.h
//  fuseHFS
//
//  Created by Ian Oliver on 2/21/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kHfsErrorDomain;

const NSInteger kHfsErrorCodeInvalidFormat = 100;

@interface NSError (HFS)

+ (NSError*)invalidFormatError;

@end

NS_ASSUME_NONNULL_END
