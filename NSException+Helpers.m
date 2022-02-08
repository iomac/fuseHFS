//
//  NSException+Helpers.m
//  fuseHFS
//
//  Created by Ian Oliver on 2/6/22.
//

#import "NSException+Helpers.h"

@implementation NSException(Int)
+ (NSException*)notImplementedException {
    return [NSException exceptionWithName:@"NotImplemented" reason:@"Lazy developer" userInfo:nil];
}
@end
