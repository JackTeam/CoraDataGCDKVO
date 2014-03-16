//
//  CoreDataController.h
//  CoraDataGCDKVO
//
//  Created by 曾 宪华 on 13-8-26.
//  Copyright (c) 2013年 Jack_team. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CoreDataController : NSObject

+ (id)sharedInstance;

- (NSURL *)applicationDocumentsDirectory;

- (NSManagedObjectContext *)masterManagedObjectContext;
- (NSManagedObjectContext *)backgroundManagedObjectContext;
- (NSManagedObjectContext *)newManagedObjectContext;
- (void)saveMasterContext;
- (void)saveBackgroundContext;
- (NSManagedObjectModel *)managedObjectModel;
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;

@end
