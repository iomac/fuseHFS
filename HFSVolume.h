//
//  HFSUtils.h
//  fuseHFS
//
//  Created by Ian Oliver on 2/5/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HFSVolume : NSObject

@property (nonatomic, retain) NSString* volumeName;
@property (nonatomic, readonly) NSUInteger writeCountSinceLastFlush;

+ (HFSVolume*)mountAtFilePath:(NSString*)filePath;

- (NSDictionary*)attributesOfFileSystemForPath:(NSString*) path error:(NSError**) error;
- (NSDictionary*)attributesOfItemAtPath:(NSString *)path userData:(id)userData error:(NSError **)error;

- (void)flush;
- (void)unmount;

@end

NS_ASSUME_NONNULL_END
