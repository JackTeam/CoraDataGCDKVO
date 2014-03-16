//
//  ApiClientAF.m
//  CoraDataGCDKVO
//
//  Created by 曾 宪华 on 13-8-26.
//  Copyright (c) 2013年 Jack_team. All rights reserved.
//

#import "ApiClient.h"

#import "AFJSONRequestOperation.h"

#define kTimeoutInterval 30.0f

static NSString * const kSDFParseAPIBaseURLString = @"https://api.parse.com/1/";

static NSString * const kSDFParseAPIApplicationId = @"SN5fFq1E2fzCyc0VHOJ0JUfVPZioOFXXP0YpsWqi";
static NSString * const kSDFParseAPIKey = @"zScbgUuRsA2jnty6u3kRhldCWxkmwN6L8tKKaeqg";

@implementation ApiClient

- (void)clearAnyHttp {
    [self clearAuthorizationHeader];
}

+ (ApiClient *)sharedClient {
    static ApiClient *sharedClient;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedClient = [[ApiClient alloc] initWithBaseURL:[NSURL URLWithString:kSDFParseAPIBaseURLString]];
        [sharedClient setParameterEncoding:AFJSONParameterEncoding];
    });
    
    return sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if (self) {
        [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
        [self setParameterEncoding:AFJSONParameterEncoding];
        [self setDefaultHeader:@"X-Parse-Application-Id" value:kSDFParseAPIApplicationId];
        [self setDefaultHeader:@"X-Parse-REST-API-Key" value:kSDFParseAPIKey];
    }
    
    return self;
}

- (NSMutableURLRequest *)GETRequestForClass:(NSString *)className parameters:(NSDictionary *)parameters {
    NSMutableURLRequest *request = nil;
    [request setTimeoutInterval:kTimeoutInterval];
    request = [self requestWithMethod:@"GET" path:[NSString stringWithFormat:@"classes/%@", className] parameters:parameters];
    return request;
}

- (NSMutableURLRequest *)GETRequestForAllRecordsOfClass:(NSString *)className updatedAfterDate:(NSDate *)updatedDate {
    NSMutableURLRequest *request = nil;
    [request setTimeoutInterval:kTimeoutInterval];
    NSDictionary *paramters = nil;
    if (updatedDate) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.'999Z'"];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
        
        NSString *jsonString = [NSString
                                stringWithFormat:@"{\"updatedAt\":{\"$gte\":{\"__type\":\"Date\",\"iso\":\"%@\"}}}",
                                [dateFormatter stringFromDate:updatedDate]];
        
        paramters = [NSDictionary dictionaryWithObject:jsonString forKey:@"where"];
    }
    
    request = [self GETRequestForClass:className parameters:paramters];
    return request;
}

- (NSMutableURLRequest *)PUTRequestForClass:(NSString *)className atObjectId:(NSString *)objectId parameters:(NSDictionary *)parameters {
    NSMutableURLRequest *request = nil;
    [request setTimeoutInterval:kTimeoutInterval];
    request = [self requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"classes/%@/%@", className, objectId] parameters:parameters];
    return request;
}

- (NSMutableURLRequest *)POSTRequestForClass:(NSString *)className parameters:(NSDictionary *)parameters {
    NSMutableURLRequest *request = nil;
    [request setTimeoutInterval:kTimeoutInterval];
    request = [self requestWithMethod:@"POST" path:[NSString stringWithFormat:@"classes/%@", className] parameters:parameters];
    return request;
}

- (NSMutableURLRequest *)DELETERequestForClass:(NSString *)className forObjectWithId:(NSString *)objectId {
    NSMutableURLRequest *request = nil;
    [request setTimeoutInterval:kTimeoutInterval];
    request = [self requestWithMethod:@"DELETE" path:[NSString stringWithFormat:@"classes/%@/%@", className, objectId] parameters:nil];
    return request;
}

@end
