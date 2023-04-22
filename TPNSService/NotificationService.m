//
//  NotificationService.m
//  XGService
//
//  Created by uwei on 09/08/2017.
//  Copyright © 2017 tyzual. All rights reserved.
//

#import "NotificationService.h"
#import "XGExtension.h"
#import <UIKit/UIKit.h>

@interface NotificationService ()

/// content handler
@property (nonatomic, strong) void (^contentHandler)(UNNotificationContent *contentToDeliver);
/// notification content
@property (nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;

@end

/// An object that modifies the content of a remote notification before it's delivered to the user.
@implementation NotificationService

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent *_Nonnull))contentHandler {
	self.contentHandler = contentHandler;
	self.bestAttemptContent = [request.content mutableCopy];

	[XGExtension defaultManager].reportDomainName = @"tpns.sh.tencent.com";

	[[XGExtension defaultManager] handleNotificationRequest:request accessID:1680015447 accessKey:@"IOSAEBOQD6US" contentHandler:^(NSArray<UNNotificationAttachment *> *_Nullable attachments, NSError *_Nullable error) {
		self.bestAttemptContent.attachments = attachments;
		self.contentHandler(self.bestAttemptContent);
	}];
}

- (void)serviceExtensionTimeWillExpire {
    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
    self.contentHandler(self.bestAttemptContent);
}

@end


