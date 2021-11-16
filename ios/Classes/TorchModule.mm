#import "TorchModule.h"
#import <Libtorch/Libtorch.h>

@implementation TorchModule {
 @protected
  torch::jit::script::Module _module;
}

- (nullable instancetype)initWithFileAtPath:(NSString*)filePath {
    self = [super init];
    if (self) {
      try {
          _module = torch::jit::load(filePath.UTF8String);
          _module.eval();
      } catch (const std::exception& e) {
          NSLog(@"%s", e.what());
          return nil;
      }
    }
    return self;
}

@end
