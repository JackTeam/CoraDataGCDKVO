//
//  NSManagedObject+JSON.m
//  SignificantDates
//
//  Created by Chris Wagner on 7/8/12.
//

#import "NSManagedObject+JSON.h"

@implementation NSManagedObject (JSON)

- (NSDictionary *)JSONToCreateObjectOnServer {
    @throw [NSException exceptionWithName:@"JSONStringToCreateObjectOnServer Not Overridden" reason:@"Must override JSONStringToCreateObjectOnServer on NSManagedObject class" userInfo:nil];
    return nil;
}

@end
