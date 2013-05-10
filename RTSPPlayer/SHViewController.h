//
//  SHViewController.h
//  RTSPPlayer
//
//  Created by ken on 13. 5. 7..
//  Copyright (c) 2013년 SH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SHViewController : UIViewController <UITextFieldDelegate>

@property (retain, nonatomic) IBOutlet UITextField* tfURL;
@property (retain, nonatomic) IBOutlet UIView* viewRender;
@property (retain, nonatomic) IBOutlet UIButton* btnPlay;

- (IBAction)playStop:(id)sender;

@end
