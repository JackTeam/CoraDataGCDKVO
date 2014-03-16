//
//  NSManagedObject+JSON.h
//  SignificantDates
//
//  Created by Chris Wagner on 7/8/12.
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (JSON)

- (NSDictionary *)JSONToCreateObjectOnServer;

@end
