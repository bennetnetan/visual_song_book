#import "VsbNodeRunner.h"
#import <NodeMobile/NodeMobile.h>
#include <string>
#include <vector>

@implementation VsbNodeRunner

+ (void)startWithProjectPath:(NSString *)projectPath {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSData *json = [NSJSONSerialization dataWithJSONObject:@[projectPath] options:NSJSONWritingFragmentsAllowed error:nil];
    NSString *jsonPath = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    NSString *bootstrap = [NSString stringWithFormat:
      @"const path=require('path');const {pathToFileURL}=require('url');const root=%@[0];process.chdir(root);import(pathToFileURL(path.join(root,'mobile_server.mjs')).href).catch(e=>{console.error(e);});",
      jsonPath];
    NSThread *thread = [[NSThread alloc] initWithBlock:^{
      std::vector<std::string> arguments = {"node", "-e", std::string([bootstrap UTF8String])};
      std::vector<char *> argv;
      for (std::string &argument : arguments) argv.push_back(&argument[0]);
      argv.push_back(nullptr);
      node_start((int)arguments.size(), argv.data());
    }];
    thread.stackSize = 2 * 1024 * 1024;
    [thread start];
  });
}

@end
