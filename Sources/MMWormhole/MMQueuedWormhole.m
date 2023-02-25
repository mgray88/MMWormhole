//
//  MMQueuedWormhole.m
//  MMWormhole
//
//  Created by Pierre Houston on 2015-03-11.
//  Copyright (c) 2015 Conrad Stoll. All rights reserved.
//

#import "MMQueuedWormhole.h"
#import "MMWormhole-Private.h"

#if !__has_feature(objc_arc)
#error This class requires automatic reference counting
#endif


@implementation MMQueuedWormholeFileTransiting
#pragma mark - Private File Operation Methods

- (NSInteger)smallestFileNumberForIdentifier:(NSString *)identifier
{
    NSString *directoryPath = [self messagePassingDirectoryPath];
    NSString *subDirectoryPath = [directoryPath stringByAppendingPathComponent:identifier];
    
    NSInteger smallest = -1;
    NSError *error;
    NSArray *files = [self.fileManager contentsOfDirectoryAtPath:subDirectoryPath error:&error];
    
    for (NSString *filePath in files) {
        NSString *fileName = [filePath lastPathComponent];
        NSString *fileNumberString = [fileName stringByDeletingPathExtension];
        NSInteger fileNumber = fileNumberString.integerValue;
        if (fileNumber >= 0 && (smallest < 0 || fileNumber < smallest)) {
            smallest = fileNumber;
        }
    }
    
    return smallest;
}

- (NSInteger)largestFileNumberForIdentifier:(NSString *)identifier
{
    NSString *directoryPath = [self messagePassingDirectoryPath];
    NSString *subDirectoryPath = [directoryPath stringByAppendingPathComponent:identifier];
    
    NSInteger largest = 0;
    NSError *error;
    NSArray *files = [self.fileManager contentsOfDirectoryAtPath:subDirectoryPath error:&error];
    
    for (NSString *filePath in files) {
        NSString *fileName = [filePath lastPathComponent];
        NSString *fileNumberString = [fileName stringByDeletingPathExtension];
        NSInteger fileNumber = fileNumberString.integerValue;
        if (fileNumber > largest) {
            largest = fileNumber;
        }
    }
    
    return largest;
}

- (NSInteger)oneGreaterThanLargestFileNumberForIdentifier:(NSString *)identifier
{
    NSString *directoryPath = [self messagePassingDirectoryPath];
    NSString *subDirectoryPath = [directoryPath stringByAppendingPathComponent:identifier];
    
    NSInteger oneGreater = 0;
    NSError *error;
    NSArray *files = [self.fileManager contentsOfDirectoryAtPath:subDirectoryPath error:&error];
    
    for (NSString *filePath in files) {
        NSString *fileName = [filePath lastPathComponent];
        NSString *fileNumberString = [fileName stringByDeletingPathExtension];
        NSInteger fileNumber = fileNumberString.integerValue;
        if (fileNumber >= oneGreater) {
            oneGreater = fileNumber + 1;
        }
    }
    
    return oneGreater;
}


- (NSString *)filePathForIdentifier:(NSString *)identifier withFileNumber:(NSInteger)fileNumber
{
    if (identifier == nil || identifier.length == 0 || fileNumber < 0) {
        return nil;
    }
    
    NSString *directoryPath = [self messagePassingDirectoryPath];
    NSString *subDirectoryPath = [directoryPath stringByAppendingPathComponent:identifier];
    
    BOOL isDir;
    if ([self.fileManager fileExistsAtPath:subDirectoryPath isDirectory:&isDir] && !isDir) {
        if (![self.fileManager removeItemAtPath:subDirectoryPath error:nil]) {
            return nil;
        }
    }
    
    NSString *fileName = [NSString stringWithFormat:@"%d.archive", (int)fileNumber];
    NSString *filePath = [subDirectoryPath stringByAppendingPathComponent:fileName];
    
    return filePath;
}

- (NSString *)uniqueFilePathWithinParent:(NSString *)parentPath
{
    return [parentPath stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
}

- (NSData *)atomicallyReadAndDeleteFile:(NSString *)filePath error:(NSError **)errorPtr
{
    // make this atomic by first moving the file to a unique path, then only if that succeeds then read & delete it
    // if 2 processes both enter this method for the same path, one move will win and the other will fail
    if (!filePath) {
        if (errorPtr) {
            errorPtr = nil; // return error = nil for now, don't know what error to use anyway
        }
        return nil;
    }
    
    NSString *uniquePath = [self uniqueFilePathWithinParent:[filePath stringByDeletingLastPathComponent]];
    if (![[NSFileManager defaultManager] moveItemAtPath:filePath toPath:uniquePath error:errorPtr]) {
        return nil;
    }
    
    NSData *data = [NSData dataWithContentsOfFile:uniquePath options:NSDataReadingUncached error:errorPtr];
    [[NSFileManager defaultManager] removeItemAtPath:uniquePath error:NULL];
    return data;
}

- (BOOL)atomicallyWriteData:(NSData *)data toFile:(NSString *)filePath error:(NSError **)errorPtr
{
    // write atomically by writing the file at a unique path then attempt to move to given location, failing if the move fails
    // if 2 processes both enter this method for the same path, one move will win and the other will fail
    if (!filePath) {
        if (errorPtr) {
            errorPtr = nil; // return error = nil for now, don't know what error to use anyway
        }
        return NO;
    }
    
    NSString *uniquePath = [self uniqueFilePathWithinParent:[filePath stringByDeletingLastPathComponent]];
    if (![data writeToFile:uniquePath options:NSDataWritingAtomic error:errorPtr]) {
        return NO;
    }
    
    if (![[NSFileManager defaultManager] moveItemAtPath:uniquePath toPath:filePath error:errorPtr]) {
        [[NSFileManager defaultManager] removeItemAtPath:uniquePath error:NULL]; // back out by deleting temporary file
        return NO;
    }
    return YES;
}

#pragma mark - Overridden Private File Operation Methods
- (BOOL)writeMessageObject:(id<NSCoding>)messageObject forIdentifier:(NSString *)identifier
{
    return [self writeMessageObject:messageObject forIdentifier:identifier usedFileNumber:NULL];
}

- (BOOL)writeMessageObject:(id)messageObject forIdentifier:(NSString *)identifier usedFileNumber:(NSInteger *)fileNumberPtr
{
    if (identifier == nil) {
        return NO;
    }
    
    NSData *data = messageObject ? [NSKeyedArchiver archivedDataWithRootObject:messageObject] : [NSData data];
    NSInteger fileNumber = [self oneGreaterThanLargestFileNumberForIdentifier:identifier];
    NSString *filePath = [self filePathForIdentifier:identifier withFileNumber:fileNumber];
    
    if (data == nil || filePath == nil) {
        return NO;
    }
    
    NSString *parentPath = [filePath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:parentPath withIntermediateDirectories:YES attributes:nil error:NULL];
    
    while (1) {
        NSError *error;
        BOOL success = [self atomicallyWriteData:data toFile:filePath error:&error];
        if (success) {
            break;
        }
        
        // if race between multiple writers and writeToFile fails because a file already exists, then pick new number and try again
        if ([error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSFileWriteFileExistsError) {
            filePath = [self filePathForIdentifier:identifier withFileNumber:++fileNumber];
            if (filePath != nil) { // only ever expect it to be nil if fileNumber wraps around to become negative
                continue;
            }
        }
        
        return NO; // any other case of !success
    }
    
    if (fileNumberPtr) {
        *fileNumberPtr = fileNumber;
    }
    return YES;
}

- (void)deleteContentForIdentifier:(NSString *)identifier {
    
    // clear the single file created by base class
    [super deleteContentForIdentifier:identifier];
    
    // delete the queue director for this identifier
    NSString *directoryPath = [self messagePassingDirectoryPath];
    NSString *subDirectoryPath = [directoryPath stringByAppendingPathComponent:identifier];
    if (subDirectoryPath != nil) {
        [self.fileManager removeItemAtPath:subDirectoryPath error:NULL];
    }
}

@end

@interface MMQueuedWormhole ()
@property (nonatomic, strong) NSMutableSet *pluralListeners;
@end


@implementation MMQueuedWormhole
- (instancetype)initWithApplicationGroupIdentifier:(nullable NSString *)identifier
                                 optionalDirectory:(nullable NSString *)directory {
    if ((self = [super initWithApplicationGroupIdentifier:identifier
                                        optionalDirectory:directory]))
    {
        
        self.wormholeMessenger = [[MMQueuedWormholeFileTransiting alloc] initWithApplicationGroupIdentifier:[identifier copy]
                                                                                    optionalDirectory:[directory copy]];
    }
    
    return self;
}

#pragma mark - Overridden Private File Operation Methods


- (id)messageObjectFromFileWithIdentifier:(NSString *)identifier
{
    return [self messageObjectFromFileWithIdentifier:identifier notGreaterThanFileNumber:-1];
}

- (id)messageObjectFromFileWithIdentifier:(NSString *)identifier notGreaterThanFileNumber:(NSInteger)limitFileNumber
{
    if (identifier == nil) {
        return nil;
    }
    
    // first attempt to read from single file created by base class, only if its not present do we read from our subdirectory
    NSData *data = nil;
    NSString *filePath = [(MMQueuedWormholeFileTransiting *) self.wormholeMessenger filePathForIdentifier:identifier];
    BOOL isDir;
    NSFileManager *fileManager = ((MMQueuedWormholeFileTransiting *) self.wormholeMessenger).fileManager;
    if (filePath != nil && [fileManager fileExistsAtPath:filePath isDirectory:&isDir] && !isDir) {
        data = [(MMQueuedWormholeFileTransiting *) self.wormholeMessenger atomicallyReadAndDeleteFile:filePath error:NULL];
        
        if (data == nil) {
            return nil;
        }
    }
    
    else {
        NSInteger fileNumber = [(MMQueuedWormholeFileTransiting *) self.wormholeMessenger smallestFileNumberForIdentifier:identifier];
        filePath = [(MMQueuedWormholeFileTransiting *) self.wormholeMessenger filePathForIdentifier:identifier withFileNumber:fileNumber];
        
        if (filePath == nil) {
            return nil;
        }
        
        while (limitFileNumber < 0 || fileNumber <= limitFileNumber) {
            NSError *error;
            data = [(MMQueuedWormholeFileTransiting *) self.wormholeMessenger atomicallyReadAndDeleteFile:filePath error:&error];
            if (data != nil) {
                break;
            }
            
            // if race between multiple readers and file has already been deleted, then find new smallest number and try again
            if (error.code == 260) {
                NSInteger updatedFileNumber = [(MMQueuedWormholeFileTransiting *) self.wormholeMessenger smallestFileNumberForIdentifier:identifier];
                if (updatedFileNumber != fileNumber) {
                    fileNumber = updatedFileNumber;
                    filePath = [(MMQueuedWormholeFileTransiting *) self.wormholeMessenger filePathForIdentifier:identifier withFileNumber:updatedFileNumber];
                    if (filePath != nil) { // don't expect it to be nil
                        continue;
                    }
                }
            }
            
            return nil; // any other case of !data
        }
    }
    
    id messageObject = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    return messageObject;
}

- (void)clearMessageContentsForIdentifier:(NSString *)identifier {
    if (identifier == nil) {
        return;
    }
    [self.wormholeMessenger deleteContentForIdentifier:identifier];    
}

#pragma mark - Private Notification Methods

// !!! maybe include this to pass # along with identifier to didReceiveMessageNotification
//     also see commented out code in didReceiveMessageNotification:
//
//- (void)sendNotificationForMessageWithIdentifier:(NSString *)identifier fileNumber:(NSInteger)sendingFileNumber {
//    CFNotificationCenterRef const center = CFNotificationCenterGetDarwinNotifyCenter();
//    CFDictionaryRef const userInfo = (__bridge CFDictionaryRef)@{ @"number": @(sendingFileNumber) };
//    BOOL const deliverImmediately = YES;
//    CFStringRef str = (__bridge CFStringRef)identifier;
//    CFNotificationCenterPostNotification(center, str, NULL, userInfo, deliverImmediately);
//}
//
//- (void)registerForNotificationsWithIdentifier:(NSString *)identifier {
//    CFNotificationCenterRef const center = CFNotificationCenterGetDarwinNotifyCenter();
//    CFStringRef str = (__bridge CFStringRef)identifier;
//    CFNotificationCenterAddObserver(center,
//                                    (__bridge const void *)(self),
//                                    queuedWormholeNotificationCallback,
//                                    str,
//                                    NULL,
//                                    CFNotificationSuspensionBehaviorDeliverImmediately);
//}
//
//void queuedWormholeNotificationCallback(CFNotificationCenterRef center,
//                                        void * observer,
//                                        CFStringRef name,
//                                        void const * object,
//                                        CFDictionaryRef userInfo) {
//    NSString *identifier = (__bridge NSString *)name;
//    NSMutableDictionary *forwardUserInfo = [NSMutableDictionary dictionaryWithDictionary:@{@"identifier" : identifier}];
//    if (userInfo) {
//        [forwardUserInfo addEntriesFromDictionary:(__bridge NSDictionary *)userInfo];
//    }
//    [[NSNotificationCenter defaultCenter] postNotificationName:MMWormholeNotificationName
//                                                        object:nil
//                                                      userInfo:forwardUserInfo];
//}

- (void)didReceiveMessageNotification:(NSNotification *)notification
{
    typedef void (^MessageListenerBlock)(id messageObject);
    
    NSDictionary *userInfo = notification.userInfo;
    NSString *identifier = [userInfo valueForKey:@"identifier"];
//    NSString *fileNumberString = [userInfo valueForKey:@"number"];
//    NSInteger fileNumber = fileNumberString.integerValue;
    
    if (identifier != nil) {
        MessageListenerBlock listenerBlock = [self listenerBlockForIdentifier:identifier];
        
        if (listenerBlock) {
            // immediately call listener for any queued messages
            
            // if more being posted while this receiver app is running, stop receiving at largest file number determined here
            // not sure if this is worthwhile or not
            NSInteger limitFileNumber = [(MMQueuedWormholeFileTransiting *)self.wormholeMessenger largestFileNumberForIdentifier:identifier];
            
//            // if sender using base class and file number not given, there should be only 1 message so call listener with it
//            // otherwise call listener for any queued messages
//            if (fileNumberString == nil) {
//                id messageObject = [self messageObjectFromFileWithIdentifier:identifier notGreaterThanFileNumber:-1];
//                if (messageObject) {
//                    // if lister for this identifier expecting array, return single object wrapped in an array
//                    listenerBlock([self.pluralListeners containsObject:identifier] ? @[ messageObject ] : messageObject);
//                }
//            }
//            else {
//            }
            
            // if lister for this identifier expecting array, create array for collecting messages
            NSMutableArray *messageObjects = nil;
            if ([self.pluralListeners containsObject:identifier]) {
                messageObjects = [NSMutableArray array];
            }
            
            while (1) {
                id messageObject = [self messageObjectFromFileWithIdentifier:identifier notGreaterThanFileNumber:limitFileNumber];
                if (!messageObject) {
                    break;
                }
                
                // if exists an array for collecting messages, append each message object, otherwise call listener once for each
                // in most use cases this will loop only once
                if (messageObjects) {
                    [messageObjects addObject:messageObject];
                }
                else {
                    listenerBlock(messageObject);
                }
            }
            
            // if exists an array for collecting objects, call listener once passing that array
            if (messageObjects) {
                listenerBlock(messageObjects);
            }
            
        }
    }
}


#pragma mark - Private Property Lazy Initialization

- (NSMutableSet *)pluralListeners
{
    if (!_pluralListeners) {
        _pluralListeners = [NSMutableSet set];
    }
    return _pluralListeners;
}


#pragma mark - Public Interface Methods

- (void)listenForMessageWithIdentifier:(NSString *)identifier listener:(void (^)(id messageObject))listener
{
    if (identifier != nil) {
        // to fix race condition (removing pluralListeners inclusion for identifier before the old plural listener has been replaced)
        // must remove the old listener first
        if ([self.pluralListeners containsObject:identifier]) {
            [super stopListeningForMessageWithIdentifier:identifier];
        }
        
        [self.pluralListeners removeObject:identifier];
        
        [super listenForMessageWithIdentifier:identifier listener:listener];
        
        // immediately call listener for any existing queued messages
        
        // if more being posted while this receiver app is running, stop receiving at largest file number determined here
        // not sure if this is worthwhile or not
        NSInteger limitFileNumber = [(MMQueuedWormholeFileTransiting *)self.wormholeMessenger largestFileNumberForIdentifier:identifier];
        
        while (1) {
            id messageObject = [self messageObjectFromFileWithIdentifier:identifier notGreaterThanFileNumber:limitFileNumber];
            if (!messageObject) {
                break;
            }
            
            // call once for each message object, in most use cases this will loop only once
            listener(messageObject);
        }
    }
}

- (void)listenForMessagesWithIdentifier:(NSString *)identifier listener:(void (^)(NSArray *messageObjects))listener
{
    if (identifier != nil) {
        // to fix race condition (setting pluralListeners inclusion for identifier before the old singular listener has been replaced)
        // must remove the old listener first
        if (![self.pluralListeners containsObject:identifier]) {
            [super stopListeningForMessageWithIdentifier:identifier];
        }
        
        [self.pluralListeners addObject:identifier];
        
        [super listenForMessageWithIdentifier:identifier listener:listener];
        
        // immediately call listener if any existing queued messages
        
        // if more being posted while this receiver app is running, stop receiving at largest file number determined here
        // not sure if this is worthwhile or not
        NSInteger limitFileNumber = [(MMQueuedWormholeFileTransiting *)self.wormholeMessenger largestFileNumberForIdentifier:identifier];
        
        NSMutableArray *messageObjects = [NSMutableArray array];
        
        while (1) {
            id messageObject = [self messageObjectFromFileWithIdentifier:identifier notGreaterThanFileNumber:limitFileNumber];
            if (!messageObject) {
                break;
            }
            
            // append each message object to the array, in most use cases this will loop only once
            [messageObjects addObject:messageObject];
        }
        
        // if any message objects collected, call listener once passing that array
        if (messageObjects.count > 0) {
            listener(messageObjects);
        }
    }
}

- (void)stopListeningForMessagesWithIdentifier:(NSString *)identifier
{
    [super stopListeningForMessageWithIdentifier:identifier];
    
    [self.pluralListeners removeObject:identifier];
}

- (NSArray *)messagesWithIdentifier:(NSString *)identifier
{
    NSInteger limitFileNumber = [(MMQueuedWormholeFileTransiting *)self.wormholeMessenger largestFileNumberForIdentifier:identifier];
    
    NSMutableArray *messageObjects = [NSMutableArray array];
    
    while (1) {
        id messageObject = [self messageObjectFromFileWithIdentifier:identifier notGreaterThanFileNumber:limitFileNumber];
        if (!messageObject) {
            break;
        }
        
        // append each message object to the array, in most use cases this will loop only once
        [messageObjects addObject:messageObject];
    }
    
    // if any message objects collected, return that array, otherwise return nil
    return (messageObjects.count > 0) ? messageObjects : nil;
}

@end
