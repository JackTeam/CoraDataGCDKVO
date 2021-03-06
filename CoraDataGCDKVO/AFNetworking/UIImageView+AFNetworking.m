// UIImageView+AFNetworking.m
//
// Copyright (c) 2011 Gowalla (http://gowalla.com/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "AFImageCache.h"

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
#import "UIImageView+AFNetworking.h"

@interface ImageCache : NSCache
@property (nonatomic, strong) AFImageCache *afImageCache;
- (UIImage *)cachedImageForRequest:(NSURLRequest *)request;
- (void)cacheImage:(UIImage *)image
        forRequest:(NSURLRequest *)request;
@end

#pragma mark -

static char kAFImageRequestOperationObjectKey;

@interface UIImageView (_AFNetworking)
@property (readwrite, nonatomic, strong, setter = af_setImageRequestOperation:) AFImageRequestOperation *af_imageRequestOperation;
@end

@implementation UIImageView (_AFNetworking)
@dynamic af_imageRequestOperation;
@end

#pragma mark -

@implementation UIImageView (AFNetworking)

- (AFHTTPRequestOperation *)af_imageRequestOperation {
    return (AFHTTPRequestOperation *)objc_getAssociatedObject(self, &kAFImageRequestOperationObjectKey);
}

- (void)af_setImageRequestOperation:(AFImageRequestOperation *)imageRequestOperation {
    objc_setAssociatedObject(self, &kAFImageRequestOperationObjectKey, imageRequestOperation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (NSOperationQueue *)af_sharedImageRequestOperationQueue {
    static NSOperationQueue *_af_imageRequestOperationQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _af_imageRequestOperationQueue = [[NSOperationQueue alloc] init];
        [_af_imageRequestOperationQueue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
    });

    return _af_imageRequestOperationQueue;
}

+ (ImageCache *)af_sharedImageCache {
    static ImageCache *_af_imageCache = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _af_imageCache = [[ImageCache alloc] init];
    });

    return _af_imageCache;
}

#pragma mark -

- (void)setImageWithURL:(NSURL *)url {
    [self setImageWithURL:url placeholderImage:nil];
}

- (void)setImageWithURL:(NSURL *)url
       placeholderImage:(UIImage *)placeholderImage
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    [request setCachePolicy:NSURLRequestReturnCacheDataElseLoad];

    [self setImageWithURLRequest:request placeholderImage:placeholderImage success:nil failure:nil];
}

- (void)setImageWithURLRequest:(NSURLRequest *)urlRequest
              placeholderImage:(UIImage *)placeholderImage
                       success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
{
    [self cancelImageRequestOperation];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *cachedImage = [[[self class] af_sharedImageCache] cachedImageForRequest:urlRequest];
        if (cachedImage) {
            self.af_imageRequestOperation = nil;
            
            if (success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    success(nil, nil, cachedImage);
                });
                
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.image = cachedImage;
                });
                
            }
        } else {
            if (placeholderImage) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.image = placeholderImage;
                });
            }
            
            AFImageRequestOperation *requestOperation = [[AFImageRequestOperation alloc] initWithRequest:urlRequest];
            [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
                if ([urlRequest isEqual:[self.af_imageRequestOperation request]]) {
                    if (self.af_imageRequestOperation == operation) {
                        self.af_imageRequestOperation = nil;
                    }
                    
                    if (success) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            success(operation.request, operation.response, responseObject);
                        });
                        
                    } else if (responseObject) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self.image = responseObject;
                        });
                        
                    }
                }
                
                [[[self class] af_sharedImageCache] cacheImage:responseObject forRequest:urlRequest];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if ([urlRequest isEqual:[self.af_imageRequestOperation request]]) {
                    if (self.af_imageRequestOperation == operation) {
                        self.af_imageRequestOperation = nil;
                    }
                    
                    if (failure) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            failure(operation.request, operation.response, error);
                        });
                        
                    }
                }
            }];
            
            self.af_imageRequestOperation = requestOperation;
            
            [[[self class] af_sharedImageRequestOperationQueue] addOperation:self.af_imageRequestOperation];
        }
    });
    
}

- (void)cancelImageRequestOperation {
    [self.af_imageRequestOperation cancel];
    self.af_imageRequestOperation = nil;
}

@end

#pragma mark -

static inline NSString * AFImageCacheKeyFromURLRequest(NSURLRequest *request) {
    return [[request URL] absoluteString];
}

@implementation ImageCache

- (id)init {
    self = [super init];
    if (self) {
        self.afImageCache = [self createCache];
    }
    return self;
}

- (AFImageCache *)createCache
{
    return [AFImageCache sharedImageCache];
}

- (UIImage *)cachedImageForRequest:(NSURLRequest *)request {
    NSInteger cachePolicy = [request cachePolicy];
    switch (cachePolicy) {
        case NSURLRequestReloadIgnoringCacheData:
        case NSURLRequestReloadIgnoringLocalAndRemoteCacheData:
            return nil;
        case NSURLRequestReturnCacheDataElseLoad: {
            
        }
        default:
            break;
    }
    __block UIImage *cacheImage = nil;
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    dispatch_group_async(group, queue, ^{
        cacheImage = [self.afImageCache imageFromMemoryCacheForKey:AFImageCacheKeyFromURLRequest(request)];
        if (!cacheImage) {
            cacheImage = [self.afImageCache imageFromDiskCacheForKey:AFImageCacheKeyFromURLRequest(request)];
        }
        dispatch_semaphore_signal(semaphore);
    });
    
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    dispatch_release(group);
    dispatch_release(semaphore);
    
    return cacheImage;
}

- (void)cacheImage:(UIImage *)image
        forRequest:(NSURLRequest *)request
{
    if (image && request) {
        if ([request cachePolicy] == NSURLRequestReturnCacheDataElseLoad) {
            [self.afImageCache storeImage:image forKey:AFImageCacheKeyFromURLRequest(request)];
        }
    }
}

@end

#endif
