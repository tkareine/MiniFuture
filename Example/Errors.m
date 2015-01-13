#import <Foundation/Foundation.h>

void tfe_error(NSInteger errorCode, NSString *description, NSError **err)
{
  if (err) {
    NSDictionary *info = @{NSLocalizedDescriptionKey: description};
    *err = [NSError errorWithDomain:@"org.tkareine.ToyFuture.example"
                               code:errorCode
                           userInfo:info];
  }
}
