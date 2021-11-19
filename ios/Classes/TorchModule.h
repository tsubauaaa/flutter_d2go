#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TorchModule : NSObject

- (nullable instancetype)initWithLoadModel:(NSString*)absModelPath absLabelPath:(NSString*)absLabelPath;
- (instancetype)init NS_UNAVAILABLE;
- (nullable NSArray<NSDictionary*>*)predictImage:(void*)imageBuffer inputWidth:(int)inputWidth inputHeight:(int)inputHeight  widthScale:(double)widthScale heightScale:(double)heightScale threshold:(double)threshold;
@end

NS_ASSUME_NONNULL_END
