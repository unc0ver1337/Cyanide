#ifndef CY_CHAMS_CONTROLLER_H
#define CY_CHAMS_CONTROLLER_H
#import <Foundation/Foundation.h>
// Experimental: call only on the serialized QuickLoader queue with the
// SpringBoard session active. A NO result must be shown to the user.
@interface CYChamsController : NSObject
- (BOOL)setEnabled:(BOOL)enabled;
- (BOOL)setMode:(unsigned)mode enabled:(BOOL)enabled;
- (BOOL)refresh;
- (BOOL)stop;
@end
#endif
