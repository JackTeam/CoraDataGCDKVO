//
//  SyncEngine.m
//  CoraDataGCDKVO
//
//  Created by 曾 宪华 on 13-8-26.
//  Copyright (c) 2013年 嗨，我是曾宪华(@xhzengAIB)，曾加入YY Inc.担任高级移动开发工程师，拍立秀App联合创始人，热衷于简洁、而富有理性的事物 QQ:543413507 主页:http://zengxianhua.com All rights reserved.
//

#import "SyncEngine.h"
#import "CoreDataController.h"
#import "NSManagedObject+JSON.h"
#import "ApiClient.h"
#import "AFHTTPRequestOperation.h"
#import "AFJSONRequestOperation.h"

NSString * const kSyncEngineSyncCompletedNotificationName = @"SyncEngineSyncCompleted";
NSString * const kSyncEngineInitialCompleteKey = @"SyncEngineInitialSyncCompleted";

@interface SyncEngine ()

@property (nonatomic, strong) NSMutableArray *registeredClassesToSync;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end

@implementation SyncEngine

@synthesize syncInProgress = _syncInProgress;

@synthesize registeredClassesToSync = _registeredClassesToSync;
@synthesize dateFormatter = _dateFormatter;

/**
 *  得到同步本地数据库与远程服务器数据的單例对象
 *
 *  @return 返回單例对象
 */
+ (SyncEngine *)sharedEngine {
    static SyncEngine *sharedEngine;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedEngine = [[SyncEngine alloc] init];
    });
    
    return sharedEngine;
}


- (void)cancelNSManagedObjectClassToSync:(Class)aClass {
    if (self.registeredClassesToSync) {
        if ([aClass isSubclassOfClass:[NSManagedObject class]]) {
            if ([self.registeredClassesToSync containsObject:NSStringFromClass(aClass)]) {
                [self.registeredClassesToSync removeObject:NSStringFromClass(aClass)];
            } else {
                NSLog(@"无法删除该实体 ： %@，因为不存在 ", NSStringFromClass(aClass));
            }
        } else {
            NSLog(@"无法注册,它不是%@ NSManagedObject的一个子类", NSStringFromClass(aClass));
        }
    }
}


/**
 *  注册一个CoreData实体对象
 *
 *  @param aClass 实体对象的类名
 */
- (void)registerNSManagedObjectClassToSync:(Class)aClass {
    if (!self.registeredClassesToSync) {
        self.registeredClassesToSync = [NSMutableArray array];
    }
    
    if ([aClass isSubclassOfClass:[NSManagedObject class]]) {
        if (![self.registeredClassesToSync containsObject:NSStringFromClass(aClass)]) {
            [self.registeredClassesToSync addObject:NSStringFromClass(aClass)];
        } else {
            NSLog(@"Unable to register %@ as it is already registered", NSStringFromClass(aClass));
        }
    } else {
        NSLog(@"Unable to register %@ as it is not a subclass of NSManagedObject", NSStringFromClass(aClass));
    }
}

/**
 *  开始同步，这个是进行网络下载的，利用GCD进行后台线程下载
 */
- (void)startSync {
    if (!self.syncInProgress) {
        NSLog(@"startSync");
        [self willChangeValueForKey:@"syncInProgress"];
        _syncInProgress = YES;
        [self didChangeValueForKey:@"syncInProgress"];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            /**
             *  开始下载
             */
            [self downloadDataForRegisteredObjects:YES toDeleteLocalRecords:NO];
        });
    }
}

 /**
 *   同步完成，进行GCD回调到主线程
 */
- (void)executeSyncCompletedOperations {
    [self setInitialSyncCompleted];
    NSError *error = nil;
    [[CoreDataController sharedInstance] saveBackgroundContext];
    if (error) {
        NSLog(@"Error saving background context after creating objects on server: %@", error);
    }
    
    [[CoreDataController sharedInstance] saveMasterContext];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        /**
         *  发送下载完成的通知
         */
        [[NSNotificationCenter defaultCenter]
         postNotificationName:kSyncEngineSyncCompletedNotificationName
         object:nil];
        /**
         *   这里是KVO通知，下载进度
         */
        [self willChangeValueForKey:@"syncInProgress"];
        _syncInProgress = NO;
        [self didChangeValueForKey:@"syncInProgress"];
    });
}

/**
 *  获取下载同步状态
 *
 *  @return YES  或者   NO，因为是用来判断下载状态的
 */
- (BOOL)initialSyncComplete {
    return [[[NSUserDefaults standardUserDefaults] valueForKey:kSyncEngineInitialCompleteKey] boolValue];
}

/**
 *  设置同步完成的一个本地化方法
 */
- (void)setInitialSyncCompleted {
    [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES] forKey:kSyncEngineInitialCompleteKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/**
 *  最近更新日期为实体与名称
 *
 *  @param entityName 实体名
 *
 *  @return 返回最新更新的时间
 */

- (NSDate *)mostRecentUpdatedAtDateForEntityWithName:(NSString *)entityName {
    __block NSDate *date = nil;
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
    [request setSortDescriptors:[NSArray arrayWithObject:
                                 [NSSortDescriptor sortDescriptorWithKey:@"updatedAt" ascending:NO]]];
    [request setFetchLimit:1];
    [[[CoreDataController sharedInstance] backgroundManagedObjectContext] performBlockAndWait:^{
        NSError *error = nil;
        NSArray *results = [[[CoreDataController sharedInstance] backgroundManagedObjectContext] executeFetchRequest:request error:&error];
        if ([results lastObject])   {
            date = [[results lastObject] valueForKey:@"updatedAt"];
        }
    }];
    
    return date;
}

/**
 *   开始下载不同远程服务器的数据库，不要以为只是下载远程服务器上的数据哦！你有可能是删除了远程数据库上的数据，然后你也需要把自己本地数据库带有删除标识的数据实体同步到远程服务器中
 *
 *  @param useUpdatedAtDate 是否使用UpdatedAtDate 作为实体的表示
 *  @param toDelete         是否位删除本地记录实体
 */
- (void)downloadDataForRegisteredObjects:(BOOL)useUpdatedAtDate toDeleteLocalRecords:(BOOL)toDelete {
    NSMutableArray *operations = [NSMutableArray array];
    for (NSString *className in self.registeredClassesToSync) {
        /**
         *  最近更新日期
         */
        NSDate *mostRecentUpdatedDate = nil;
        if (useUpdatedAtDate) {
            mostRecentUpdatedDate = [self mostRecentUpdatedAtDateForEntityWithName:className];
        }
        NSMutableURLRequest *request = [[ApiClient sharedClient]
                                        GETRequestForAllRecordsOfClass:className
                                        updatedAfterDate:mostRecentUpdatedDate];
        AFJSONRequestOperation *jsonOperation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                if ([JSON isKindOfClass:[NSDictionary class]]) {
                    [self writeJSONResponse:JSON toDiskForClassWithName:className];
                }
            });
        } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
            NSLog(@"Request for class %@ failed with error: %@", className, error);
        }];
        [operations addObject:jsonOperation];
    }
    
    /**
     *  等待下载队列完成
     *
     *  @param numberOfCompletedOperations 下载队列
     *  @param totalNumberOfOperations     总的队列数目
     *
     *  @return 空
     */
    [[ApiClient sharedClient] enqueueBatchOfHTTPRequestOperations:operations progressBlock:^(NSUInteger numberOfCompletedOperations, NSUInteger totalNumberOfOperations) {
        
    } completionBlock:^(NSArray *operations) {
        /**
         *  判断是进行删除过程还是写入CoreData数据库过程
         */
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (!toDelete) {
                [weakSelf processJSONDataRecordsIntoCoreData];
            } else {
                [weakSelf processJSONDataRecordsForDeletion];
            }
        });
    }];
}

/**
 *  把JSON数据过程记录到CoreData 这里会把JSON缓存删除的
 */
- (void)processJSONDataRecordsIntoCoreData {
    /**
     *  因为这里下载完成后调用的函数，所以是把数据进行缓存的地方，现在是
     */
    NSManagedObjectContext *managedObjectContext = [[CoreDataController sharedInstance] backgroundManagedObjectContext];
    /**
     *  循环看看有多少个实体类型需要进行次操作
     */
    for (NSString *className in self.registeredClassesToSync) {
        /**
         *  判断是否下载完成，如果是下载完成的话那就需要缓存数据到CoreData数据库中去
         */
        if (![self initialSyncComplete]) { // import all downloaded data to Core Data for initial sync
            NSDictionary *JSONDictionary = [self JSONDictionaryForClassWithName:className];
            /**
             *  这里是得到服务器返回的字典中，主要的Key是 results
             */
            NSArray *records = [JSONDictionary objectForKey:@"results"];
            for (NSDictionary *record in records) {
                [self newManagedObjectWithClassName:className forRecord:record];
            }
        } else {
            /**
             *  如果没有下载完成的话，就在JSON缓存目录找到对应的实体对象数组，返回来的是排好序的，所以进行判断是否为空，如果不为空，那就说明是存在的，如果为空，那不就进行任何操作哦！downloadedRecords 该数组是远程服务最新的数据
             
             虽然是在本地JSON缓存目录获取的数据，但是你要知道，这里是下载完成后调用的地方，所以，数据已经写入本地JSON缓存目录里面了，获取回来的当然是服务器最新的数据
             */
            
            NSArray *downloadedRecords = [self JSONDataRecordsForClass:className sortedByKey:@"objectId"];
            if ([downloadedRecords lastObject]) {
                /**
                 *  [downloadedRecords valueForKey:@"objectId"] 这里有个技巧，就是在含有字典的数组里面使用valueForKey会返回数组一样个数的数组回来，并且是对应Key的值组合为一个数组，哈哈！
                 
                    这里是进行比较的，判断本地数据库和下载数据中是否有重复，如果有那就会返回本地数据库和远程服务器中相同的数据，如果真的会存在
                 */
                NSArray *storedRecords = [self managedObjectsForClass:className sortedByKey:@"objectId" usingArrayOfIds:[downloadedRecords valueForKey:@"objectId"] inArrayOfIds:YES];
                
                int currentIndex = 0;
                for (NSDictionary *record in downloadedRecords) {
                    NSManagedObject *storedManagedObject = nil;
                    if ([storedRecords count] > currentIndex) {
                        /**
                         *  这里获取一个本地服务器和远程服务器都有的实体对象
                         */
                        storedManagedObject = [storedRecords objectAtIndex:currentIndex];
                    }
                    
                    /**
                     *  进行判断，在CoreData中是否存在，如果存在那就进行更新操作，如果不存在那就进行创建操作
                     */
                    if ([[storedManagedObject valueForKey:@"objectId"] isEqualToString:[record valueForKey:@"objectId"]]) {
                        // 如果是从本地数据库也存在的数据，那就执行更新数据
                        [self updateManagedObject:[storedRecords objectAtIndex:currentIndex] withRecord:record];
                    } else {
                        // 如果本地数据库不存在的，那就执行插入新的数据
                        [self newManagedObjectWithClassName:className forRecord:record];
                    }
                    currentIndex++;
                }
            }
        }
        
        // 等到存档完成，记住是一定会完成后才会往下执行的哦！
        [managedObjectContext performBlockAndWait:^{
            NSError *error = nil;
            if (![managedObjectContext save:&error]) {
                NSLog(@"Unable to save context for class %@", className);
            }
        }];
                
        // 尽然存档完成，那就需要删除本地JSON缓存文件
        [self deleteJSONDataRecordsForClassWithName:className];
    }
    
    // 然后这里需要重复一遍的检查，主要是为了删除本地数据库上的数据，因为远程服务器已经删除了啊！  这里的NO  应该是不需要最新的数据，-------主要的目的还有：该才做还是位于更新完最新的数据后的，所以这里只是做后台工作的问题，同步数据只是后台做就好了，用户永远都不需要知道
    [self downloadDataForRegisteredObjects:NO toDeleteLocalRecords:YES];
}

/**
 *  JSON数据记录删除过程   这里会把JSON缓存删除的
 */
- (void)processJSONDataRecordsForDeletion {
    NSManagedObjectContext *managedObjectContext = [[CoreDataController sharedInstance] backgroundManagedObjectContext];
    for (NSString *className in self.registeredClassesToSync) {
        // 获取本地JSON缓存数据数组，这里就是下载好的数据，如果为空的话，获取数据有两种方式，一个是最新的，一个是全部数据，
        NSArray *JSONRecords = [self JSONDataRecordsForClass:className sortedByKey:@"objectId"];
        // 如果有数据存在
        // 找和本地数据不一样的数据，因为NOT (objectId IN %@)，array）所以意思是：当本地数据有一些不存在于远程服务器的数据，那本地就必须要的删除
        NSArray *storedRecords = [self
                                  managedObjectsForClass:className
                                  sortedByKey:@"objectId"
                                  usingArrayOfIds:[JSONRecords valueForKey:@"objectId"]
                                  inArrayOfIds:NO];
        if (storedRecords.count > 0) {
            [managedObjectContext performBlockAndWait:^{
                for (NSManagedObject *managedObject in storedRecords) {
                    if ([[managedObject valueForKey:@"syncStatus"] integerValue] == ObjectSynced)
                        [managedObjectContext deleteObject:managedObject];
                }
                NSError *error = nil;
                BOOL saved = [managedObjectContext save:&error];
                if (!saved) {
                    NSLog(@"Unable to save context after deleting records for class %@ because %@", className, error);
                }
            }];
        } else {
            [managedObjectContext performBlockAndWait:^{
                for (NSManagedObject *managedObject in storedRecords) {
                        [managedObjectContext deleteObject:managedObject];
                }
                NSError *error = nil;
                BOOL saved = [managedObjectContext save:&error];
                if (!saved) {
                    NSLog(@"Unable to save context after deleting records for class %@ because %@", className, error);
                }
            }];
        }
        
        
        // 执行完后，需要把本地的JSON缓存数据删除了
        [self deleteJSONDataRecordsForClassWithName:className];
    }
    
    // 然后同步本地数据库的数据到远程服务器的数据库
    [self postLocalObjectsToServer];
}

/**
 *  在CoreData数据库里面创建一个新的实体对象
 *
 *  @param className 实体对象类型
 *  @param record    记录字典，意思是什么呢？查查先
 */
- (void)newManagedObjectWithClassName:(NSString *)className forRecord:(NSDictionary *)record {
    /**
     *  插入数据到CoreData数据库中   insertNewObjectForEntityForName
     */
    NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:[[CoreDataController sharedInstance] backgroundManagedObjectContext]];
    [record enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [self setValue:obj forKey:key forManagedObject:newManagedObject];
    }];
    [record setValue:[NSNumber numberWithInt:ObjectSynced] forKey:@"syncStatus"];
}

- (void)updateManagedObject:(NSManagedObject *)managedObject withRecord:(NSDictionary *)record {
    [record enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [self setValue:obj forKey:key forManagedObject:managedObject];
    }];
}

/**
 *  在新建实体对象的时候，或者更新实体对象的时候需要设置里面的具体内容
 *
 *  @param value         设置的值
 *  @param key           设置的Key
 *  @param managedObject 对那个实体进行设置
 */
- (void)setValue:(id)value forKey:(NSString *)key forManagedObject:(NSManagedObject *)managedObject {
    if ([key isEqualToString:@"createdAt"] || [key isEqualToString:@"updatedAt"]) {
        NSDate *date = [self dateUsingStringFromAPI:value];
        [managedObject setValue:date forKey:key];
    } else if ([value isKindOfClass:[NSDictionary class]]) {
        if ([value objectForKey:@"__type"]) {
            NSString *dataType = [value objectForKey:@"__type"];
            if ([dataType isEqualToString:@"Date"]) {
                 /**
                 *  这里是时间的判断
                 */
                NSString *dateString = [value objectForKey:@"iso"];
                NSDate *date = [self dateUsingStringFromAPI:dateString];
                [managedObject setValue:date forKey:key];
            } else if ([dataType isEqualToString:@"File"]) {
                /**
                 *   这里还直接把网络图片转换为NSData来进行缓存图片，我觉得没必要，因为可以用URLCache，这样只需要存URL链接就可以了
                 */
                // 这里阻碍了主线程
                NSString *urlString = [value objectForKey:@"url"];
                /*
                NSURL *url = [NSURL URLWithString:urlString];
                NSURLRequest *request = [NSURLRequest requestWithURL:url];
                NSURLResponse *response = nil;
                NSError *error = nil;
                NSData *dataResponse = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                [managedObject setValue:dataResponse forKey:key];
                 */
                [managedObject setValue:urlString forKey:@"imageUrl"];
            } else {
                NSLog(@"Unknown Data Type Received");
                [managedObject setValue:nil forKey:key];
            }
        }
    } else {
        [managedObject setValue:value forKey:key];
    }
}

/**
 *  上传本地实体对象到服务器，意思是利用HTTP方式来访问服务器，把本地数据上传到服务器
 */
- (void)postLocalObjectsToServer {
    NSMutableArray *operations = [NSMutableArray array];
     /**
     *  先获取本地是否有最新创建的数据需要上传到服务器的，如果有，那就开始更新到服务器
     */
    for (NSString *className in self.registeredClassesToSync) {
        // 这里是得到本地新建的数据实体，因为还没有同步到远程服务器的数据里面去
        NSArray *objectsToCreate = [self managedObjectsForClass:className withSyncStatus:ObjectCreated];
        for (NSManagedObject *objectToCreate in objectsToCreate) {
            // 这里利用分类的方式，检查JSON格式
            NSDictionary *jsonString = [objectToCreate JSONToCreateObjectOnServer];
            NSMutableURLRequest *request = [[ApiClient sharedClient] POSTRequestForClass:className parameters:jsonString];
            
            AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                NSLog(@"Success creation: %@", JSON);
                NSDictionary *responseDictionary = JSON;
                NSDate *createdDate = [self dateUsingStringFromAPI:[responseDictionary valueForKey:@"createdAt"]];
                [objectToCreate setValue:createdDate forKey:@"createdAt"];
                [objectToCreate setValue:[responseDictionary valueForKey:@"objectId"] forKey:@"objectId"];
                // 这里如果上传成功的话，那你就得给我重新设置状态，因为是已经同步了，所以是ObjectSynced；
                [objectToCreate setValue:[NSNumber numberWithInt:ObjectSynced] forKey:@"syncStatus"];
            } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
                NSLog(@"Failed creation: %@", error);
            }];
            
            [operations addObject:operation];
        }
        
        NSArray *objectsToUpData = [self managedObjectsForClass:className withSyncStatus:ObjectUpData];
        for (NSManagedObject *objectToUpData in objectsToUpData) {
            // 这里利用分类的方式，检查JSON格式
            NSDictionary *jsonString = [objectToUpData JSONToCreateObjectOnServer];
            NSMutableURLRequest *request = [[ApiClient sharedClient] PUTRequestForClass:className atObjectId:[objectToUpData valueForKey:@"ObjectId"] parameters:jsonString];
            
            AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                NSLog(@"Success creation: %@", JSON);
                NSDictionary *responseDictionary = JSON;
                NSDate *updated = [self dateUsingStringFromAPI:[responseDictionary valueForKey:@"updatedAt"]];
                [objectToUpData setValue:updated forKey:@"updatedAt"];
                // 这里如果上传成功的话，那你就得给我重新设置状态，因为是已经同步了，所以是ObjectSynced；
                [objectToUpData setValue:[NSNumber numberWithInt:ObjectSynced] forKey:@"syncStatus"];
            } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
                NSLog(@"Failed creation: %@", error);
            }];
            
            [operations addObject:operation];
        }
        
    }
    
    /**
     *  等待本地上传更新完成后，开始把本地带有删除表示的数据同步到服务器，让服务器也删除该实体，进行通知工作的
     *
     *  @param numberOfCompletedOperations 需要等待的队列
     *  @param totalNumberOfOperations     总的队列数目
     *
     *  @return 空
     */
    [[ApiClient sharedClient] enqueueBatchOfHTTPRequestOperations:operations progressBlock:^(NSUInteger numberOfCompletedOperations, NSUInteger totalNumberOfOperations) {
        NSLog(@"Completed %d of %d create operations", numberOfCompletedOperations, totalNumberOfOperations);
    } completionBlock:^(NSArray *operations) {
        /**
         *  发送请求让服务器删除实体
         */
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if ([operations count] > 0) {
                NSSet *updataObjects = [[[CoreDataController sharedInstance] backgroundManagedObjectContext] updatedObjects];
                NSLog(@"Creation of objects on server compelete, updated objects in context: %@", updataObjects);
                // 保存，因为上面如果访问成功需要对数据库的数据进行操作的，主要是因为数据的状态会从Create转为synce状态，所以需要等到下载线程完成后，进行数据保存
                [[CoreDataController sharedInstance] saveBackgroundContext];
                NSLog(@"SBC After call creation");
            }
            
            [self deleteObjectsOnServer];
        });
        
        
    }];
}

/**
 *  在服务器上删除实体对象，意思是用HTPP请求的方式来进行访问服务器
 */
- (void)deleteObjectsOnServer {
    NSMutableArray *operations = [NSMutableArray array];
    for (NSString *className in self.registeredClassesToSync) {
        /**
         *  开始获取带有删除表示的实体
         */
        NSArray *objectsToDelete = [self managedObjectsForClass:className withSyncStatus:ObjectDeleted];
        // 循环遍历，删除
        for (NSManagedObject *objectToDelete in objectsToDelete) {
            NSMutableURLRequest *request = [[ApiClient sharedClient]
                                            DELETERequestForClass:className
                                            forObjectWithId:[objectToDelete valueForKey:@"objectId"]];
            AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                NSLog(@"Success deletion: %@", JSON);
                [[[CoreDataController sharedInstance] backgroundManagedObjectContext] deleteObject:objectToDelete];
            } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
                NSLog(@"Failed to delete: %@", error);
            }];
            
            [operations addObject:operation];
        }
    }
    
    /**
     *  等待删除队列完成，进行通知工作的
     *
     *  @param numberOfCompletedOperations 删除队列
     *  @param totalNumberOfOperations     总的队列数目
     *
     *  @return 空
     */
    [[ApiClient sharedClient] enqueueBatchOfHTTPRequestOperations:operations progressBlock:^(NSUInteger numberOfCompletedOperations, NSUInteger totalNumberOfOperations) {
        
    } completionBlock:^(NSArray *operations) {
        // 执行回调到主线程，然后更新UI
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if ([operations count] > 0) {
                NSLog(@"Deletion of objects on server compelete, updated objects in context: %@", [[[CoreDataController sharedInstance] backgroundManagedObjectContext] updatedObjects]);
            }
            
            [self executeSyncCompletedOperations];
        });
        
    }];
}

/**
 *  获取同步状态不同的实体对象数组
 *
 *  @param className  实体对象类型
 *  @param syncStatus 实体同步状态枚举
 *
 *  @return 返回查询数组
 */
- (NSArray *)managedObjectsForClass:(NSString *)className withSyncStatus:(ObjectSyncStatus)syncStatus {
    __block NSArray *results = nil;
    NSManagedObjectContext *managedObjectContext = [[CoreDataController sharedInstance] backgroundManagedObjectContext];
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:className];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"syncStatus = %d", syncStatus];
    [fetchRequest setPredicate:predicate];
    [managedObjectContext performBlockAndWait:^{
        NSError *error = nil;
        results = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    }];
    
    return results;
}

/**
 *  根据某个Key进行排序和筛选得到实体对象数组
 *
 *  @param className 需要获取的实体对象类型
 *  @param key       排序Key
 *  @param idArray   比较的实体对象数组
 *  @param inIds     决定是否进行对现有的实体对象数组进行比较，比如说，这个实体对象是否在这个数组里面，如果存在的话，可能就只是更新改实体，而不是从新创建一个新的实体
 *
 *  @return 返回比较好的实体对象数组
 */
- (NSArray *)managedObjectsForClass:(NSString *)className sortedByKey:(NSString *)key usingArrayOfIds:(NSArray *)idArray inArrayOfIds:(BOOL)inIds {
    if (!idArray) {
        return nil;
    }
    __block NSArray *results = nil;
    NSManagedObjectContext *managedObjectContext = [[CoreDataController sharedInstance] backgroundManagedObjectContext];
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:className];
    NSPredicate *predicate;
    if (inIds) {
        // 查询条件为，需要查询的数组里面的元素是否在idArray数组里面，如果在，那就过滤出来
        predicate = [NSPredicate predicateWithFormat:@"objectId IN %@", idArray];
    } else {
        // 查询条件为，需要查询的数组里面的元素是否不在idArray数组里面，如果不在，那就过滤出来
        predicate = [NSPredicate predicateWithFormat:@"NOT (objectId IN %@)", idArray];
    }
    
    [fetchRequest setPredicate:predicate];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:
                                      [NSSortDescriptor sortDescriptorWithKey:@"objectId" ascending:YES]]];
    [managedObjectContext performBlockAndWait:^{
        NSError *error = nil;
        results = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    }];
    
    return results;
}

 /**
 *  格式化时间的格式
 */
- (void)initializeDateFormatter {
    if (!self.dateFormatter) {
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
        [self.dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
    }
}

/**
 *  转换格式化后的字符串时间
 *
 *  @param dateString 需要转换的格式化时间字符串
 *
 *  @return 返回NSdate对象
 */
- (NSDate *)dateUsingStringFromAPI:(NSString *)dateString {
    [self initializeDateFormatter];
    // NSDateFormatter does not like ISO 8601 so strip the milliseconds and timezone
    dateString = [dateString substringWithRange:NSMakeRange(0, [dateString length]-5)];
    
    return [self.dateFormatter dateFromString:dateString];
}

/**
 *  转换时间为格式化的时间
 *
 *  @param date 需要格式化的时间
 *
 *  @return 返回格式化后的时间字符串
 */
- (NSString *)dateStringForAPIUsingDate:(NSDate *)date {
    [self initializeDateFormatter];
    NSString *dateString = [self.dateFormatter stringFromDate:date];
    // remove Z
    dateString = [dateString substringWithRange:NSMakeRange(0, [dateString length]-1)];
    // add milliseconds and put Z back on
    dateString = [dateString stringByAppendingFormat:@".000Z"];
    
    return dateString;
}

#pragma mark - File Management

/**
 *  获取数据库缓存的目录
 *
 *  @return 返回目录的URL
 */
- (NSURL *)applicationCacheDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
}

/**
 *  JSON数据的缓存目录
 *
 *  @return 返回JSON数据的缓存目录URL
 */
- (NSURL *)JSONDataRecordsDirectory {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *url = [NSURL URLWithString:@"JSONRecords/" relativeToURL:[self applicationCacheDirectory]];
    NSError *error = nil;
    if (![fileManager fileExistsAtPath:[url path]]) {
        [fileManager createDirectoryAtPath:[url path] withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    return url;
}

 /**
 *  写JSON数据到硬盘中,这里也只是过度，而不是一直存在磁盘中
 *
 *  @param response  需要写入的数据,
 *  @param className 类名称，比如实体User
 */
- (void)writeJSONResponse:(id)response toDiskForClassWithName:(NSString *)className {
    NSURL *fileURL = [NSURL URLWithString:className relativeToURL:[self JSONDataRecordsDirectory]];
    if (![(NSDictionary *)response writeToFile:[fileURL path] atomically:YES]) {
        NSLog(@"Error saving response to disk, will attempt to remove NSNull values and try again.");
        // remove NSNulls and try again...
         /**
         *  这里进行NSNull写入，因为只能用NSNull来做
         */
        NSArray *records = [response objectForKey:@"results"];
        NSMutableArray *nullFreeRecords = [NSMutableArray array];
        for (NSDictionary *record in records) {
            NSMutableDictionary *nullFreeRecord = [NSMutableDictionary dictionaryWithDictionary:record];
            [record enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if ([obj isKindOfClass:[NSNull class]]) {
                    [nullFreeRecord setValue:nil forKey:key];
                }
            }];
            [nullFreeRecords addObject:nullFreeRecord];
        }
        
        NSDictionary *nullFreeDictionary = [NSDictionary dictionaryWithObject:nullFreeRecords forKey:@"results"];
        
        if (![nullFreeDictionary writeToFile:[fileURL path] atomically:YES]) {
            NSLog(@"Failed all attempts to save reponse to disk: %@", response);
        }
    }
}

/**
 *  在JSON缓存目录中删除JSON数据，这里也只是过度，而不是一直存在磁盘中
 *
 *  @param className 需要删除的类名，例如实体User
 */
- (void)deleteJSONDataRecordsForClassWithName:(NSString *)className {
    NSURL *url = [NSURL URLWithString:className relativeToURL:[self JSONDataRecordsDirectory]];
    NSError *error = nil;
    BOOL deleted = [[NSFileManager defaultManager] removeItemAtURL:url error:&error];
    if (!deleted) {
        NSLog(@"Unable to delete JSON Records at %@, reason: %@", url, error);
    }
}

/**
 *  从JSON缓存数据目录中得到JSON字典数据
 *
 *  @param className 实体名称，例如User
 *
 *  @return 返回一个实体转换为字典的字典，
 */
- (NSDictionary *)JSONDictionaryForClassWithName:(NSString *)className {
    NSURL *fileURL = [NSURL URLWithString:className relativeToURL:[self JSONDataRecordsDirectory]];
    return [NSDictionary dictionaryWithContentsOfURL:fileURL];
}

/**
 *  从JSON缓存目录中得到一个实体的User的所有数据，并且根据某个Key来进行排序
 *
 *  @param className 实体名
 *  @param key       需要排序的Key
 *
 *  @return 返回排好序的数据（数组）
 */
- (NSArray *)JSONDataRecordsForClass:(NSString *)className sortedByKey:(NSString *)key {
    NSDictionary *JSONDictionary = [self JSONDictionaryForClassWithName:className];
    NSArray *records = [JSONDictionary objectForKey:@"results"];
    return [records sortedArrayUsingDescriptors:[NSArray arrayWithObject:
                                                 [NSSortDescriptor sortDescriptorWithKey:key ascending:YES]]];
}

@end
