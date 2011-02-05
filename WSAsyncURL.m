//
//  WSAsyncURL.m
//  hexcolorpicker
//
//  Created by Jesper on 2010-01-01.
//  This file is available under terms equivalent to the US public domain.
//  For more information, see <http://creativecommons.org/publicdomain/zero/1.0/>.
//

#import "WSAsyncURL.h"

@interface WSAsyncURL ()
- (id)initAsyncWithURL:(NSURL *)url loadDelegate:(id)delegate successSelector:(SEL)successSelector failSelector:(SEL)failSelector;
@end


@implementation WSAsyncURL

static NSMutableSet *wsasyncurlInstances = nil;

- (id)initAsyncWithURL:(NSURL *)aURL loadDelegate:(id)aDelegate successSelector:(SEL)aSuccessSelector failSelector:(SEL)aFailSelector {
	if (!aURL) return nil;
	if (!aDelegate) return nil;
	
	self = [super init];
	if (self) {
		url = [aURL copy];
		delegate = [aDelegate retain];
		successSelector = aSuccessSelector;
		failSelector = aFailSelector;
	}
	
	return self;
}

/* needed to work in both refcount and GC */

+ (void)retainObject:(WSAsyncURL *)obj {
//	NSLog(@"retaining %@ in %@", obj, wsasyncurlInstances);
	[wsasyncurlInstances addObject:obj];
}

- (void)retainOurselves {
	[WSAsyncURL retainObject:self];
}

+ (void)releaseObject:(WSAsyncURL *)obj {
//	NSLog(@"releasing %@ from %@", obj, wsasyncurlInstances);
	[wsasyncurlInstances removeObject:obj];
}

- (void)releaseOurselves {
	[WSAsyncURL releaseObject:self];
}

- (void)startFetching {
	
	[self retainOurselves];
	
	NSURLRequest *updateReq = [NSURLRequest requestWithURL:url
											   cachePolicy:NSURLRequestReloadIgnoringCacheData 
										   timeoutInterval:20];
	connection = [[NSURLConnection connectionWithRequest:updateReq delegate:self] retain];
	if ([connection respondsToSelector:@selector(start)]) {
		[connection performSelector:@selector(start)];
	}
//	NSLog(@"started connection %@ to %@", connection, url);
	if (!connection) {
//		NSLog(@"didn't work, fail");
		[delegate performSelector:failSelector withObject:nil];
		[self releaseOurselves];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	if (chunk) {
		[chunk release];
	}
	chunk = [[NSMutableData alloc] init];
//	NSLog(@"received response");
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[chunk appendData:data];
//	NSLog(@"append %d bytes", [data length]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
//	NSLog(@"finished");
	[delegate performSelector:successSelector withObject:[chunk autorelease]];
	[self releaseOurselves]; // we're spent!
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	if (chunk) {
		[chunk release];
	}
//	NSLog(@"failed");
	[delegate performSelector:failSelector withObject:[[error copy] autorelease]];
	[self releaseOurselves]; // we're spent!
}

- (void)dealloc {
	[connection release];
	[delegate release];
	[url release];
	[super dealloc];
}


+ (void)fetchURL:(NSURL *)url loadDelegate:(id)delegate successSelector:(SEL)successSelector failSelector:(SEL)failSelector {
	if (!wsasyncurlInstances) {
		wsasyncurlInstances = [[NSMutableSet alloc] init];
	}
	
	WSAsyncURL *instance = [[WSAsyncURL alloc] initAsyncWithURL:url loadDelegate:delegate successSelector:successSelector failSelector:failSelector];
	[instance startFetching];
	[instance release];
}
@end
