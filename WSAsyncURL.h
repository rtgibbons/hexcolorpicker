//
//  WSAsyncURL.h
//  hexcolorpicker
//
//  Created by Jesper on 2010-01-01.
//  This file is available under terms equivalent to the US public domain.
//  For more information, see <http://creativecommons.org/publicdomain/zero/1.0/>.
//

#import <Cocoa/Cocoa.h>


@interface WSAsyncURL : NSObject {
	NSMutableData *chunk;
	id delegate;
	SEL successSelector;
	SEL failSelector;
	NSURL *url;
	
	NSURLConnection *connection;
}
+ (void)fetchURL:(NSURL *)url loadDelegate:(id)delegate successSelector:(SEL)successSelector failSelector:(SEL)failSelector;
@end
