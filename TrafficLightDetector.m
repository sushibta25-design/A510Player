#import "TrafficLightDetector.h"
#import <Vision/Vision.h>
#import <CoreML/CoreML.h>
@implementation TATrafficLightDetection @end
@interface TrafficLightDetector ()
@property VNCoreMLRequest *request;
@property dispatch_queue_t queue;
@property BOOL busy;
@end
@implementation TrafficLightDetector
- (instancetype)init { if((self=[super init])) { _queue=dispatch_queue_create("tasmart.traffic.ai",DISPATCH_QUEUE_SERIAL); NSURL *u=[[NSBundle mainBundle] URLForResource:@"TrafficLightDetector" withExtension:@"mlmodelc"]; if(u){ NSError *e=nil; MLModel *m=[MLModel modelWithContentsOfURL:u error:&e]; if(m){ VNCoreMLModel *vm=[VNCoreMLModel modelForMLModel:m error:&e]; if(vm){ _request=[[VNCoreMLRequest alloc] initWithModel:vm]; _request.imageCropAndScaleOption=VNImageCropAndScaleOptionScaleFill; } } if(e) NSLog(@"[TAsmartAI] model error=%@",e); } else NSLog(@"[TAsmartAI] TrafficLightDetector.mlmodelc not bundled"); } return self; }
- (BOOL)modelLoaded { return self.request != nil; }
- (void)detectPixelBuffer:(CVPixelBufferRef)p completion:(void(^)(NSArray *))completion { if(!p||!self.request||self.busy){ if(completion)completion(@[]); return; } self.busy=YES; CFRetain(p); dispatch_async(self.queue, ^{ NSError *e=nil; VNImageRequestHandler *h=[[VNImageRequestHandler alloc] initWithCVPixelBuffer:p orientation:kCGImagePropertyOrientationUp options:@{}]; [h performRequests:@[self.request] error:&e]; NSMutableArray *out=[NSMutableArray array]; for(VNRecognizedObjectObservation *o in self.request.results){ if(![o isKindOfClass:VNRecognizedObjectObservation.class]||!o.labels.count)continue; VNClassificationObservation *c=o.labels.firstObject; NSString *s=c.identifier.lowercaseString; if(!([s containsString:@"red"]||[s containsString:@"yellow"]||[s containsString:@"green"]||[s containsString:@"traffic"]))continue; TATrafficLightDetection *d=[TATrafficLightDetection new]; d.normalizedRect=o.boundingBox; d.label=s; d.confidence=c.confidence; [out addObject:d]; } CFRelease(p); self.busy=NO; dispatch_async(dispatch_get_main_queue(), ^{ if(completion)completion(out); }); }); }
@end
