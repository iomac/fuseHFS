//
//  FileInspector.m
//  fuseHFS
//
//  Created by Ian Oliver on 3/23/22.
//

#import "FileInspector.h"
#import "NSException+Helpers.h"

@implementation ImageFileType

+ (instancetype)withType:(NSString*)type subType:(NSString*)subType {
    return [[ImageFileType alloc] initWithType:type subType:subType];
}

- (instancetype)initWithType:(NSString*)type subType:(NSString*)subType {
    if (self = [super init]) {
        self.type = type;
        self.subType = subType;
    }
    
    return self;
}

@end

@implementation FileInspector

+ (ImageFileType*)typeForFilePath:(NSString*)filePath error:(NSError**) error {
    ImageFileType* fileType = nil;
    
    NSFileHandle* fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    
    [fileHandle seekToFileOffset:0];
    
    NSData* data = [fileHandle readDataOfLength:16 * 512];
    
    const char * buffer = data.bytes;

    if (buffer[0x0] == 'L' && buffer[0x1] == 'K') {
        fileType = [ImageFileType withType:@"image" subType:@"bootable"];
    }
    else if (buffer[0x400] == 'B' && buffer[0x401] == 'D') {
        
    }
    else if (buffer[0x0] == 'E' && buffer[0x1] == 'R') {
        
    }
    else {
        @throw [NSException notImplementedException];
    }
    
    return fileType;
}

@end
