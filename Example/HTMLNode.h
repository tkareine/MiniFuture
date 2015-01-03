#import <Foundation/Foundation.h>
#import <libxml/HTMLparser.h>
#import <libxml/xpath.h>

@class HTMLDocument;

@interface HTMLNode: NSObject

@property (readonly) NSString *textContents;

+ (instancetype)nodeWithXMLNode:(xmlNodePtr)xmlNode
                    forDocument:(HTMLDocument *)htmlDoc;

- (instancetype)initWithXMLNode:(xmlNodePtr)xmlNode
                    forDocument:(HTMLDocument *)htmlDoc;

- (instancetype)nodeForXPath:(NSString *)query error:(NSError **)err;

@end
