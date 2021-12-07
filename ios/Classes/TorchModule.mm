#import "TorchModule.h"
#import <Libtorch/Libtorch.h>

@implementation TorchModule {
    @protected
        torch::jit::script::Module _module;
    @protected
        NSArray *_classes;
}


/// Load the d2go model and get pytorch module in [_module]. Read the classes file and add classes to [_classes].
///
/// @param modelPath The path of the D2Go model loaded by the load of org.pytorch.Module.
/// @param labelPath The path of the file where the class is written.
/// 
- (nullable instancetype)initWithLoadModel:(NSString*)modelPath labelPath:(NSString*)labelPath {
    self = [super init];
    if (self) {
      try {
          _module = torch::jit::load(modelPath.UTF8String);
          _module.eval();
          NSError *error;
          NSString* lines = [NSString stringWithContentsOfFile:labelPath
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


/// Infer using the D2Go model, format the result and return it.
///
/// @param imageBuffer Bytes of the image to be inferred.
/// @param inputWidth width of image when inferring to d2go model.
/// @param inputHeight height of image when inferring to d2go model.
/// @param widthScale the increase / decrease ratio between the image and the original image.
/// @param heightScale the increase / decrease ratio between the image and the original image.
/// @param threshold confidence threshold to exclude from inference results.
///
/// @return Inference result.
///         the format of [outputs] is List of { "rect": { "left": Float, "top": Float, "right": Float, "bottom": Float },
///         "mask": [byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte ...],
///         "keypoints": [[Float, Float], [Float, Float], [Float, Float], [Float, Float], ...],
///         "confidenceInClass": Float, "detectedClass": String }. "mask" and "keypoints" do not exist on some models.
///
- (NSArray<NSDictionary*>*)predictImage:(void*)imageBuffer inputWidth:(int)inputWidth inputHeight:(int)inputHeight widthScale:(double)widthScale heightScale:(double)heightScale threshold:(double)threshold {
    try {
        at::Tensor tensor = torch::from_blob(imageBuffer, {3, inputWidth, inputHeight}, at::kFloat);
        c10::InferenceMode guard;

        std::vector<torch::Tensor> v;
        v.push_back(tensor);

        // inference
        auto outputTuple = _module.forward({at::TensorList(v)}).toTuple();
        
        auto outputDict = outputTuple->elements()[1].toList().get(0).toGenericDict();
        auto boxesTensor = outputDict.at("boxes").toTensor();
        auto scoresTensor = outputDict.at("scores").toTensor();
        auto labelsTensor = outputDict.at("labels").toTensor();
        
        auto hasKeypoints = outputDict.contains("keypoints");
        
    
        // [boxesBuffer] has 4 sets of left, top, right and bottom per instance
        // boxesBuffer = [left1, top1, right1, bottom1, left2, top2, right2, bottom2, left3, top3, ..., bottomN]
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

        // Inferred number of all instances
        NSMutableArray* outputs = [[NSMutableArray alloc] init];
        long num = scoresTensor.numel();
        for (int i = 0; i < num; i++) {
            if (scoresBuffer[i] < threshold)
                continue;
            NSMutableDictionary* output = [[NSMutableDictionary dictionary] init];
            NSMutableDictionary* rect = [[NSMutableDictionary dictionary] init];
            
            // Set rect to a value that matches the original image
            [rect setObject:@(boxesBuffer[4 * i] * widthScale) forKey:@"left"];
            [rect setObject:@(boxesBuffer[4 * i + 1] * heightScale) forKey:@"top"];
            [rect setObject:@(boxesBuffer[4 * i + 2] * widthScale) forKey:@"right"];
            [rect setObject:@(boxesBuffer[4 * i + 3] * heightScale) forKey:@"bottom"];
            
            [output setObject:rect forKey:@"rect"];
            
            if (hasKeypoints) {
                auto keypointsTensor = outputDict.at("keypoints").toTensor();
                float* keypointsBuffer = keypointsTensor.data_ptr<float>();
                int numOfKeypoints = 17;

                NSMutableArray *keypoints = [NSMutableArray array];
                for (int j = i; j < 3 * numOfKeypoints; j++) {
                    [keypoints addObject:[NSNumber numberWithFloat:keypointsBuffer[j]]];
                }
                NSMutableArray *keypointsList = [NSMutableArray array];
                for (int k = 0; k < keypoints.count; k = 3 + k) {
                    float x = [keypoints[k] floatValue] * (float) widthScale;
                    float y = [keypoints[k+1] floatValue] * (float) heightScale;
                    NSArray *keypoint = [[NSArray alloc] initWithObjects:
                                         [NSNumber numberWithFloat:x],
                                         [NSNumber numberWithFloat:y],
                                         nil];
                    [keypointsList addObject:keypoint];
                }
                
                [output setObject:keypointsList forKey:@"keypoints"];
            }
            
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
