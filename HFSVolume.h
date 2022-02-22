//
//  HFSUtils.h
//  fuseHFS
//
//  Created by Ian Oliver on 2/5/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HFSVolume : NSObject

@property (nonatomic, retain)   NSString*   volumeName;

/* Flush statistics */
@property (nonatomic, retain)   NSDate*     dirtyTimeStamp;
@property (nonatomic, readonly) NSUInteger  writeCountSinceLastFlush;

+ (instancetype _Nullable)mountAtFilePath:(NSString*)filePath error:(NSError**) error;
+ (instancetype _Nullable)formatAndMountAtFilePath:(NSString *)filePath error:(NSError**) error;

- (NSDictionary* _Nullable)attributesOfFileSystemForPath:(NSString*) path error:(NSError**) error;
- (NSDictionary* _Nullable)attributesOfItemAtPath:(NSString *)path userData:(id)userData error:(NSError **)error;

- (BOOL)flush:(NSError **)error;
- (BOOL)unmount:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
