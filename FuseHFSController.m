//
//  FuseHFSController.m
//  fuseHFS
//
//  Created by Ian Oliver on 2/5/22.
//
#import "FuseHFSController.h"
#import "HFS.h"
#import <macFUSE/macFUSE.h>
#import "FileInspector.h"

#import <AvailabilityMacros.h>

@interface FuseHFSController () <NSOpenSavePanelDelegate>

@property (strong) IBOutlet NSWindow *window;

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

  for (NSString* e in  @[@"",@"hda",@"dsk",@"iso",@"image",@"toast",@"img",@"dmg"]) {
    if ([e isEqualToString:ext]) {
      return YES;
    }
  }
  
  return NO;
}

- (NSString*)lastDriveFile {
  return [[NSUserDefaults standardUserDefaults] valueForKey:@"LastDriveFile"];
}

- (void)setLastDriveFile: (NSString*) value {
  [[NSUserDefaults standardUserDefaults] setValue:value forKey:@"LastDriveFile"];
}

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

- (NSString*)driveIconPath {
  NSString* iconPath = [[NSBundle mainBundle] pathForResource:@"fuseHFS" ofType:@"icns"];

  NSAssert(iconPath, @"Unable to locate drive icon in bundle");
  
  return iconPath;
}

- (BOOL)mountVolume {
  NSString* mountPath = [NSString stringWithFormat:@"/Volumes/%@", self.hfs.volumeName];

  NSMutableArray* options = [[NSMutableArray alloc] initWithArray:@[
    [NSString stringWithFormat:@"volicon=%@", self.driveIconPath],
    @"native_xattr", // TODO: is this valid or necessary for HFS?
    [NSString stringWithFormat:@"volname=%@", self.hfs.volumeName],
    [NSString stringWithFormat:@"fstypename=HFS"],
    [NSString stringWithFormat:@"fsname=fuseHFS"],
    
  ]];

  self.fs = [[GMUserFileSystem alloc] initWithDelegate:_hfs isThreadSafe:NO];

  [_fs mountAtPath:mountPath withOptions:options];
  
  return YES;
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

- (BOOL)formatAndMountFileAtPath:(NSString*)rootPath {
  [self registerNotifications];

  NSError* error;
  self.hfs = [HFS formatAndMountWithRootPath:rootPath error:&error];

  if (!_hfs) {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
      NSAlert* alert = [[NSAlert alloc] init];
      
      alert.messageText = @"Format & Mount Failed";
      alert.informativeText = [NSString stringWithFormat:@"formatAndMountWithRootPath failed with error: %@", error];

      [alert runModal];
      
      [[NSApplication sharedApplication] terminate:nil];
    }];
    
    return NO;
  }

  return [self mountVolume];
}

- (BOOL)application:(NSApplication *)sender
           openFile:(NSString *)filename
{
  return [self mountFileAtPath:filename];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  if (self.hfs) {
    [[NSRunningApplication currentApplication] hide];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
  }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [_hfs willUnmount];
  [_fs unmount];
  
  return NSTerminateNow;
}

- (void)selectImageFile:(void (^)(NSString* path, ImageFileType* fileType))callback {
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
    callback(nil, nil);
    return;
  }
  
  NSArray* paths = [panel URLs];

  if ( [paths count] != 1 ) {
    callback(nil, nil);
    return;
  }

  NSString* path = [[paths objectAtIndex:0] path];
  self.lastDriveFile = path;
  
  callback(path, [FileInspector typeForFilePath:path error:nil]);
}

- (IBAction)openImage:(id)sender {
  
  [self selectImageFile:^(NSString *path, ImageFileType* fileType) {
    [self mountFileAtPath:path];
    
    [self.window close];
  }];
}

- (IBAction)createImage:(id)sender {
  
}

- (IBAction)formatImage:(id)sender {
  [self selectImageFile:^(NSString *path, ImageFileType* fileType) {
    if (path) {
      [self formatAndMountFileAtPath:path];
    }
  }];
}

@end
