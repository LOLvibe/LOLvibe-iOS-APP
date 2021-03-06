//
//  OptionClass.m
//  LOLvibe
//
//  Created by Jaydip Godhani on 26/06/16.
//  Copyright © 2016 Dreamcodesolution. All rights reserved.
//

#import "OptionClass.h"
#import "ServiceConstant.h"

@implementation OptionClass
@synthesize delegate;

-(id)initWithView:(id)myView andDelegate:(id <OptionClassDelegate>)del
{
    self = [super init];
    
    if(self)
    {
        view_Process = myView;
        self.delegate = del;
    }
    return self;
}


#pragma mark Other User Opetoin
-(void)otherUserPostOptionClass:(NSDictionary *)dictPostDetail Image:(UIImage *)image;
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *repost = [UIAlertAction actionWithTitle:@"Repost It!" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self repostThisPost:dictPostDetail];
    }];

    UIAlertAction *facebook = [UIAlertAction actionWithTitle:@"Share to Facebook"
                                                       style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                           [self shareInFacebook:dictPostDetail];
                                                       }];
    
    UIAlertAction *twitter = [UIAlertAction actionWithTitle:@"Tweet" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self twitterShare:dictPostDetail Image:image];
    }];
    
    UIAlertAction *instagram = [UIAlertAction actionWithTitle:@"Share to Instagram" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self instaGramWallPost:dictPostDetail Image:image];
    }];
    
    UIAlertAction *report = [UIAlertAction actionWithTitle:@"REPORT!" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self reportThisPost:dictPostDetail];
    }];

    UIAlertAction *block = [UIAlertAction actionWithTitle:@"BLOCK USER!" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self blockThisUser:dictPostDetail];
    }];

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    
    [alert addAction:report];
    [alert addAction:block];
    [alert addAction:repost];
    [alert addAction:facebook];
    [alert addAction:twitter];
    [alert addAction:instagram];
    [alert addAction:cancel];
    
    [view_Process presentViewController:alert animated:YES completion:nil];
}

#pragma mark --Selt Opetion
-(void)selfUserPostOptionClass:(NSDictionary *)dictPostDetail Image:(UIImage *)image;
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    
    
    UIAlertAction *facebook = [UIAlertAction actionWithTitle:@"Share to Facebook"
                                                       style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                           [self shareInFacebook:dictPostDetail];
                                                       }];
    
    UIAlertAction *twitter = [UIAlertAction actionWithTitle:@"Tweet" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self twitterShare:dictPostDetail Image:image];
    }];
    
    UIAlertAction *instagram = [UIAlertAction actionWithTitle:@"Share to Instagram" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self instaGramWallPost:dictPostDetail Image:image];
    }];
    
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    
    [alert addAction:facebook];
    [alert addAction:twitter];
    [alert addAction:instagram];
    [alert addAction:cancel];
    [view_Process presentViewController:alert animated:YES completion:nil];
}


#pragma mark --Selt Opetion
-(void)UserProfileSharingOption:(NSDictionary *)dictPostDetail Image:(UIImage *)image;
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    
    
    UIAlertAction *facebook = [UIAlertAction actionWithTitle:@"Share to Facebook"
                                                       style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                           [self shareInFacebook:dictPostDetail];
                                                       }];
    
    UIAlertAction *twitter = [UIAlertAction actionWithTitle:@"Tweet" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self twitterShare:dictPostDetail Image:image];
    }];
    
    UIAlertAction *instagram = [UIAlertAction actionWithTitle:@"Share to Instagram" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self instaGramWallPost:dictPostDetail Image:image];
    }];
    
    UIAlertAction *report = [UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action)
                             {
                                 [self deleteThisPost:dictPostDetail];
                             }];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    
    
    [alert addAction:facebook];
    [alert addAction:twitter];
    [alert addAction:instagram];
    [alert addAction:report];
    [alert addAction:cancel];
    
    [view_Process presentViewController:alert animated:YES completion:nil];
}

-(void)deleteThisPost:(NSDictionary *)dict
{
    [self.delegate callDeleteMethod:dict];
}
-(void)repostThisPost:(NSDictionary *)dict
{
    [self.delegate callRepostMethod:dict];
}
-(void)reportThisPost:(NSDictionary *)dict
{
    [self.delegate callReportMethod:dict];
}
-(void)blockThisUser:(NSDictionary *)dict
{
    [self.delegate callBlockUserMethod:dict];
}
#pragma marm --Insta Share
-(void)instaGramWallPost:(NSDictionary *)dictValue Image:(UIImage *)image
{
    [self.delegate callInstagramMethod:dictValue Image:image];
}

#pragma marm --Twitter Share
-(void)twitterShare:(NSDictionary *)dictValue Image:(UIImage *)image
{
    const char *jsonString = [[dictValue valueForKey:@"feed_text"] UTF8String];
    NSData *jsonData = [NSData dataWithBytes:jsonString length:strlen(jsonString)];
    NSString *goodMsg = [[NSString alloc] initWithData:jsonData encoding:NSNonLossyASCIIStringEncoding];
    
    if([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter])
    {
        SLComposeViewController *controller = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
        
        [controller setInitialText:[NSString stringWithFormat:@"%@\n\n#LOLvibe",goodMsg]];
        [controller addImage:image];
        [controller addURL:[NSURL URLWithString:APP_ITUNES_LINK]];
        
        [view_Process presentViewController:controller animated:YES completion:Nil];
    }
}

#pragma mark - FBSDKSharingDelegate
-(void)shareInFacebook:(NSDictionary *)dictPostDetail
{
    const char *jsonString = [[dictPostDetail valueForKey:@"feed_text"] UTF8String];
    NSData *jsonData = [NSData dataWithBytes:jsonString length:strlen(jsonString)];
    NSString *goodMsg = [[NSString alloc] initWithData:jsonData encoding:NSNonLossyASCIIStringEncoding];
    
    
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"fb://"]])
    {
        FBSDKShareLinkContent *content = [FBSDKShareLinkContent new];
        content.contentURL = [NSURL URLWithString:APP_ITUNES_LINK];
        content.contentTitle = [NSString stringWithFormat:@"%@",goodMsg];
        content.contentDescription = App_Name;
        content.quote = [NSString stringWithFormat:@"%@",goodMsg];
        content.imageURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@",[dictPostDetail valueForKey:@"image"]]];
        FBSDKShareDialog *shareDialog = [FBSDKShareDialog new];
        [shareDialog setMode:FBSDKShareDialogModeNative];
        [shareDialog setShareContent:content];
        [shareDialog setDelegate:self];
        [shareDialog setFromViewController:view_Process];
        [shareDialog show];
    }
    else
    {
        FBSDKShareLinkContent *content = [FBSDKShareLinkContent new];
        content.contentURL = [NSURL URLWithString:APP_ITUNES_LINK];
        content.contentTitle = [NSString stringWithFormat:@"%@",goodMsg];
        content.contentDescription = App_Name;
        content.quote = [NSString stringWithFormat:@"%@",goodMsg];
        content.imageURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@",[dictPostDetail valueForKey:@"image"]]];
        FBSDKShareDialog *shareDialog = [FBSDKShareDialog new];
        [shareDialog setMode:FBSDKShareDialogModeFeedWeb];
        [shareDialog setShareContent:content];
        [shareDialog setDelegate:self];
        [shareDialog setFromViewController:view_Process];
        [shareDialog show];
    }
}
- (void)sharer:(id<FBSDKSharing>)sharer didCompleteWithResults :(NSDictionary *)results
{
    [view_Process dismissViewControllerAnimated:YES completion:nil];
    [GlobalMethods displayAlertWithTitle:App_Name andMessage:@"Your post successfully post on your wall."];
    //NSLog(@"FB: SHARE RESULTS=%@\n",[results debugDescription]);
}

- (void)sharer:(id<FBSDKSharing>)sharer didFailWithError:(NSError *)error
{
    [view_Process dismissViewControllerAnimated:YES completion:nil];
    [GlobalMethods displayAlertWithTitle:App_Name andMessage:@"Something wrong."];
    //NSLog(@"FB: ERROR=%@\n",[error debugDescription]);
}

- (void)sharerDidCancel:(id<FBSDKSharing>)sharer
{
    [view_Process dismissViewControllerAnimated:YES completion:nil];
    
//    NSLog(@"FB: CANCELED SHARER=%@\n",[sharer debugDescription]);
}
@end
