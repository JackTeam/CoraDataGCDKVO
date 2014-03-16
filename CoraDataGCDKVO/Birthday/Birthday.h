//
//  Birthday.h
//  CoraDataGCDKVO
//
//  Created by 曾 宪华 on 13-8-27.
//  Copyright (c) 2013年 Jack_team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Birthday : NSManagedObject

@property (nonatomic, retain) NSDate * createdAt;
@property (nonatomic, retain) NSDate * date;
@property (nonatomic, retain) NSString * details;
@property (nonatomic, retain) NSString * facebook;
@property (nonatomic, retain) NSString * giftIdeas;
@property (nonatomic, retain) NSData * image;
@property (nonatomic, retain) NSString * imageUrl;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * objectId;
@property (nonatomic, retain) id observedBy;
@property (nonatomic, retain) NSNumber * syncStatus;
@property (nonatomic, retain) NSDate * updatedAt;
@property (nonatomic, retain) NSString * wikipediaLink;
@property (nonatomic, retain) NSString * jack;

@end
