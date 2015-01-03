#import "Errors.h"
#import "HTMLDocument.h"
#import "HTMLNode.h"

@interface HTMLDocument ()

@property (nonatomic) htmlDocPtr htmlDoc;

@end

@implementation HTMLDocument

+ (instancetype)readDataAsUTF8:(NSData *)data
                         error:(NSError **)err
{
  int htmlParseOptions = HTML_PARSE_RECOVER | HTML_PARSE_NOERROR | HTML_PARSE_NOWARNING;
  htmlDocPtr htmlDoc = htmlReadMemory([data bytes],
                                      (int)[data length],
                                      NULL,
                                      "UTF-8",
                                      htmlParseOptions);
  if (!htmlDoc) {
    tfe_error(1, @"Could not read HTML doc", err);
    return nil;
  }

  return [HTMLDocument documentWithHTMLDoc:htmlDoc];
}

+ (instancetype)documentWithHTMLDoc:(htmlDocPtr)htmlDoc
{
  return [[HTMLDocument alloc] initWithHTMLDoc:htmlDoc];
}

- (instancetype)initWithHTMLDoc:(htmlDocPtr)htmlDoc
{
  self = [super init];
  if (self) {
    _htmlDoc = htmlDoc;
  }
  return self;
}

- (void)dealloc
{
  xmlFreeDoc(_htmlDoc);
}

- (HTMLNode *)rootHTMLNode:(NSError **)err
{
  xmlNodePtr xmlNode = xmlDocGetRootElement(self.htmlDoc);

  if (!xmlNode) {
    tfe_error(2, @"Could not get HTML root element", err);
    return nil;
  }

  return [HTMLNode nodeWithXMLNode:xmlNode forDocument:self];
}

@end
