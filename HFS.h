//
//  HFS.h
//  fuseHFS
//
//  Created by Ian Oliver on 2/5/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HFS : NSObject

@property (retain) NSString* rootPath;

+ (instancetype)mountWithRootPath:(NSString *)rootPath;

@property (nonatomic, readonly) NSString* volumeName;

- (void)willUnmount;

@end

NS_ASSUME_NONNULL_END
