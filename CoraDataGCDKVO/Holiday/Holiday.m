//
//  Holiday.m
//  CoraDataGCDKVO
//
//  Created by 曾 宪华 on 13-8-27.
//  Copyright (c) 2013年 Jack_team. All rights reserved.
//

#import "Holiday.h"
#import "SyncEngine.h"

@implementation Holiday

@dynamic createdAt;
@dynamic date;
@dynamic details;
@dynamic image;
@dynamic name;
@dynamic objectId;
@dynamic observedBy;
@dynamic syncStatus;
@dynamic updatedAt;
@dynamic wikipediaLink;
@dynamic imageUrl;

- (NSDictionary *)JSONToCreateObjectOnServer {
    NSString *jsonString = nil;
    NSDictionary *date = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"Date", @"__type",
                          [[SyncEngine sharedEngine] dateStringForAPIUsingDate:self.date], @"iso" , nil];
    
    NSDictionary *jsonDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    self.name, @"name",
                                    self.details, @"details",
                                    self.wikipediaLink, @"wikipediaLink",
                                    date, @"date", nil];
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization
                        dataWithJSONObject:jsonDictionary
                        options:NSJSONWritingPrettyPrinted
                        error:&error];
    if (!jsonData) {
        NSLog(@"Error creaing jsonData: %@", error);
    } else {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    return jsonDictionary;
}

@end
