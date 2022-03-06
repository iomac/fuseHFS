//
//  AppDelegate.m
//  fuseHFS_agent
//
//  Created by Ian Oliver on 3/1/22.
//

#import "AppDelegate.h"

#import "HFS.h"
#import <macFUSE/macFUSE.h>

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;

@property (nonatomic, retain) GMUserFileSystem* fs;
@property (nonatomic, retain) HFS* hfs;

@end

@implementation AppDelegate

- (BOOL)application:(NSApplication *)sender
           openFile:(NSString *)filename
{
  return [self mountFileAtPath:filename];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)mountFileAtPath:(NSString*)rootPath {
  
  [self registerNotifications];

  NSError* error;
  self.hfs = [HFS mountWithRootPath:rootPath error:&error];

  if (!_hfs) {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
      NSAlert* alert = [[NSAlert alloc] init];
      
      alert.messageText = @"Mount Failed";
      alert.informativeText = [NSString stringWithFormat:@"mountWithRootPath failed with error: %@", error];

      [alert runModal];
      
      [[NSApplication sharedApplication] terminate:nil];
    }];
    
    return NO;
  }

  return [self mountVolume];
}

- (BOOL)mountVolume {
  NSString* mountPath = [NSString stringWithFormat:@"/Volumes/%@", self.hfs.volumeName];

  NSMutableArray* options = [[NSMutableArray alloc] initWithArray:@[
    [NSString stringWithFormat:@"volicon=%@", self.driveIconPath],
    @"native_xattr", // TODO: is this valid or necessary for HFS?
    [NSString stringWithFormat:@"volname=%@", self.hfs.volumeName]
  ]];

  self.fs = [[GMUserFileSystem alloc] initWithDelegate:_hfs isThreadSafe:NO];

  [_fs mountAtPath:mountPath withOptions:options];
  
  return YES;
}

- (NSString*)driveIconPath {
  NSString* iconPath = [[NSBundle mainBundle] pathForResource:@"fuseHFS" ofType:@"icns"];

  NSAssert(iconPath, @"Unable to locate drive icon in bundle");
  
  return iconPath;
}

/*
 * Notifications
 */

- (void)registerNotifications {
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
}

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

@end
