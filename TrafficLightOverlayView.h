#import <UIKit/UIKit.h>
#import "TrafficLightDetector.h"
@interface TrafficLightOverlayView : UIView
- (void)showDetections:(NSArray<TATrafficLightDetection *> *)items;
@end
