#import "TorchModule.h"
#import <Libtorch/Libtorch.h>

@implementation TorchModule {
    @protected
        torch::jit::script::Module _module;
    @protected
        NSArray *_classes;
}

- (nullable instancetype)initWithLoadModel:(NSString*)absModelPath absLabelPath:(NSString*)absLabelPath {
    self = [super init];
    if (self) {
      try {
          _module = torch::jit::load(absModelPath.UTF8String);
          _module.eval();
          NSError *error;
          NSString* lines = [NSString stringWithContentsOfFile:absLabelPath
                                                        encoding:NSUTF8StringEncoding
                                                           error:&error];
          if (error) {
              NSLog(@"Error reading file: %@", error.localizedDescription);
          }
//          NSLog(@"lines: %@", lines);
          _classes = [lines componentsSeparatedByString:@"\n"];
      } catch (const std::exception& e) {
          NSLog(@"%s", e.what());
          return nil;
      }
    }
    return self;
}

- (NSArray<NSDictionary*>*)predictImage:(void*)imageBuffer inputWidth:(int)inputWidth inputHeight:(int)inputHeight widthScale:(double)widthScale heightScale:(double)heightScale threshold:(double)threshold {
    try {
        at::Tensor tensor = torch::from_blob(imageBuffer, {3, inputWidth, inputHeight}, at::kFloat);
        c10::InferenceMode guard;

        std::vector<torch::Tensor> v;
        v.push_back(tensor);

        auto outputTuple = _module.forward({at::TensorList(v)}).toTuple();
        auto outputDict = outputTuple->elements()[1].toList().get(0).toGenericDict();
        auto boxesTensor = outputDict.at("boxes").toTensor();
        auto scoresTensor = outputDict.at("scores").toTensor();
        auto labelsTensor = outputDict.at("labels").toTensor();
    
        float* boxesBuffer = boxesTensor.data_ptr<float>();
        if (!boxesBuffer) {
            return nil;
        }
        float* scoresBuffer = scoresTensor.data_ptr<float>();
        if (!scoresBuffer) {
            return nil;
        }
        int64_t* labelsBuffer = labelsTensor.data_ptr<int64_t>();
        if (!labelsBuffer) {
            return nil;
        }

        NSMutableArray* outputs = [[NSMutableArray alloc] init];
        long num = scoresTensor.numel();
        for (int i = 0; i < num; i++) {
            if (scoresBuffer[i] < threshold)
                continue;
            NSMutableDictionary* output = [[NSMutableDictionary dictionary] init];
            NSMutableDictionary* rect = [[NSMutableDictionary dictionary] init];
            
            [rect setObject:@(boxesBuffer[4 * i] * widthScale) forKey:@"left"];
            [rect setObject:@(boxesBuffer[4 * i + 1] * heightScale) forKey:@"top"];
            [rect setObject:@(boxesBuffer[4 * i + 2] * widthScale) forKey:@"right"];
            [rect setObject:@(boxesBuffer[4 * i + 3] * heightScale) forKey:@"bottom"];
            
            [output setObject:rect forKey:@"rect"];
            
            [output setObject:@(scoresBuffer[i]) forKey:@"confidenceInClass"];
            [output setObject:[_classes objectAtIndex:labelsBuffer[i] - 1] forKey:@"detectedClass"];
        
            [outputs addObject:output];
        }

        return [outputs copy];
        
    } catch (const std::exception& e) {
        NSLog(@"%s", e.what());
    }
    return nil;
}

@end
