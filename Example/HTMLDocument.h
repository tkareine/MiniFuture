#import <Foundation/Foundation.h>
#import <libxml/HTMLparser.h>

@class HTMLNode;

@interface HTMLDocument : NSObject

+ (instancetype)readDataAsUTF8:(NSData *)data
                         error:(NSError **)err;

+ (instancetype)documentWithHTMLDoc:(htmlDocPtr)htmlDoc;

- (instancetype)initWithHTMLDoc:(htmlDocPtr)htmlDoc;

- (HTMLNode *)rootHTMLNode:(NSError **)err;

@end
