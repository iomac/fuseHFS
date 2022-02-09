//
//  HFSUtils.m
//  fuseHFS
//
//  Created by Ian Oliver on 2/5/22.
//

#import "HFSVolume.h"
#import <macFUSE/macFUSE.h>
#import "NSException+Helpers.h"
#import "NSError+POSIX.h"
extern "C"
{
    #include "libhfs.h"
}

#define CONVERT_TO_HFS_PATH(__path__) do { __path__ = [__path__ stringByReplacingOccurrencesOfString:@"/" withString:@":"]; } while(0);
#define TO_MACOS_ROMAN_STRING(__str__) [__str__ cStringUsingEncoding:NSMacOSRomanStringEncoding]
#define HFS_ERROR [NSError hfsErrorWithMessage:hfs_error code:errno]

const unsigned short kDataFork = 0x00;
const unsigned short kResourceFork = 0xff;

const NSString* kExtendedAttributeFinderInfo = @"com.apple.FinderInfo";
const NSString* kExtendedAttributeResourceFork = @"com.apple.ResourceFork";

typedef struct {
    union {
        struct {
            FileInfo info;
            ExtendedFileInfo extendedInfo;
        } file;
        struct {
            FolderInfo info;
            ExtendedFolderInfo extendedInfo;
        } folder;
    } u;
} FinderInfo;

@interface HFSFile : NSObject

@property (nonatomic, assign) hfsfile* file;

@end

@implementation HFSFile

+ (instancetype)withPointer:(hfsfile*)file {
    HFSFile* f = [HFSFile new];
    
    f.file = file;
    
    return f;
}

@end

@interface HFSVolume()

@property (nonatomic) hfsvol* hfsVolume;

@end

@implementation HFSVolume

- (instancetype)initWithVolume:(hfsvol*)vol {
    if (self = [super init]) {
        self.hfsVolume = vol;
    }
    
    return self;
}

+ (HFSVolume*)mountAtFilePath:(NSString*)filePath;
{
    // TODO: Handle case where there are multiple partitions
    int partitionNumber = 1;
    hfsvol* volume = hfs_mount(filePath.UTF8String, partitionNumber, HFS_MODE_ANY);
    
    if (volume == NULL) {
        // TODO: Better error handling?
        @throw [NSException exceptionWithName:@"HFS Failure" reason:@"Unable to mount volume" userInfo:nil];
    }
    
    return [[HFSVolume alloc] initWithVolume:volume];
}

- (NSString*)volumeName {
    if (!_volumeName) {
        hfsvolent entry;

        if (hfs_vstat(self.hfsVolume, &entry) == -1) {
            self.volumeName = @"[Unknown]";
        } else {
            self.volumeName = [NSString stringWithCString:entry.name encoding:NSMacOSRomanStringEncoding];
        }
    }
    
    return _volumeName;
}

- (NSDictionary*)attributesOfFileSystemForPath:(NSString*) path error:(NSError**) error
{
    hfsvolent entry;

    if (hfs_vstat(self.hfsVolume, &entry) == -1) {
        *error = [NSError errorWithPOSIXCode:ENOENT];
        return nil;
    }
    
    
    NSMutableDictionary* attributes = [[NSMutableDictionary alloc] initWithDictionary:@{
        NSFileSystemFreeSize: @(entry.freebytes),
        NSFileSystemNodes: @(entry.numfiles),
        NSFileSystemSize: @(entry.totbytes),
    }];
    
    // FUSE Flags
    attributes[kGMUserFileSystemVolumeSupportsExtendedDatesKey] = @NO;
    attributes[kGMUserFileSystemVolumeSupportsCaseSensitiveNamesKey] = @YES;
    attributes[kGMUserFileSystemVolumeMaxFilenameLengthKey] = @(27);
    attributes[kGMUserFileSystemVolumeFileSystemBlockSizeKey] = @(entry.alblocksz);
    
    //NSLog(@"%@", attributes);
    
    return attributes;
}

- (NSDictionary*)attributesOfItemAtPath:(NSString *)path userData:(id)userData error:(NSError **)error
{
    hfsdirent entry;

    if (userData) {
        HFSFile* file = userData;

        if (hfs_fstat(file.file, &entry) == -1) {
            *error = [NSError errorWithPOSIXCode:ENOENT];
            return nil;
        }
    } else {
        CONVERT_TO_HFS_PATH(path);

        if (hfs_stat(self.hfsVolume, TO_MACOS_ROMAN_STRING(path), &entry) == -1) {
            *error = [NSError errorWithPOSIXCode:ENOENT];
            return nil;
        }
    }
    
    NSMutableDictionary* attributes = [[NSMutableDictionary alloc] initWithDictionary:@{
        NSFileReferenceCount: @1,
        NSFileCreationDate: [NSDate dateWithTimeIntervalSince1970:entry.crdate],
        NSFileModificationDate: [NSDate dateWithTimeIntervalSince1970:entry.mddate],
        NSFileSystemFileNumber: @(entry.cnid)
    }];

    // File attributes
    if (entry.flags & HFS_ISDIR) {
        attributes[NSFileType] = NSFileTypeDirectory;
        attributes[NSFileReferenceCount] = @(entry.u.dir.valence);
    } else {
        attributes[NSFileType] = NSFileTypeRegular;
        attributes[NSFileSize] = @(entry.u.file.dsize + entry.u.file.rsize);
        
        attributes[NSFileHFSCreatorCode] = @(*(unsigned int*)entry.u.file.creator);
        attributes[NSFileHFSTypeCode] = @(*(unsigned int*)entry.u.file.type);
    }
    
    // TODO: fix
    if (entry.flags & HFS_ISLOCKED) attributes[NSFilePosixPermissions] = @(777);

    // TODO: verify
    attributes[NSFileImmutable] = (entry.flags & HFS_ISLOCKED) ? @YES : @NO;
    
    // Finder flags
    if (entry.fdflags & HFS_FNDR_ISALIAS) attributes[NSFileTypeSymbolicLink] = @YES;
    
    // FUSE Flags
    attributes[kGMUserFileSystemVolumeSupportsExtendedDatesKey] = @NO;
    attributes[kGMUserFileSystemVolumeSupportsCaseSensitiveNamesKey] = @YES;
    
    return attributes;
}

- (void)dealloc
{
    if (self.hfsVolume) {
        hfs_umount(self.hfsVolume);
        self.hfsVolume = NULL;
    }
}

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path
                                 error:(NSError **)error
{
    path = [path stringByReplacingOccurrencesOfString:@"/" withString:@":"];

    hfsdir * dir = hfs_opendir(self.hfsVolume, [path cStringUsingEncoding:NSMacOSRomanStringEncoding]);
    
    if (!dir) {
        *error = [NSError errorWithPOSIXCode:ENOENT];
        return nil;
    }
    
    hfsdirent ent;
    NSMutableArray* contents = [NSMutableArray new];

    while( hfs_readdir(dir, &ent) != -1) {
        [contents addObject:[NSString stringWithCString:ent.name encoding:NSMacOSRomanStringEncoding]];
    }
    
    hfs_closedir(dir);
    
    NSLog(@"%@", contents);
    
    return contents;
}

- (BOOL)createDirectoryAtPath:(NSString *)path
                   attributes:(NSDictionary *)attributes
                        error:(NSError **)error
{
    path = [path stringByReplacingOccurrencesOfString:@"/" withString:@":"];
    path = [self.volumeName stringByAppendingString:path];
    
    if(hfs_mkdir(self.hfsVolume, [path cStringUsingEncoding:NSMacOSRomanStringEncoding]) == -1) {
        *error = HFS_ERROR;
        return NO;
    }
    
    return YES;
}


- (BOOL)moveItemAtPath:(NSString *)source
                toPath:(NSString *)destination
               options:(GMUserFileSystemMoveOption)options
                 error:(NSError **)error
{
    source = [source stringByReplacingOccurrencesOfString:@"/" withString:@":"];
    destination = [destination stringByReplacingOccurrencesOfString:@"/" withString:@":"];

    if( hfs_rename(self.hfsVolume, [source cStringUsingEncoding:NSMacOSRomanStringEncoding], [destination cStringUsingEncoding:NSMacOSRomanStringEncoding]) != 0 ) {
        *error = HFS_ERROR;
        return NO;
    }
    
    return YES;
}


- (BOOL)createFileAtPath:(NSString *)path
              attributes:(NSDictionary *)attributes
                   flags:(int)flags
                userData:(id *)userData
                   error:(NSError **)error
{
    path = [path stringByReplacingOccurrencesOfString:@"/" withString:@":"];

    int creatorCode = 'APPL';
    int typeCode = 'TEXT';

    hfsfile * file = hfs_create(self.hfsVolume,
                                [path cStringUsingEncoding:NSMacOSRomanStringEncoding],
                                (char*)&typeCode,
                                (char*)&creatorCode);
    
    if( !file )
    {
        *error = [NSError errorWithPOSIXCode:ENOENT];
        return NO;
    }
    
    *userData = [HFSFile withPointer:file];
    
    return YES;
}

/*
 * 'Faking' the prealloc by writing 4 byte '0' at the end of the file
 */
- (BOOL)preallocateFileAtPath:(NSString *)path
                     userData:(id)userData
                      options:(int)options
                       offset:(off_t)offset
                       length:(off_t)length
                        error:(NSError **)error {

    int tmp = 0;
    
    const char * buffer = (const char *)&tmp;
    size_t size = sizeof(tmp);
    offset = offset + length - size;
    
    return [self writeFileAtPath:path
                 userData:userData
                   buffer:buffer
                     size:size
                   offset:offset
                    error:error];
}

- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error
{
    path = [path stringByReplacingOccurrencesOfString:@"/" withString:@":"];
    
    if( hfs_delete(self.hfsVolume, [path cStringUsingEncoding:NSMacOSRomanStringEncoding]) == -1) {
        *error = [NSError errorWithPOSIXCode:ENOENT];
        return NO;
    }

    return YES;
}


- (BOOL)openFileAtPath:(NSString *)path
                  mode:(int)mode
              userData:(id *)userData
                 error:(NSError **)error {
    path = [path stringByReplacingOccurrencesOfString:@"/" withString:@":"];

    hfsfile* file = hfs_open(self.hfsVolume, [path cStringUsingEncoding:NSMacOSRomanStringEncoding]);

    if( !file )
    {
        *error = [NSError errorWithPOSIXCode:ENOENT];
        return NO;
    }
    
    *userData = [HFSFile withPointer:file];
    
    return YES;
}

- (void)releaseFileAtPath:(NSString *)path userData:(id)userData
{
    HFSFile* file = userData;
    
    hfs_close(file.file);
}


- (int)writeFileAtPath:(NSString *)path
              userData:(id)userData
                buffer:(const char *)buffer
                  size:(size_t)size
                offset:(off_t)offset
                 error:(NSError **)error
{
    NSAssert(userData, @"Expected user data");

    HFSFile* file = userData;

    if (hfs_seek(file.file, offset, HFS_SEEK_SET) == -1) {
        *error = [NSError errorWithPOSIXCode:ENOENT];
        return -1;
    }
    
    size_t bytesWritten = hfs_write(file.file, buffer, size);
    
    _writeCountSinceLastFlush++;

    return (int)bytesWritten;
}

- (int)readFileAtPath:(NSString *)path
             userData:(id)userData
               buffer:(char *)buffer
                 size:(size_t)size
               offset:(off_t)offset
                error:(NSError **)error
{
    NSAssert(userData, @"Expected user data");
    
    HFSFile* file = userData;

    if (hfs_seek(file.file, offset, HFS_SEEK_SET) == -1) {
        *error = [NSError errorWithPOSIXCode:ENOENT];
        return -1;
    }
    
    size_t bytesRead = hfs_read(file.file, buffer, size);
    
    return (int)bytesRead;
}

- (BOOL)setAttributes:(NSDictionary *)attributes
         ofItemAtPath:(NSString *)path
             userData:(id)userData
                error:(NSError **)error
{
    NSAssert(userData, @"Expected user data");

    NSLog(@"%@", attributes);

    path = [path stringByReplacingOccurrencesOfString:@"/" withString:@":"];

    NSNumber* offset = attributes[NSFileSize];
    
    if (offset) {
        hfsfile* pFile = hfs_open(self.hfsVolume, [path cStringUsingEncoding:NSMacOSRomanStringEncoding]);
        
        if (!pFile) {
            *error = [NSError errorWithPOSIXCode:ENOENT];
            return NO;
        }
        
        int result = hfs_truncate(pFile, offset.intValue);

        hfs_close(pFile);

        if ( result == -1) {
            *error = [NSError errorWithPOSIXCode:ENOENT];
            return NO;
        }
    }
    
    NSNumber* flags = [attributes objectForKey:kGMUserFileSystemFileFlagsKey];
    if (flags != nil) {
        @throw [NSException notImplementedException];
    }
    
    // TODO: other flags?
    
    _writeCountSinceLastFlush++;

    return YES;
}

- (BOOL)removeDirectoryAtPath:(NSString *)path error:(NSError **)error
{
    path = [path stringByReplacingOccurrencesOfString:@"/" withString:@":"];

    int result = hfs_rmdir(self.hfsVolume, [path cStringUsingEncoding:NSMacOSRomanStringEncoding]);
    
    if (result == -1) {
        *error = [NSError errorWithPOSIXCode:ENOENT];
        return NO;
    }
    
    _writeCountSinceLastFlush++;

    return YES;
}

- (void)flush
{
    hfs_flush(self.hfsVolume);
    
    _writeCountSinceLastFlush = 0;
}

- (void)unmount
{
    NSLog(@"HFSUtils unmount");
    
    if (self.hfsVolume) {
        hfs_umount(self.hfsVolume);
        
        self.hfsVolume = NULL;
    }
}

#pragma mark Extended Attributes

- (NSArray *)extendedAttributesOfItemAtPath:(NSString *)path error:(NSError **)error {
    CONVERT_TO_HFS_PATH(path);

    hfsdirent ent;

    if (hfs_stat(self.hfsVolume, TO_MACOS_ROMAN_STRING(path), &ent) == -1) {
        *error = HFS_ERROR;
        return nil;
    }

    NSArray* attributes = @[kExtendedAttributeFinderInfo];
    
    if (!(ent.flags & HFS_ISDIR)) {
        if (ent.u.file.rsize > 0) {
            attributes = @[kExtendedAttributeFinderInfo, kExtendedAttributeResourceFork];
        }
    }
    return attributes;
}

- (NSData *)valueOfExtendedAttribute:(NSString *)name
                        ofItemAtPath:(NSString *)path
                            position:(off_t)position
                               error:(NSError **)error {
    CONVERT_TO_HFS_PATH(path);
    
    if ([kExtendedAttributeFinderInfo isEqualToString:name]) {
        // Need to populate the classic finder info data set
        hfsdirent ent;

        if (hfs_stat(self.hfsVolume, TO_MACOS_ROMAN_STRING(path), &ent) == -1) {
            *error = HFS_ERROR;
            return nil;
        }

        FinderInfo finderInfo = {0};

        if (ent.flags & HFS_ISDIR) {
            finderInfo.u.folder.info.windowBounds.left = ent.u.dir.rect.left;
            finderInfo.u.folder.info.windowBounds.right = ent.u.dir.rect.right;
            finderInfo.u.folder.info.windowBounds.top = ent.u.dir.rect.top;
            finderInfo.u.folder.info.windowBounds.bottom = ent.u.dir.rect.bottom;
            finderInfo.u.folder.info.finderFlags = ent.fdflags;
            finderInfo.u.folder.info.location.h = ent.fdlocation.h;
            finderInfo.u.folder.info.location.v = ent.fdlocation.v;
//            finderInfo.u.folder.extendedInfo.scrollPosition;
//            finderInfo.u.folder.extendedInfo.extendedFinderFlags;
//            finderInfo.u.folder.extendedInfo.putAwayFolderID;
        } else {
            finderInfo.u.file.info.fileType = *((OSType*)&ent.u.file.type);
            finderInfo.u.file.info.fileCreator = *((OSType*)&ent.u.file.creator);
            finderInfo.u.file.info.finderFlags = ent.fdflags;
            finderInfo.u.file.info.location.h = ent.fdlocation.h;
            finderInfo.u.file.info.location.v = ent.fdlocation.v;
//            finderInfo.u.file.extendedInfo.extendedFinderFlags;
//            finderInfo.u.file.extendedInfo.putAwayFolderID;
        }
        
        _writeCountSinceLastFlush++;

        return [NSData dataWithBytes:&finderInfo length:32];
    } else if ([kExtendedAttributeResourceFork isEqualToString:name]) {
        hfsdirent ent;

        if (hfs_stat(self.hfsVolume, TO_MACOS_ROMAN_STRING(path), &ent) == -1) {
            *error = HFS_ERROR;
            return nil;
        }
        
        if (ent.flags & HFS_ISDIR) {
            *error = [NSError errorWithPOSIXCode:EPERM];
            return nil;
        }
        
        size_t byteCount = ent.u.file.rsize;
        hfsfile* file = hfs_open(self.hfsVolume, TO_MACOS_ROMAN_STRING(path));
        
        if (hfs_setfork(file, kResourceFork) == -1) {
            hfs_close(file);
            
            *error = HFS_ERROR;
            return nil;
        }
        
        NSMutableData* data = [NSMutableData data];
        
        size_t bytesRead = 0;
        const int kBufferSize = 512;
        byte buffer[kBufferSize];

        while( (bytesRead = hfs_read(file, buffer, kBufferSize)) > 0 ) {
            [data appendBytes:buffer length:bytesRead];
        }
        
        if (bytesRead == -1) {
            *error = HFS_ERROR;
            data = nil;
        }

        hfs_close(file);

        _writeCountSinceLastFlush++;

        return data;
    }
    
    return nil;
}

- (BOOL)setExtendedAttribute:(NSString *)name
                ofItemAtPath:(NSString *)path
                       value:(NSData *)value
                    position:(off_t)position
                       options:(int)options
                       error:(NSError **)error {
    CONVERT_TO_HFS_PATH(path);

    if ([kExtendedAttributeFinderInfo isEqualToString:name]) {
        hfsdirent ent;

        if (hfs_stat(self.hfsVolume, TO_MACOS_ROMAN_STRING(path), &ent) == -1) {
            *error = HFS_ERROR;
            return nil;
        }
        
        FinderInfo finderInfo = {0};
        
        memcpy(&finderInfo, [value bytes], sizeof(finderInfo));
        
        if (ent.flags & HFS_ISDIR) {
            ent.u.dir.rect.left = finderInfo.u.folder.info.windowBounds.left;
            ent.u.dir.rect.right = finderInfo.u.folder.info.windowBounds.right;
            ent.u.dir.rect.top = finderInfo.u.folder.info.windowBounds.top;
            ent.u.dir.rect.bottom = finderInfo.u.folder.info.windowBounds.bottom;
            ent.fdflags = finderInfo.u.folder.info.finderFlags;
            ent.fdlocation.h = finderInfo.u.folder.info.location.h;
            ent.fdlocation.v = finderInfo.u.folder.info.location.v;
//            finderInfo.u.folder.extendedInfo.scrollPosition;
//            finderInfo.u.folder.extendedInfo.extendedFinderFlags;
//            finderInfo.u.folder.extendedInfo.putAwayFolderID;
        } else {
            memcpy(&ent.u.file.type, &finderInfo.u.file.info.fileType, 4);
            memcpy(&ent.u.file.creator, &finderInfo.u.file.info.fileCreator, 4);
            ent.fdflags = finderInfo.u.file.info.finderFlags;
            ent.fdlocation.h = finderInfo.u.file.info.location.h;
            ent.fdlocation.v = finderInfo.u.file.info.location.v;
//            finderInfo.u.file.extendedInfo.extendedFinderFlags;
//            finderInfo.u.file.extendedInfo.putAwayFolderID;
        }

        if (hfs_setattr(self.hfsVolume, TO_MACOS_ROMAN_STRING(path), &ent) == -1) {
            *error = HFS_ERROR;
            return nil;
        }
        
        _writeCountSinceLastFlush++;
        
        return YES;
    } else if ([kExtendedAttributeResourceFork isEqualToString:name]) {
        hfsfile* file = hfs_open(self.hfsVolume, TO_MACOS_ROMAN_STRING(path));

        if (hfs_setfork(file, kResourceFork) == -1) {
            hfs_close(file);
            
            *error = HFS_ERROR;
            return NO;
        }
        
        if (hfs_seek(file, 0, HFS_SEEK_SET) == -1) {
            hfs_close(file);

            *error = HFS_ERROR;
            return NO;
        }
        
        if( hfs_write(file, [value bytes], value.length) == -1 ) {
            hfs_close(file);

            *error = HFS_ERROR;
            return NO;
        }

        hfs_close(file);

        _writeCountSinceLastFlush++;

        hfsdirent ent;

        if (hfs_stat(self.hfsVolume, TO_MACOS_ROMAN_STRING(path), &ent) == -1) {
            *error = HFS_ERROR;
            return nil;
        }

        return YES;
    }
    
    return NO;
}

- (BOOL)removeExtendedAttribute:(NSString *)name
                   ofItemAtPath:(NSString *)path
                          error:(NSError **)error {
    @throw [NSException notImplementedException];
}


@end
