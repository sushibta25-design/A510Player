#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
NS_ASSUME_NONNULL_BEGIN
@interface TATrafficLightDetection : NSObject
@property CGRect normalizedRect;
@property NSString *label;
@property float confidence;
@end
@interface TrafficLightDetector : NSObject
@property (nonatomic, readonly) BOOL modelLoaded;
- (instancetype)init;
- (void)detectPixelBuffer:(CVPixelBufferRef)pixelBuffer completion:(void(^)(NSArray<TATrafficLightDetection *> *items))completion;
@end
NS_ASSUME_NONNULL_END
