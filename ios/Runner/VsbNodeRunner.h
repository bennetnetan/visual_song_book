#import <Foundation/Foundation.h>

@interface VsbNodeRunner : NSObject
+ (void)startWithProjectPath:(NSString *)projectPath NS_SWIFT_NAME(start(projectPath:));
@end
