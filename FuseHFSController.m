//
//  FuseHFSController.m
//  fuseHFS
//
//  Created by Ian Oliver on 2/5/22.
//
#import "FuseHFSController.h"
#import "HFS.h"
#import <macFUSE/macFUSE.h>

#import <AvailabilityMacros.h>

@interface FuseHFSController () <NSOpenSavePanelDelegate>

@property (nonatomic, retain) GMUserFileSystem* fs;
@property (nonatomic, retain) HFS* hfs;

@end

@implementation FuseHFSController

- (void)mountFailed:(NSNotification *)notification {
  NSLog(@"Got mountFailed notification.");
  
  NSDictionary* userInfo = [notification userInfo];
  NSError* error = [userInfo objectForKey:kGMUserFileSystemErrorKey];
  NSLog(@"kGMUserFileSystem Error: %@, userInfo=%@", error, [error userInfo]);
  
  if (self.hfs) {
    [self.hfs willUnmount];
  }
  
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Mount Failed"];
    [alert setInformativeText:[error localizedDescription] ?: @"Unknown error"];
    [alert runModal];
    
    [[NSApplication sharedApplication] terminate:nil];
  }];
}

- (void)didMount:(NSNotification *)notification {
  NSLog(@"Got didMount notification.");
  
  NSDictionary* userInfo = [notification userInfo];
  NSString* mountPath = [userInfo objectForKey:@"mountPath"];
  NSString* parentPath = [mountPath stringByDeletingLastPathComponent];
  
  [[NSWorkspace sharedWorkspace] selectFile:mountPath
                   inFileViewerRootedAtPath:parentPath];
}

- (void)didUnmount:(NSNotification*)notification {
  NSLog(@"Got didUnmount notification.");
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSApplication sharedApplication] terminate:nil];
  });
}

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url {
  NSString* ext = [url pathExtension];
  
  if ([@"" isEqualToString:ext]) {
    return YES;
  }
  
  if ([@"hda" isEqualToString:ext]) {
    return YES;
  }

  if ([@"dsk" isEqualToString:ext]) {
    return YES;
  }

  return NO;
}

- (NSString*)lastDriveFile {
  return [[NSUserDefaults standardUserDefaults] valueForKey:@"LastDriveFile"];
}

- (void)setLastDriveFile: (NSString*) value {
  [[NSUserDefaults standardUserDefaults] setValue:value forKey:@"LastDriveFile"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  
  panel.delegate = self;
  panel.canChooseFiles = YES;
  panel.canChooseDirectories = NO;
  panel.allowsMultipleSelection = NO;

  if (self.lastDriveFile) {
    panel.directoryURL = [NSURL URLWithString:self.lastDriveFile];
  } else {
    panel.directoryURL = [NSURL fileURLWithPath:[@"~" stringByExpandingTildeInPath]];
  }
  
  NSInteger ret = [panel runModal];
  
  if ( ret == NSModalResponseCancel )
  {
    exit(0);
  }
  
  NSArray* paths = [panel URLs];

  if ( [paths count] != 1 ) {
    exit(0);
  }
  
  NSString* rootPath = [[paths objectAtIndex:0] path];
  
  NSNotificationCenter* center = [NSNotificationCenter defaultCenter];

  [center addObserver:self
             selector:@selector(mountFailed:)
                 name:kGMUserFileSystemMountFailed object:nil];
  [center addObserver:self
             selector:@selector(didMount:)
                 name:kGMUserFileSystemDidMount object:nil];
  [center addObserver:self
             selector:@selector(didUnmount:)
                 name:kGMUserFileSystemDidUnmount object:nil];
  
  
  NSString* iconPath = [[NSBundle mainBundle] pathForResource:@"fuseHFS" ofType:@"icns"];
  
  if (!iconPath) {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
      NSAlert* alert = [[NSAlert alloc] init];
      
      alert.messageText = @"Mount Failed";
      alert.informativeText = @"Unable to locate drive icon in bundle";

      [alert runModal];
      
      [[NSApplication sharedApplication] terminate:nil];
    }];
    
    return;
  }
  
  self.hfs = [HFS mountWithRootPath:rootPath];

  if (!_hfs) {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
      NSAlert* alert = [[NSAlert alloc] init];
      
      alert.messageText = @"Mount Failed";
      alert.informativeText = @"mountWithRootPath failed";

      [alert runModal];
      
      [[NSApplication sharedApplication] terminate:nil];
    }];
    
    return;
  }

  NSString* mountPath = [NSString stringWithFormat:@"/Volumes/%@", self.hfs.volumeName];

  NSMutableArray* options = [[NSMutableArray alloc] initWithArray:@[
    [NSString stringWithFormat:@"volicon=%@", iconPath],
    @"native_xattr", // TODO: is this valid or necessary for HFS?
    [NSString stringWithFormat:@"volname=%@", self.hfs.volumeName]
  ]];

  self.lastDriveFile = rootPath;
  self.fs = [[GMUserFileSystem alloc] initWithDelegate:_hfs isThreadSafe:NO];

  [_fs mountAtPath:mountPath withOptions:options];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [_hfs willUnmount];
  [_fs unmount];
  
  return NSTerminateNow;
}

@end
