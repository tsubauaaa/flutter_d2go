#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TorchModule : NSObject

- (nullable instancetype)initWithFileAtPath:(NSString*)filePath;
- (instancetype)init NS_UNAVAILABLE;
- (nullable NSArray<NSDictionary*>*)predictImage:(void*)imageBuffer inputWidth:(int)inputWidth inputHeight:(int)inputHeight widthScale:(double)widthScale heightScale:(double)heightScale;
@end

NS_ASSUME_NONNULL_END
