#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TorchModule : NSObject

- (nullable instancetype)initWithLoadModel:(NSString*)modelPath labelPath:(NSString*)labelPath;
- (instancetype)init NS_UNAVAILABLE;
- (nullable NSArray<NSDictionary*>*)predictImage:(void*)imageBuffer width:(int)width height:(int)height  inputWidth:(int)inputWidth inputHeight:(int)inputHeight threshold:(double)threshold;
@end

NS_ASSUME_NONNULL_END
