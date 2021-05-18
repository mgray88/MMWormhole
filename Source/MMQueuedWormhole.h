//
//  MMQueuedWormhole.h
//  MMWormhole
//
//  Created by Pierre Houston on 2015-03-11.
//  Copyright (c) 2015 Conrad Stoll. All rights reserved.
//

#import "MMWormhole.h"
#import "MMWormholeFileTransiting.h"

/**
 This subclass of MMWormhole ensures every message sent to the wormhole will be received in order
 by the recipient even while its not listening. The changes to the base class' semantics are:
   1. The messageWithIdentifier: method can be called repeatedly to get each of the sent messages,
      and it will return nil when there are none remaining. This constrast with the base class
      which only saves the most recent message and returns it over and over on repeated calls.
   2. When listenForMessage is called and there are queued messages that haven't been received yet
      then the block will immediately once for each queued messages in order.
 Also, two variations on messageWithIdentifier: & listenForMessageWithIdentifier: are implemented
 that return an array of all queued objects at once, these are messagesWithIdentifier: and
 listenForMessagesWithIdentifier: (pluralized), documented below.
 */
@interface MMQueuedWormhole : MMWormhole

/**
 This method returns the value of all queued messages with a specific identifier as an array of
 objects, in order they were posted.
 
 @param identifier The identifier for the message
 @return In-order array of posted messages
 */
- (NSArray *)messagesWithIdentifier:(NSString *)identifier;

/**
 This method begins listening for notifications of changes to a message with a specific identifier.
 If notifications are observed then the given listener block will be called along with an array of
 the actual message objects in order they were posted. The block is usually passed an array of one
 single object, but, primarily, when this listen method is first called and there are multiple
 queued messages, that's when the block will be passed an array of multiple objects.
 Also if the application is not running when mutliple messages are posted, when the app is brought
 to the foreground then the listener block will also be passed an array of multiple objects.
 
 @discussion This class only supports one listener per message identifier, so calling this method
 repeatedly for the same identifier will update the listener block that will be called when
 messages are heard.
 
 @param identifier The identifier for the message
 @param listener A listener block called with the messageObjects parameter when a notification
 is observed, or called immediately if messages are queued at the time.
 */
- (void)listenForMessagesWithIdentifier:(NSString *)identifier
                               listener:(void (^)(NSArray *messageObjects))listener;

/**
 This method is synonomous with stopListeningForMessageWithIdentifier: (name is pluralized).
 It should be used to balance calls to listenForMessagesWithIdentifier:listener:, although
 currently calling either would work (but that may not be true in future versions of this class).
 */
- (void)stopListeningForMessagesWithIdentifier:(NSString *)identifier;

@end

@interface MMQueuedWormholeFileTransiting : MMWormholeFileTransiting
@end
