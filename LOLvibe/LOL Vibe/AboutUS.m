//
//  AboutUS.m
//  LOLvibe
//
//  Created by Paras Navadiya on 7/11/16.
//  Copyright © 2016 Dreamcodesolution. All rights reserved.
//

#import "AboutUS.h"
#import <MessageUI/MessageUI.h>
#import "ServiceConstant.h"
#import "TermsAndCondition.h"

@interface AboutUS ()<MFMailComposeViewControllerDelegate>

@end

@implementation AboutUS

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)AboutUS:(id)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:APP_ITUNES_LINK]]];
}
-(IBAction)btnICON:(id)sender
{
    WebBrowserVc *web = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"WebBrowserVc"];
    
    web.strURL = @"www.lolvibe.com";
    
    [self.navigationController pushViewController:web animated:YES];
}

- (IBAction)btnTutorial:(id)sender
{
}

- (IBAction)btnFB:(id)sender {
    WebBrowserVc *web = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"WebBrowserVc"];
    
    web.strURL = @"http://www.facebook.com/LOLvibeapp/";
    
    [self.navigationController pushViewController:web animated:YES];
}

- (IBAction)btnTwitter:(id)sender {
    WebBrowserVc *web = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"WebBrowserVc"];
    
    web.strURL = @"http://twitter.com/lolvibeapp";
    
    [self.navigationController pushViewController:web animated:YES];
}


- (IBAction)btnInsta:(id)sender {
    WebBrowserVc *web = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"WebBrowserVc"];
    
    web.strURL = @"http://www.instagram.com/lolvibeapp/";
    
    [self.navigationController pushViewController:web animated:YES];
}


- (IBAction)btnFeedback:(id)sender
{
    NSString *emailTitle = @"iOS Feedback";
    
    MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
    mc.mailComposeDelegate = self;
    [mc setSubject:emailTitle];
    
    if([MFMailComposeViewController canSendMail])
    {
        NSArray *toRecipents = [NSArray arrayWithObject:@"info@lolvibe.com"];
        
        MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
        mc.mailComposeDelegate = self;
        [mc setSubject:emailTitle];
        [mc setMessageBody:@"" isHTML:NO];
        [mc setToRecipients:toRecipents];
        
        [self presentViewController:mc animated:YES completion:NULL];
    }
}

- (void) mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}
- (IBAction)btnTerms:(id)sender {
    WebBrowserVc *web = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"WebBrowserVc"];
    
    web.strURL = @"www.lolvibe.com/index.php/en/terms";
    
    [self.navigationController pushViewController:web animated:YES];
}
@end
