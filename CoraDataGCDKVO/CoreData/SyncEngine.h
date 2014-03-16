//
//  SyncEngine.h
//  CoraDataGCDKVO
//
//  Created by 曾 宪华 on 13-8-26.
//  Copyright (c) 2013年 Jack_team. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    ObjectSynced = 0,
    ObjectCreated,
    ObjectDeleted,
    ObjectUpData,
} ObjectSyncStatus;


@interface SyncEngine : NSObject

@property (atomic, readonly) BOOL syncInProgress;

+ (SyncEngine *)sharedEngine;

- (void)cancelNSManagedObjectClassToSync:(Class)aClass;
- (void)registerNSManagedObjectClassToSync:(Class)aClass;
- (void)startSync;

- (NSString *)dateStringForAPIUsingDate:(NSDate *)date;

@end
