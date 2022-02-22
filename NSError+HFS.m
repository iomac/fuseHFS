//
//  NSError+HFS.m
//  fuseHFS
//
//  Created by Ian Oliver on 2/21/22.
//

#import "NSError+HFS.h"

NSString* const kHfsErrorDomain = @"HFS_Error";

@implementation NSError (HFS)

+ (NSError*)invalidFormatError {
    return [NSError errorWithDomain:kHfsErrorDomain
                               code:kHfsErrorCodeInvalidFormat
                           userInfo:@{@"message": @"Invalid format for selected device"}];
}

@end
