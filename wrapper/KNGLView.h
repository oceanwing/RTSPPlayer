//
//  KNGLView.h
//  OpenGLES2ShaderRanderDemo
//
//  Created by cyh on 12. 11. 26..
//  Copyright (c) 2012년 cyh3813. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface KNGLView : UIView
@property (retain, nonatomic) EAGLContext* context;
- (void)render:(NSDictionary *)frameData;
@end
