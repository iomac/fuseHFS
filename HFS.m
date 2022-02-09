//
//  HFS.m
//  fuseHFS
//
//  Created by Ian Oliver on 2/5/22.
//

#import "HFS.h"
#import "HFSVolume.h"
#import <macFUSE/macFUSE.h>
#import "NSException+Helpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface HFS()

@property (retain) HFSVolume* volume;

@end

@implementation HFS

+ (instancetype)mountWithRootPath:(NSString *)rootPath
{
    HFSVolume* volume = [HFSVolume mountAtFilePath: rootPath];
    
    if (volume) {
        return [[HFS alloc] initWithVolume:volume rootPath:rootPath];
    }
    
    return nil;
}

- (id)initWithVolume:(HFSVolume*)volume rootPath:(NSString *)rootPath
{
    if (self = [super init]) {
        self.rootPath = rootPath;
        self.volume = volume;
    }
    
    return self;
}

- (NSString*)volumeName {
    return self.volume.volumeName;
}

#pragma mark Moving an Item

- (BOOL)moveItemAtPath:(NSString *)source
                toPath:(NSString *)destination
               options:(GMUserFileSystemMoveOption)options
                 error:(NSError **)error {
    NSLog(@"moveItemAtPath: %@", source);
    return [self.volume moveItemAtPath:source toPath:destination options:options error:error];
}

#pragma mark Removing an Item

- (BOOL)removeDirectoryAtPath:(NSString *)path error:(NSError **)error {
    NSLog(@"removeDirectoryAtPath: %@", path);
    return [self.volume removeDirectoryAtPath:path error:error];
}

- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error {
    NSLog(@"removeItemAtPath: %@", path);
    return [self.volume removeItemAtPath:path error:error];
}

#pragma mark Creating an Item

- (BOOL)createDirectoryAtPath:(NSString *)path
                   attributes:(NSDictionary *)attributes
                        error:(NSError **)error {
    NSLog(@"createDirectoryAtPath: %@", path);
    return [self.volume createDirectoryAtPath:path attributes:attributes error:error];
}

- (BOOL)createFileAtPath:(NSString *)path
              attributes:(NSDictionary *)attributes
                   flags:(int)flags
                userData:(id *)userData
                   error:(NSError **)error
{
    NSLog(@"createFileAtPath: %@", path);
    return [self.volume createFileAtPath:path
                              attributes:attributes
                                   flags:flags
                                userData:userData
                                   error:error];
}


- (BOOL)createFileAtPath:(NSString *)path
              attributes:(NSDictionary *)attributes
                userData:(id *)userData
                   error:(NSError **)error {
    return [self createFileAtPath:path
                       attributes:attributes
                            flags:(O_RDWR | O_CREAT | O_EXCL)
                         userData:userData
                            error:error];
}

#pragma mark Linking an Item

- (BOOL)linkItemAtPath:(NSString *)path
                toPath:(NSString *)otherPath
                 error:(NSError **)error {

    NSLog(@"linkItemAtPath: %@", path);
    @throw [NSException exceptionWithName:@"NotImplemented" reason:@"Lazy developer" userInfo:nil];
}

#pragma mark Symbolic Links

- (BOOL)createSymbolicLinkAtPath:(NSString *)path
             withDestinationPath:(NSString *)otherPath
                           error:(NSError **)error {
    NSLog(@"createSymbolicLinkAtPath: %@", path);
    @throw [NSException exceptionWithName:@"NotImplemented" reason:@"Lazy developer" userInfo:nil];
}

- (NSString *)destinationOfSymbolicLinkAtPath:(NSString *)path
                                        error:(NSError **)error {
    NSLog(@"destinationOfSymbolicLinkAtPath: %@", path);
    @throw [NSException exceptionWithName:@"NotImplemented" reason:@"Lazy developer" userInfo:nil];
}

#pragma mark File Contents

- (BOOL)openFileAtPath:(NSString *)path
                  mode:(int)mode
              userData:(id *)userData
                 error:(NSError **)error {
    NSLog(@"openFileAtPath: %@", path);
    return [self.volume openFileAtPath:path mode:mode userData:userData error:error];
}

- (void)releaseFileAtPath:(NSString *)path userData:(id)userData {
    NSLog(@"releaseFileAtPath: %@", path);
    [self.volume releaseFileAtPath:path userData:userData];
}

- (int)readFileAtPath:(NSString *)path
             userData:(id)userData
               buffer:(char *)buffer
                 size:(size_t)size
               offset:(off_t)offset
                error:(NSError **)error {
    NSLog(@"readFileAtPath: %@", path);
    return [self.volume readFileAtPath:path userData:userData buffer:buffer size:size offset:offset error:error];
}

- (int)writeFileAtPath:(NSString *)path
              userData:(id)userData
                buffer:(const char *)buffer
                  size:(size_t)size
                offset:(off_t)offset
                 error:(NSError **)error {
    NSLog(@"writeFileAtPath: %@", path);
    return [self.volume writeFileAtPath:path userData:userData buffer:buffer size:size offset:offset error:error];
}

- (BOOL)preallocateFileAtPath:(NSString *)path
                     userData:(id)userData
                      options:(int)options
                       offset:(off_t)offset
                       length:(off_t)length
                        error:(NSError **)error {
    NSLog(@"preallocateFileAtPath: %@", path);
    return [self.volume preallocateFileAtPath:path userData:userData options:options offset:offset length:length error:error];
}

- (BOOL)exchangeDataOfItemAtPath:(NSString *)path1
                  withItemAtPath:(NSString *)path2
                           error:(NSError **)error {
    NSLog(@"exchangeDataOfItemAtPath");
    @throw [NSException exceptionWithName:@"NotImplemented" reason:@"Lazy developer" userInfo:nil];
}

#pragma mark Directory Contents

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    NSLog(@"contentsOfDirectoryAtPath:%@", path);
    
    return [self.volume contentsOfDirectoryAtPath:path error:error];
}

#pragma mark Getting and Setting Attributes

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path
                                userData:(id)userData
                                   error:(NSError **)error {
    NSLog(@"attributesOfItemAtPath: %@", path);
    return [self.volume attributesOfItemAtPath:path userData:userData error:error];
}

- (NSDictionary *)attributesOfFileSystemForPath:(NSString *)path
                                          error:(NSError **)error {
    NSLog(@"attributesOfFileSystemForPath: %@", path);
    return [self.volume attributesOfFileSystemForPath: path error:error];
}

- (BOOL)setAttributes:(NSDictionary *)attributes
         ofItemAtPath:(NSString *)path
             userData:(id)userData
                error:(NSError **)error
{
    NSLog(@"setAttributes: %@", path);
    return [self.volume setAttributes:attributes
                         ofItemAtPath:path
                             userData:userData
                                error:error];
}

- (void)willUnmount
{
    NSLog(@"willUnmount");
    [self.volume unmount];
}

#pragma mark Extended Attributes

- (NSArray *)extendedAttributesOfItemAtPath:(NSString *)path error:(NSError **)error
{
    NSLog(@"extendedAttributesOfItemAtPath: %@", path);

    return [self.volume extendedAttributesOfItemAtPath:path error:error];
}

- (NSData *)valueOfExtendedAttribute:(NSString *)name
                        ofItemAtPath:(NSString *)path
                            position:(off_t)position
                               error:(NSError **)error
{
    NSLog(@"valueOfExtendedAttribute: %@ ofItemAtPath: %@", name, path);
    return [self.volume valueOfExtendedAttribute:name ofItemAtPath:path position:position error:error];
}

- (BOOL)setExtendedAttribute:(NSString *)name
                ofItemAtPath:(NSString *)path
                       value:(NSData *)value
                    position:(off_t)position
                     options:(int)options
                       error:(NSError **)error
{
    NSLog(@"setExtendedAttribute: %@ ofItemAtPath: %@", name, path);
    
    return [self.volume setExtendedAttribute:name ofItemAtPath:path value:value position:position options:options error:error];
}

- (BOOL)removeExtendedAttribute:(NSString *)name
                   ofItemAtPath:(NSString *)path
                          error:(NSError **)error
{
    NSLog(@"removeExtendedAttribute: %@", path);
    return [self.volume removeExtendedAttribute:name ofItemAtPath:path error:error];
}

@end

NS_ASSUME_NONNULL_END
