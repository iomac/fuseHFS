//
//  NSException+Helpers.h
//  fuseHFS
//
//  Created by Ian Oliver on 2/6/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSException(Int)
+ (NSException*)notImplementedException;
@end

NS_ASSUME_NONNULL_END
