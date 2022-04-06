//
//  FileInspector.h
//  fuseHFS
//
//  Created by Ian Oliver on 3/23/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImageFileType : NSObject

@property (nonatomic, retain) NSString* type;
@property (nonatomic, retain) NSString* subType;

@end

@interface FileInspector : NSObject

+ (ImageFileType*)typeForFilePath:(NSString*)filePath error:(NSError**) error;

@end

NS_ASSUME_NONNULL_END
