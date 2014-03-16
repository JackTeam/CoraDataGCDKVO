//
//  ApiClientAF.h
//  CoraDataGCDKVO
//
//  Created by 曾 宪华 on 13-8-26.
//  Copyright (c) 2013年 Jack_team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFHTTPClient.h"

@interface ApiClient : AFHTTPClient

+ (ApiClient *)sharedClient;

- (void)clearAnyHttp;

- (NSMutableURLRequest *)GETRequestForClass:(NSString *)className parameters:(NSDictionary *)parameters;

- (NSMutableURLRequest *)GETRequestForAllRecordsOfClass:(NSString *)className updatedAfterDate:(NSDate *)updatedDate;

- (NSMutableURLRequest *)PUTRequestForClass:(NSString *)className atObjectId:(NSString *)objectId parameters:(NSDictionary *)parameters;

- (NSMutableURLRequest *)POSTRequestForClass:(NSString *)className parameters:(NSDictionary *)parameters;

- (NSMutableURLRequest *)DELETERequestForClass:(NSString *)className forObjectWithId:(NSString *)objectId;
@end
