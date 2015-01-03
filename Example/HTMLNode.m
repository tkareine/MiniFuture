#import "Errors.h"
#import "HTMLDocument.h"
#import "HTMLNode.h"

@interface HTMLNode ()

@property (nonatomic) xmlNodePtr xmlNode;

// Needed to ensure that reference to `htmlDoc` stays valid as long as this object
@property (nonatomic, strong) HTMLDocument *htmlDoc;

@end

@implementation HTMLNode

+ (instancetype)nodeWithXMLNode:(xmlNodePtr)xmlNode
                    forDocument:(HTMLDocument *)htmlDoc
{

  return [[HTMLNode alloc] initWithXMLNode:xmlNode forDocument:htmlDoc];
}

- (instancetype) initWithXMLNode:(xmlNodePtr)xmlNode
                     forDocument:(HTMLDocument *)htmlDoc
{
  self = [super init];

  if (self) {
    _xmlNode = xmlNode;
    _htmlDoc = htmlDoc;
  }

  return self;
}

- (NSString *)textContents
{
  xmlChar *contents = xmlNodeGetContent(self.xmlNode);

  if (contents) {
    NSString *string = [NSString stringWithUTF8String:(const char *)contents];
    xmlFree(contents);
    return string;
  }

  return nil;
}

- (HTMLNode *)nodeForXPath:(NSString *)query error:(NSError **)err
{
  xmlXPathContextPtr xpathContext = xmlXPathNewContext((xmlDocPtr) self.xmlNode);

  if (!xpathContext) {
    tfe_error(3, @"Could not create new XPath context", err);
    return nil;
  }

  xmlXPathObjectPtr xpathObject = xmlXPathEvalExpression((xmlChar *)[query UTF8String], xpathContext);

  if (!xpathObject) {
    NSString *description = [NSString stringWithFormat:@"Could not eval XPath expression: %@", query];
    xmlXPathFreeContext(xpathContext);
    tfe_error(4, description, err);
    return nil;
  }

  xmlNodeSetPtr nodes = xpathObject->nodesetval;

  HTMLNode *found = nil;

  if (!xmlXPathNodeSetIsEmpty(nodes)) {
    found = [HTMLNode nodeWithXMLNode:nodes->nodeTab[0] forDocument:self.htmlDoc];
  }

  xmlXPathFreeObject(xpathObject);
  xmlXPathFreeContext(xpathContext);

  return found;
}

@end
