//
//  GroupChatController.m
//  LOLvibe
//
//  Created by Jaydip Godhani on 08/06/16.
//  Copyright © 2016 Dreamcodesolution. All rights reserved.
//

#import "GroupChatController.h"
#import "SenderChatMsgCell.h"
#import "ReceiverChatMsgCell.h"
#import "ServiceConstant.h"
#import "ReceiverGroupChatCell.h"
#import "GroupInfoController.h"

@interface GroupChatController ()<ChatDelegate,NSFetchedResultsControllerDelegate,WebServiceDelegate>
{
    NSFetchedResultsController *fetchedResultsController;
    CGFloat maxChatTextWidth;
    NSMutableDictionary *chatScreenCells;
    BOOL checkForRoomJoined;
    BOOL isMemberListFetched;
    BOOL isModeratorListFetched;
    NSMutableArray *roomMemberArray;
    BOOL isLoggedUserModerator;
    NSTimer *checkingTimer;
    
}

@end

@implementation GroupChatController
@synthesize dictUser;

- (void)viewDidLoad
{
    [super viewDidLoad];
    roomMemberArray = [[NSMutableArray alloc] init];
    
    maxChatTextWidth = self.view.bounds.size.width - 30.0;
    
    chatScreenCells = [NSMutableDictionary dictionary];
    
    chatTextView.text = [NSLocalizedString(@"Type Message", nil) uppercaseString];
    chatTableView.userInteractionEnabled = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    [chatTableView registerNib:[UINib nibWithNibName:@"ChatSectionHeaderCell" bundle:nil] forCellReuseIdentifier:@"ChatSectionHeaderCell"];
    [chatTableView registerNib:[UINib nibWithNibName:@"SenderChatMsgCell" bundle:nil] forCellReuseIdentifier:@"SenderChatMsgCell"];
    [chatTableView registerNib:[UINib nibWithNibName:@"ReceiverGroupChatCell" bundle:nil] forCellReuseIdentifier:@"ReceiverChatMsgCell"];
    
    [self setDefualtProperties];
    
    [[[XmppHelper sharedInstance] xmppStream] addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    [self makeReadStatusForAllUnreadMessage];
    [XmppHelper sharedInstance].delegate = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(roomMemberListFetchedNotification:) name:XMPP_ROOM_MEMBER_LIST_FETCHED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(roomModeratorListFetchedNotification:) name:XMPP_ROOM_MODERATOR_LIST_FETCHED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(roomMemberListNotFetchedNotification:) name:XMPP_ROOM_MEMBER_LIST_NOT_FETCHED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(roomModeratorListNotFetchedNotification:) name:XMPP_ROOM_MODERATOR_LIST_NOT_FETCHED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(roomPrivilegesEditedNotification:) name:XMPP_ROOM_PRIVILEGES_EDITED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(roomPrivilegesNotEditedNotification:) name:XMPP_ROOM_PRIVILEGES_NOT_EDITED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userRemovedFromGroupNotification:) name:XMPP_USER_REMOVED_FROM_ROOM_NOTIFICATION object:nil];
    
    checkForRoomJoined = YES;
    [self joinCurrentRoomIfNeeded];
    
    if(_currentRoom!=nil)
    {
        [_currentRoom fetchMembersList];
        
        ////Change [item addAttributeWithName:@"role" stringValue:@"moderator"]; with [item addAttributeWithName:@"affiliation" stringValue:@"owner"]; in this method
        [_currentRoom fetchModeratorsList];
    }
    
    CGPoint offset = CGPointMake(0, CGFLOAT_MAX);
    [chatTableView setContentOffset:offset animated:YES];

    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onBackgroundTap:)];
    tapGesture.numberOfTapsRequired = 1;
    tapGesture.cancelsTouchesInView = YES;
    [self.view addGestureRecognizer:tapGesture];
}
- (void)onBackgroundTap:(id)sender
{
    [self.view endEditing:YES];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if(![[XmppHelper sharedInstance].xmppStream isAuthenticated])
    {
        if(![[XmppHelper sharedInstance].xmppStream isConnecting] && ![[XmppHelper sharedInstance].xmppStream isConnected])
        {
            [[XmppHelper sharedInstance] connect];
        }
    }
    else if(!(isMemberListFetched && isModeratorListFetched))
    {
        
    }
    
    [chatTableView  reloadData];
    
}

-(void)setDefualtProperties
{
    chatTextView.layer.cornerRadius = 3.0;
    chatTextView.layer.masksToBounds = YES;
    
    chatTextView.layer.borderColor = [UIColor colorWithRed:230.0/255.0 green:230.0/255.0 blue:230.0/255.0 alpha:1.0].CGColor;
    chatTextView.layer.borderWidth = 1.0;
    
    sendBtn.layer.cornerRadius = 3.0;
    sendBtn.layer.masksToBounds = YES;
    
    self.navigationItem.title = [NSString stringWithFormat:@"%@",[dictUser valueForKey:@"name"]];
    
    profile_pic.layer.cornerRadius = profile_pic.frame.size.height/2;
    profile_pic.layer.masksToBounds = YES;
    
    UIImageView *imgProfile = [[UIImageView alloc] init];
    [imgProfile sd_setImageWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@",[dictUser valueForKey:@"profile_pic"]]] placeholderImage:[UIImage imageNamed:@""] completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        [profile_pic setBackgroundImage:image forState:UIControlStateNormal];
    }];
}

#pragma mark ---Make Read Status---
-(void)makeReadStatusForAllUnreadMessage
{
    NSManagedObjectContext *context = [XmppHelper sharedInstance].managedObjectContext_chatMessage;
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"ChatConversation"  inManagedObjectContext:context];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"senderId == %@ AND receiverId == %@ AND isGroupMessage == 0 AND isNew == 1", [XmppHelper sharedInstance].username, [dictUser valueForKey:@"group_id"]];
    
    NSFetchRequest *fetch = [[NSFetchRequest alloc] init];
    [fetch setEntity:entityDescription];
    [fetch setPredicate:predicate];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"messageDateTime" ascending:NO];
    [fetch setSortDescriptors:@[sortDescriptor]];
    
    NSArray *unreadMsgArray = [context executeFetchRequest:fetch error:nil];
    
    for(ChatConversation *chatObj in unreadMsgArray)
    {
        chatObj.isNew = @(NO);
        [[XmppHelper sharedInstance].managedObjectContext_chatMessage save:nil];
    }
}
-(void)xmppRoomJoinedNotification:(NSNotification *)notification
{
    XMPPRoom *room = (XMPPRoom *)notification.object;
    
    if([room.roomJID.user isEqualToString:[dictUser valueForKey:@"group_id"]])
    {
        self.currentRoom = room;
        
        if(!isMemberListFetched || !isModeratorListFetched)
        {
            if(_currentRoom!=nil)
            {
                [_currentRoom fetchMembersList];
                
                ////Change [item addAttributeWithName:@"role" stringValue:@"moderator"]; with [item addAttributeWithName:@"affiliation" stringValue:@"owner"]; in this method
                [_currentRoom fetchModeratorsList];
            }
        }
    }
}


-(void)xmppDisCoonectedNotification:(NSNotification *)notification
{
    sendBtn.enabled = NO;
}

-(void)xmppAuthenticatedNotification:(NSNotification *)notification
{
    sendBtn.enabled = YES;
    
    if(isMemberListFetched && isModeratorListFetched)
    {
        if(_currentRoom!=nil)
        {
            [_currentRoom fetchMembersList];
            
            ////Change [item addAttributeWithName:@"role" stringValue:@"moderator"]; with [item addAttributeWithName:@"affiliation" stringValue:@"owner"]; in this method
            [_currentRoom fetchModeratorsList];
        }
    }
    
    self.currentRoom = nil;
    checkForRoomJoined = YES;
    [self joinCurrentRoomIfNeeded];
}

-(void)xmppUnauthenticatedNotification:(NSNotification *)notification
{
    sendBtn.enabled = NO;
}
-(void)roomMemberListFetchedNotification:(NSNotification *)notification
{
    XMPPRoom *room = notification.object;
    NSArray *memberListAr = notification.userInfo[@"list"];
    
    DLog(@"Room ID :- %@", room.myRoomJID.bare);
    DLog(@"Member list :- %@", memberListAr);
    
    if([[room.myRoomJID.user lowercaseString] isEqualToString:[[dictUser valueForKey:@"group_id"] lowercaseString]] && !isMemberListFetched)
    {
        isMemberListFetched = YES;
        
        for (NSXMLElement *roomElement in memberListAr)
        {
            NSString *jidString = [roomElement attributeStringValueForName:@"jid"];
            XMPPJID *jid = [XMPPJID jidWithString:jidString];
            
            NSDictionary *tempDict = [[XmppHelper sharedInstance] fetchUserInfoDictionaryForID:jid.user];
            if(tempDict!=nil)
            {
                NSMutableDictionary *memberDict = [[NSMutableDictionary alloc] initWithDictionary:tempDict];
                [memberDict setObject:@(NO) forKey:@"isGroupModerator"];
                [memberDict setObject:@(YES) forKey:@"isUserInfoAvailable"];
                [roomMemberArray addObject:memberDict];
                memberDict = nil;
            }
            else if([[jid.user lowercaseString] isEqualToString:[[XmppHelper sharedInstance].username lowercaseString]])
            {
                NSMutableDictionary *memberDict = [[NSMutableDictionary alloc] init];
                [memberDict setObject:[[XmppHelper sharedInstance].username lowercaseString] forKey:@"phone_number"];
                [memberDict setObject:@(NO) forKey:@"isGroupModerator"];
                [memberDict setObject:@(YES) forKey:@"isUserInfoAvailable"];
                [roomMemberArray addObject:memberDict];
                memberDict = nil;
            }
            else
            {
                NSMutableDictionary *memberDict = [[NSMutableDictionary alloc] init];
                [memberDict setObject:jid.user forKey:@"phone_number"];
                [memberDict setObject:@(NO) forKey:@"isGroupModerator"];
                [memberDict setObject:@(NO) forKey:@"isUserInfoAvailable"];
                [roomMemberArray addObject:memberDict];
                memberDict = nil;
            }
            tempDict = nil;
        }
        
        if(isMemberListFetched && isModeratorListFetched)
        {
            //[self displayDefaultNavigationTitle];
            
            [self sortRoomMemberArray];
        }
    }
}

-(void)roomModeratorListFetchedNotification:(NSNotification *)notification
{
    XMPPRoom *room = notification.object;
    NSArray *ModeratorListAr = notification.userInfo[@"list"];
    
    DLog(@"Room ID :- %@", room.myRoomJID.bare);
    DLog(@"Moderator list :- %@", ModeratorListAr);
    
    if([[room.myRoomJID.user lowercaseString] isEqualToString:[[dictUser valueForKey:@"group_id"] lowercaseString]] && !isModeratorListFetched)
    {
        isModeratorListFetched = YES;
        
        for (NSXMLElement *roomElement in ModeratorListAr)
        {
            NSString *jidString = [roomElement attributeStringValueForName:@"jid"];
            XMPPJID *jid = [XMPPJID jidWithString:jidString];
            
            NSDictionary *tempDict = [[XmppHelper sharedInstance] fetchUserInfoDictionaryForID:jid.user];
            if(tempDict!=nil)
            {
                NSMutableDictionary *memberDict = [[NSMutableDictionary alloc] initWithDictionary:tempDict];
                [memberDict setObject:@(YES) forKey:@"isGroupModerator"];
                [memberDict setObject:@(YES) forKey:@"isUserInfoAvailable"];
                [roomMemberArray addObject:memberDict];
                
                memberDict = nil;
            }
            else if([[jid.user lowercaseString] isEqualToString:[[XmppHelper sharedInstance].username lowercaseString]])
            {
                isLoggedUserModerator = YES;
                
                NSMutableDictionary *memberDict = [[NSMutableDictionary alloc] init];
                [memberDict setObject:[[XmppHelper sharedInstance].username lowercaseString] forKey:@"phone_number"];
                [memberDict setObject:@(YES) forKey:@"isGroupModerator"];
                [memberDict setObject:@(YES) forKey:@"isUserInfoAvailable"];
                [roomMemberArray addObject:memberDict];
                
                memberDict = nil;
            }
            else
            {
                NSMutableDictionary *memberDict = [[NSMutableDictionary alloc] init];
                [memberDict setObject:jid.user forKey:@"phone_number"];
                [memberDict setObject:@(YES) forKey:@"isGroupModerator"];
                [memberDict setObject:@(NO) forKey:@"isUserInfoAvailable"];
                [roomMemberArray addObject:memberDict];
                memberDict = nil;
            }
            
            tempDict = nil;
        }
        
        
        if(isMemberListFetched && isModeratorListFetched)
        {
            //[self displayDefaultNavigationTitle];
            
            [self sortRoomMemberArray];
        }
    }
}

-(void)roomMemberListNotFetchedNotification:(NSNotification *)notification
{
    XMPPRoom *room = notification.object;
    DLog(@"Member list not fetched Room ID :- %@", room.myRoomJID.bare);
}

-(void)roomModeratorListNotFetchedNotification:(NSNotification *)notification
{
    XMPPRoom *room = notification.object;
    DLog(@"Moderator list not fetched Room ID :- %@", room.myRoomJID.bare);
}

-(void)roomPrivilegesEditedNotification:(NSNotification *)notification
{
    XMPPRoom *room = notification.object;
    DLog(@"PrivilegesEdited Room ID :- %@", room.myRoomJID.bare);
    
    if([[room.myRoomJID.user lowercaseString] isEqualToString:[[dictUser valueForKey:@"group_id"] lowercaseString]])
    {
        [roomMemberArray removeAllObjects];
        
        isMemberListFetched = NO;
        isModeratorListFetched = NO;
        
        [_currentRoom fetchMembersList];
        
        ////Change [item addAttributeWithName:@"role" stringValue:@"moderator"]; with [item addAttributeWithName:@"affiliation" stringValue:@"owner"]; in this method
        [_currentRoom fetchModeratorsList];
    }
}

-(void)roomPrivilegesNotEditedNotification:(NSNotification *)notification
{
    XMPPRoom *room = notification.object;
    DLog(@"PrivilegesEdited Room ID :- %@", room.myRoomJID.bare);
}

-(void)userRemovedFromGroupNotification:(NSNotification *)notification
{
    NSDictionary *dict = notification.userInfo;
    
    if([[dictUser valueForKey:@"group_id"] isEqualToString:dict[@"group_id"]])
    {
        id viewController = [self.navigationController.viewControllers objectAtIndex:1];
        [self.navigationController popToViewController:viewController animated:YES];
    }
}

-(void)sortRoomMemberArray
{
    NSSortDescriptor *userNameSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"user_name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
    NSSortDescriptor *phoneNumberSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"phone_number" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
    
    NSArray *sortedArray = [roomMemberArray sortedArrayUsingDescriptors:@[userNameSortDescriptor, phoneNumberSortDescriptor]];
    
    [roomMemberArray removeAllObjects];
    [roomMemberArray addObjectsFromArray:sortedArray];
    
    userNameSortDescriptor = nil;
    phoneNumberSortDescriptor = nil;
    sortedArray = nil;
    
}


-(void)joinCurrentRoomIfNeeded
{
    if(self.currentRoom==nil && checkForRoomJoined)
    {
        XMPPRoom *roomObj = [[XmppHelper sharedInstance].rooms objectForKey:[dictUser valueForKey:@"group_id"]];
        
        if(roomObj && roomObj.isJoined)
        {
            _currentRoom = roomObj;
            checkForRoomJoined = NO;
            checkingTimer = nil;
            
            if(_currentRoom!=nil)
            {
                [_currentRoom fetchMembersList];
                
                ////Change [item addAttributeWithName:@"role" stringValue:@"moderator"]; with [item addAttributeWithName:@"affiliation" stringValue:@"owner"]; in this method
                [_currentRoom fetchModeratorsList];
            }
        }
        else
        {
            if([[XmppHelper sharedInstance].xmppStream isConnected] && [[XmppHelper sharedInstance].xmppStream isAuthenticated])
            {
                [[XmppHelper sharedInstance] joinGroup:[dictUser valueForKey:@"group_id"] withNickname:nil];
            }
            checkingTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(joinCurrentRoomIfNeeded) userInfo:nil repeats:NO];
        }
    }
    else
    {
        checkForRoomJoined = NO;
        checkingTimer = nil;
        
        if(_currentRoom!=nil)
        {
            [_currentRoom fetchMembersList];
            
            ////Change [item addAttributeWithName:@"role" stringValue:@"moderator"]; with [item addAttributeWithName:@"affiliation" stringValue:@"owner"]; in this method
            [_currentRoom fetchModeratorsList];
        }
    }
}

-(void)refreshChatMessageTableForChatObj:(id)msgObj
{
    ChatConversation *chatObj = (ChatConversation *)msgObj;
    
    if([chatObj.receiverId isEqualToString:[dictUser valueForKey:@"group_id"]])
    {
        //[chatTableView reloadData];
        [self updateChatTable];
        
        if (chatTableView.contentSize.height > chatTableView.frame.size.height-(chatTableView.contentInset.top+chatTableView.contentInset.bottom))
        {
            CGPoint offset = CGPointMake(0, chatTableView.contentSize.height -  (chatTableView.frame.size.height-(chatTableView.contentInset.top+chatTableView.contentInset.bottom)));
            [chatTableView setContentOffset:offset animated:YES];
        }
    }
}

-(void)newMessageReceivedFrom:(NSString *)user withChatObj:(ChatConversation *)msgObj
{
    if([user isEqualToString:[dictUser valueForKey:@"group_id"]])
    {
        //[chatTableView reloadData];
        [self updateChatTable];
        
        if (chatTableView.contentSize.height > chatTableView.frame.size.height-(chatTableView.contentInset.top+chatTableView.contentInset.bottom))
        {
            CGPoint offset = CGPointMake(0, chatTableView.contentSize.height -  (chatTableView.frame.size.height-(chatTableView.contentInset.top+chatTableView.contentInset.bottom)));
            [chatTableView setContentOffset:offset animated:YES];
        }
    }
    else
    {
        [[XmppHelper sharedInstance] displayNavigationNotificationForChatObj:msgObj];
    }
}
-(void)updateChatTable
{
    NSArray *sections = [[self fetchedResultsController] sections];
    id <NSFetchedResultsSectionInfo> sectionInfo = [sections objectAtIndex:sections.count-1];
    
    NSInteger rows = [chatTableView numberOfRowsInSection:sections.count-1];
//    NSLog(@"%lu",(unsigned long)sectionInfo.numberOfObjects);
//    NSLog(@"%ld",(long)rows);
    
    NSInteger sectionCount = [chatTableView numberOfSections];
    if(sections.count == sectionCount)
    {
        if(sectionInfo.numberOfObjects > rows)
        {
            
            NSArray *paths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:sectionInfo.numberOfObjects-1 inSection:sections.count-1]];
            [chatTableView insertRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationNone];
            
        }
    }
    else if (sectionCount == sections.count-1)
    {
        [chatTableView reloadData];
        
    }
    else
    {
        [chatTableView reloadData];
    }
}

#pragma mark NSFetchedResultsController
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSFetchedResultsController *)fetchedResultsController
{
    if (fetchedResultsController == nil)
    {
        
        NSManagedObjectContext *moc = [XmppHelper sharedInstance].managedObjectContext_chatMessage;
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"ChatConversation"
                                                  inManagedObjectContext:moc];
        
        NSSortDescriptor *sd1 = [[NSSortDescriptor alloc] initWithKey:@"messageDateTime" ascending:YES];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        [fetchRequest setSortDescriptors:@[sd1]];
        [fetchRequest setFetchBatchSize:100];
        
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"senderId == %@ AND receiverId == %@ AND isGroupMessage == 1", [XmppHelper sharedInstance].username, [dictUser valueForKey:@"group_id"]];
        [fetchRequest setPredicate:predicate];
        
        
        
        
        fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                       managedObjectContext:moc
                                                                         sectionNameKeyPath:@"sectionIdentifier"
                                                                                  cacheName:nil];
        [fetchedResultsController setDelegate:self];
        
        
        NSError *error = nil;
        if (![fetchedResultsController performFetch:&error])
        {
            //NSLog(@"Error performing fetch: %@", error);
        }
        
    }
    
    return fetchedResultsController;
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    //[chatTableView reloadData];
    [self updateChatTable];
    
    if (chatTableView.contentSize.height > chatTableView.frame.size.height-(chatTableView.contentInset.top+chatTableView.contentInset.bottom))
    {
        CGPoint offset = CGPointMake(0, chatTableView.contentSize.height - (chatTableView.frame.size.height-(chatTableView.contentInset.top+chatTableView.contentInset.bottom)));
        [chatTableView setContentOffset:offset animated:YES];
    }
}

-(NSString *)getUserJidStr
{
    XMPPUserCoreDataStorageObject *user = [[XmppHelper sharedInstance].xmppRosterStorage userForJID:[XMPPJID jidWithString:[[XmppHelper sharedInstance] getActualUsernameForUser:[dictUser valueForKey:@"group_id"]]] xmppStream:[XmppHelper sharedInstance].xmppStream managedObjectContext:[XmppHelper sharedInstance].managedObjectContext_roster];
    
    NSString *jidStr = [[XmppHelper sharedInstance] getActualUsernameForUser:[dictUser valueForKey:@"group_id"]];
    
    if(user.primaryResource)
    {
        jidStr = user.primaryResource.jid.full;
    }
    
    return jidStr;
}

#pragma mark Send Button
- (IBAction)sendBnClick:(UIButton *)sender
{
    //NSLog(@"%@",chatTextView.text);

    if([[chatTextView.text lowercaseString] isEqualToString:[NSLocalizedString(@"Type Message", nil) lowercaseString]] || [chatTextView.text length] == 0)
    {
        return;
    }

    
    
    if([chatTextView.text length]==0)
    {
        chatTextViewHeightConstraint.constant = 35.0;
        
        return;
    }
    
    //NSData *data = [chatTextView.text dataUsingEncoding:NSNonLossyASCIIStringEncoding];
    //NSString *msgVal = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSString *msgVal = chatTextView.text;
    
    //NSString *strMsg = [NSString stringWithFormat:@"%@ : %@",[LoggedInUser sharedUser].userFullName,msgVal];
    
    NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
    [body setStringValue:msgVal];
    
    //NSTimeInterval  today = [[NSDate date] timeIntervalSince1970]*1000;
    //NSString *intervalString = [NSString stringWithFormat:@"%f", today];
    
    NSXMLElement *chatDetail = [NSXMLElement elementWithName:@"chatDetail" xmlns:@"jabber:x:oob"];
    NSXMLElement *username = [NSXMLElement elementWithName:@"username" stringValue:[NSString stringWithFormat:@"%@",[LoggedInUser sharedUser].userVibeName]];
    [chatDetail addChild:username];
    
    NSXMLElement *name = [NSXMLElement elementWithName:@"name" stringValue:[NSString stringWithFormat:@"%@",[dictUser valueForKey:@"name"]]];
    [chatDetail addChild:name];
    
    NSXMLElement *profile_pic1 = [NSXMLElement elementWithName:@"profile_pic" stringValue:[dictUser valueForKey:@"profile_pic"]];
    [chatDetail addChild:profile_pic1];
    
    NSString *messageID=[[XmppHelper sharedInstance] generateUniqueID];
    NSString *JIDStr = [[XmppHelper sharedInstance] getActualGroupIDForRoom:[dictUser valueForKey:@"group_id"]];
    XMPPJID *roomJID = [XMPPJID jidWithString:JIDStr];
    //NSLog(@"%@",self.dictUser);
    
    
    NSXMLElement *message = [NSXMLElement elementWithName:@"message"];
    [message addAttributeWithName:@"type" stringValue:CHAT_TYPE_GROUP];
    [message addAttributeWithName:@"to" stringValue:[NSString stringWithFormat:@"%@",roomJID]];
    [message addAttributeWithName:@"id" stringValue:messageID];
    [message addChild:body];
    [message addChild:chatDetail];
    
    //XMPPMessage *message = [XMPPMessage messageWithType:CHAT_TYPE_GROUP to:roomJID elementID:messageID child:body];
    
    [[[XmppHelper sharedInstance] xmppStream] sendElement:message];
    
    chatTextViewHeightConstraint.constant = 35.0;
//    [chatTextView resignFirstResponder];
    chatTextView.text = @"";

    //chatTextView.text = [NSLocalizedString(@"Type Message", nil) uppercaseString];
    chatTextView.textColor = [UIColor colorWithRed:93.0/255.0 green:93.0/255.00 blue:93.0/255.00 alpha:1.0];
    [self sendNotification:msgVal];
    [self createRecentChatArray:msgVal];
    
}

#pragma mark --Notification--
-(void)sendNotification:(NSString *)strMessage
{
    NSMutableDictionary *dictNoti = [[NSMutableDictionary alloc] init];
    [dictNoti setValue:[NSString stringWithFormat:@": %@",strMessage] forKey:@"msg"];
    [dictNoti setValue:[LoggedInUser sharedUser].userId forKey:@"user_id"];
    [dictNoti setValue:[dictUser valueForKey:@"group_id"] forKey:@"group_id"];
    
    WebService *serNoti = [[WebService alloc] initWithView:self.view andDelegate:self];
    [serNoti callWebServiceWithURLDict:GROUP_NOTIFICATION
                         andHTTPMethod:@"POST"
                           andDictData:dictNoti
                           withLoading:NO
                      andWebServiceTag:@"notification"
                              setToken:NO];
}

#pragma mark Recent Chat Array
-(void)createRecentChatArray:(NSString *)message
{
    BOOL isAlready = false;
    
    NSDateFormatter *dateFormate = [[NSDateFormatter alloc]init];
    [dateFormate setDateFormat:@"dd/MM/yyyy hh:mm a"];
    NSString *time = [dateFormate stringFromDate:[NSDate date]];
    
    NSArray *recentMag = [[kPref valueForKey:kRecentChatArray] mutableCopy];
    NSMutableArray *arrRecent = [[NSMutableArray alloc]init];
    [arrRecent addObjectsFromArray:recentMag];
    
    for(int i = 0;i<arrRecent.count;i++)
    {
        if([[[arrRecent objectAtIndex:i] valueForKey:@"type"] isEqualToString:CHAT_TYPE_GROUP])
        {
            if([[dictUser valueForKey:@"group_id"] isEqualToString:[[arrRecent objectAtIndex:i] valueForKey:@"group_id"] ])
            {
                int count = 0;
                [arrRecent removeObjectAtIndex:i];
                
                NSMutableDictionary *dictRecent = [[NSMutableDictionary alloc]init];
                [dictRecent setValue:[dictUser valueForKey:@"profile_pic"] forKey:@"profile_pic"];
                [dictRecent setValue:[dictUser valueForKey:@"group_id"] forKey:@"group_id"];
                [dictRecent setValue:[dictUser valueForKey:@"name"] forKey:@"name"];
                [dictRecent setValue:message forKey:@"message"];
                [dictRecent setValue:time forKey:@"time"];
                [dictRecent setValue:CHAT_TYPE_GROUP forKey:@"type"];
                [dictRecent setValue:[NSNumber numberWithInt:count] forKey:@"count"];
                [arrRecent addObject:dictRecent];
                [kPref setObject:arrRecent forKey:kRecentChatArray];
                isAlready = true;
                break;
            }
        }
    }
    if(!isAlready)
    {
        int count = 0;
        NSMutableDictionary *dictRecent = [[NSMutableDictionary alloc]init];
        [dictRecent setValue:[dictUser valueForKey:@"profile_pic"] forKey:@"profile_pic"];
        [dictRecent setValue:[dictUser valueForKey:@"group_id"] forKey:@"group_id"];
        [dictRecent setValue:[dictUser valueForKey:@"name"] forKey:@"name"];
        [dictRecent setValue:message forKey:@"message"];
        [dictRecent setValue:time forKey:@"time"];
        [dictRecent setValue:CHAT_TYPE_GROUP forKey:@"type"];
        [dictRecent setValue:[NSNumber numberWithInt:count] forKey:@"count"];
        [arrRecent addObject:dictRecent];
        [kPref setObject:arrRecent forKey:kRecentChatArray];
    }
}

#pragma mark Group Info Button
- (IBAction)btnProfilePic:(UIButton *)sender
{
    [self performSegueWithIdentifier:@"groupInfo" sender:self];
}

#pragma mark PrepareForSegue Method

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier] isEqualToString:@"groupInfo"])
    {
        GroupInfoController *obj = [segue destinationViewController];
        obj.dictGroup = dictUser;
    }
}


#pragma mark Tableview delegate/datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSArray *sections = [[self fetchedResultsController] sections];
    
    return [sections count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 15.0;
}
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    static NSString *CellIdentifier = @"ChatSectionHeaderCell";
    UITableViewCell *headerView = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    
    
    UILabel *headerLabel = (UILabel *)[headerView viewWithTag:100];
    
    
    NSArray *sections = [[self fetchedResultsController] sections];
    
    if (section < [sections count])
    {
        id <NSFetchedResultsSectionInfo> sectionInfo = [sections objectAtIndex:section];
        
        NSString *sectionNameStr = [sectionInfo name];
        
        NSArray *componentArray = [sectionNameStr componentsSeparatedByString:@"_"];
        
        NSInteger year = [[componentArray objectAtIndex:0] integerValue];
        NSInteger month = [[componentArray objectAtIndex:1] integerValue];
        NSInteger day = [[componentArray objectAtIndex:2] integerValue];
        
        
        NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
        dateComponents.year = year;
        dateComponents.month = month;
        dateComponents.day = day;
        NSDate *date = [[NSCalendar currentCalendar] dateFromComponents:dateComponents];
        
        headerLabel.text = [NSString stringWithFormat:@" %@  "  ,[Utility timeDaysForDate:date]];
        headerLabel.backgroundColor = [UIColor colorWithRed:204.0/255.0 green:204.0/255.0 blue:204.0/255.0 alpha:1.0];
        headerLabel.layer.cornerRadius = 4.0;
        headerLabel.layer.masksToBounds = YES;
        [headerView layoutIfNeeded];
        
        return headerView;
    }
    
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSArray *sections = [[self fetchedResultsController] sections];
    
    if (section < [sections count])
    {
        id <NSFetchedResultsSectionInfo> sectionInfo = [sections objectAtIndex:section];
        return sectionInfo.numberOfObjects;
    }
    
    return 0;
}



- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    ChatConversation *chatObj = [[self fetchedResultsController] objectAtIndexPath:indexPath];
    
    if([chatObj.messageType isEqualToString:OUT_BOUND_MESSAGE_TYPE_IMAGE] || [chatObj.messageType isEqualToString:OUT_BOUND_MESSAGE_TYPE_VIDEO])
    {
        return 142;
    }
    else
    {
        if([chatObj.isMessageReceived boolValue])
        {
            ReceiverGroupChatCell *cell = [chatScreenCells objectForKey:@"ReceiverChatMsgCell"];
            if (!cell && cell.tag!=-1)
            {
                cell = [tableView dequeueReusableCellWithIdentifier:@"ReceiverChatMsgCell"];
                cell.tag = -1;
                [chatScreenCells setObject:cell forKey:@"ReceiverChatMsgCell"];
            }
     
            cell.chatMessageTxt.selectable = NO;
            cell.chatMessageTxt.text = chatObj.messageBody;
            cell.chatMessageTxt.font = [UIFont systemFontOfSize:14.0];
            
            
            CGSize sizeThatFitsTextView = [cell.chatMessageTxt sizeThatFits:CGSizeMake(maxChatTextWidth, MAXFLOAT)];
            cell.msgTxtWidthConstraint.constant = sizeThatFitsTextView.width;
            cell.msgTxtHeightConstraint.constant = sizeThatFitsTextView.height;
            
            if(cell.msgTxtWidthConstraint.constant + 58.0 <= maxChatTextWidth)
            {
            
                CGFloat height = cell.msgTxtHeightConstraint.constant+15.0;
                return height;
            }
            
            [cell setNeedsLayout];
            [cell layoutIfNeeded];
            
            
            CGFloat height = [cell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
            
            return cell.msgTxtHeightConstraint.constant + 30.0;
        }
        else
        {
            SenderChatMsgCell *cell = [chatScreenCells objectForKey:@"SenderChatMsgCell"];
            if (!cell && cell.tag!=-1)
            {
                cell = [tableView dequeueReusableCellWithIdentifier:@"SenderChatMsgCell"];
                cell.tag = -1;
                [chatScreenCells setObject:cell forKey:@"SenderChatMsgCell"];
            }
            
            cell.chatMessageTxt.text = chatObj.messageBody;
            
            cell.chatMessageTxt.font = [UIFont systemFontOfSize:14.0];
            
            CGSize sizeThatFitsTextView = [cell.chatMessageTxt sizeThatFits:CGSizeMake(maxChatTextWidth, MAXFLOAT)];
            cell.msgTxtWidthConstraint.constant = sizeThatFitsTextView.width;
            cell.msgTxtHeightConstraint.constant = sizeThatFitsTextView.height;
            
            [cell setNeedsLayout];
            [cell layoutIfNeeded];
            if(cell.msgTxtWidthConstraint.constant + 58.0 <= maxChatTextWidth)
            {
                CGFloat height = cell.msgTxtHeightConstraint.constant;
                return height;
            }
            
            return cell.msgTxtHeightConstraint.constant + 13.0;

        }
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ChatConversation *chatObj = [[self fetchedResultsController] objectAtIndexPath:indexPath];
    if([chatObj.messageType isEqualToString:OUT_BOUND_MESSAGE_TYPE_IMAGE])
    {
        return nil;
    }
    else
    {
        if([chatObj.isMessageReceived boolValue])
        {
            ReceiverGroupChatCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ReceiverChatMsgCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            cell.chatObj = chatObj;
            
            cell.chatTimeLbl.text = chatObj.messageTimeStr;
            cell.chatTimeLbl.hidden = false;
            
            cell.chatMessageTxt.selectable = YES;
            
            cell.chatMessageTxt.text = chatObj.messageBody;
            cell.chatUserLbl.text = chatObj.senderUserName;
            
            CGSize sizeThatFitsTextView = [cell.chatMessageTxt sizeThatFits:CGSizeMake(maxChatTextWidth, MAXFLOAT)];
            cell.msgTxtWidthConstraint.constant = sizeThatFitsTextView.width;
            cell.msgTxtHeightConstraint.constant = sizeThatFitsTextView.height;
            
            if(cell.msgTxtWidthConstraint.constant + 58.0 <= maxChatTextWidth)
            {
                cell.msgTxtWidthConstraint.constant = sizeThatFitsTextView.width + 58.0;
                if(cell.msgTxtWidthConstraint.constant < cell.chatUserLbl.text.length)
                {
                    cell.msgTxtWidthConstraint.constant = cell.chatUserLbl.text.length + 10.0;
                }
                cell.chatMessageTxt.text = chatObj.messageBody;
            }
            
            if([chatObj.isNew boolValue])
            {
                DLog(@"New message");
                [chatObj setIsNew:@(NO)];
                
                [[XmppHelper sharedInstance].managedObjectContext_chatMessage save:nil];
                
            }
            
            [cell layoutIfNeeded];
            
            return cell;
        }
        else
        {
            SenderChatMsgCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SenderChatMsgCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            cell.chatObj = chatObj;
            
            cell.chatTimeLbl.text = chatObj.messageTimeStr;
            cell.chatTimeLbl.hidden = false;
            cell.msgReadStatusImage.hidden = false;
            
            
            cell.chatMessageTxt.text = chatObj.messageBody;
            
            CGSize sizeThatFitsTextView = [cell.chatMessageTxt sizeThatFits:CGSizeMake(maxChatTextWidth, MAXFLOAT)];
            cell.msgTxtWidthConstraint.constant = sizeThatFitsTextView.width;
            cell.msgTxtHeightConstraint.constant = sizeThatFitsTextView.height;
            
            if(cell.msgTxtWidthConstraint.constant + 58.0 <= maxChatTextWidth)
            {
                cell.chatMessageTxt.text = chatObj.messageBody;
                
                cell.msgTxtWidthConstraint.constant = sizeThatFitsTextView.width + 65.0;
                
            }
            
            if([chatObj.isNew boolValue])
            {
                [chatObj setIsNew:@(NO)];
                [[XmppHelper sharedInstance].managedObjectContext_chatMessage save:nil];
            }
            
            
            cell.msgReadStatusImage.highlighted = NO;
            
            /*if([chatObj.isPending boolValue])
            {
                cell.msgReadStatusImage.highlighted = NO;
            }
            else
            {
                cell.msgReadStatusImage.highlighted = YES;
            }*/
            
            [cell setNeedsLayout];
            [cell layoutIfNeeded];
            
            return cell;
        }
    }
    return nil;
}
#pragma mark --Webservice Delegate Method--
-(void)webserviceCallFinishedWithSuccess:(BOOL)success andResponseObject:(id)responseObj andError:(NSError *)error forWebServiceTag:(NSString *)tagStr
{
    if(success)
    {
        NSDictionary *dictResult = (NSDictionary *)responseObj;
        //NSLog(@"%@",dictResult);
    }
}

#pragma mark --Keyboard show/hide notifications--

//Code from Brett Schumann
-(void) keyboardWillShow:(NSNotification *)note
{
    // get keyboard size and loctaion
    CGRect keyboardBounds;
    [[note.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardBounds];
    NSNumber *duration = [note.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSNumber *curve = [note.userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    
    // Need to translate the bounds to account for rotation.
    keyboardBounds = [self.view convertRect:keyboardBounds toView:nil];
    
    // animations settings
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:[duration doubleValue]];
    [UIView setAnimationCurve:[curve intValue]];
    
    chatBoxViewBottomSpaceConstraint.constant = keyboardBounds.size.height - 50;
    
    // commit animations
    [UIView commitAnimations];
    
    [self.view layoutIfNeeded];
    
    
    if (chatTableView.contentSize.height > chatTableView.frame.size.height)
    {
        CGPoint offset = CGPointMake(0, chatTableView.contentSize.height - chatTableView.frame.size.height);
        [chatTableView setContentOffset:offset animated:YES];
    }
    
}

-(void) keyboardWillHide:(NSNotification *)note
{
    
    NSNumber *duration = [note.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSNumber *curve = [note.userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    
    
    // animations settings
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:[duration doubleValue]];
    [UIView setAnimationCurve:[curve intValue]];
    
    chatBoxViewBottomSpaceConstraint.constant = 0;
    
    // commit animations
    [UIView commitAnimations];
}

#pragma mark --UITextView delegate methods--
- (void)textViewDidBeginEditing:(UITextView *)textView
{
    if([[textView.text lowercaseString] isEqualToString:[NSLocalizedString(@"Type Message", nil) lowercaseString]])
    {
        textView.text = @"";
    }
    textView.textColor = [UIColor blackColor];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    textView.text = [textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if([textView.text length]==0)
    {
        textView.text = [NSLocalizedString(@"Type Message", nil) uppercaseString];
    }
    
    textView.textColor = [UIColor colorWithRed:93.0/255.0 green:93.0/255.00 blue:93.0/255.00 alpha:1.0];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView
{
    if([textView contentSize].height <120.0)
    {
        chatTextViewHeightConstraint.constant = [textView contentSize].height;
        
        CGRect cursorRect = [textView caretRectForPosition:textView.selectedTextRange.end];
        cursorRect= CGRectMake(cursorRect.origin.x, cursorRect.origin.y-3, cursorRect.size.width, cursorRect.size.height);
        [chatTextView scrollRectToVisible:cursorRect animated:YES];
        //WLog(@"height = %f", chatTextViewHeightConstraint.constant);
    }
}

#pragma mark Back Button


- (IBAction)btnBack:(UIButton *)sender
{
    [self chageCountStatusOfRecentArray];
    [self.navigationController popViewControllerAnimated:YES];
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

-(void)chageCountStatusOfRecentArray
{
    NSMutableArray *arrRecent = [[NSMutableArray alloc]init];
    arrRecent = [[kPref valueForKey:kRecentChatArray] mutableCopy];
    for(int k = 0;k<arrRecent.count;k++)
    {
        if([[[arrRecent objectAtIndex:k] valueForKey:@"type"] isEqualToString:CHAT_TYPE_GROUP])
        {
            if([[dictUser valueForKey:@"group_id"] isEqualToString:[[arrRecent objectAtIndex:k] valueForKey:@"group_id"]])
            {
                NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
                dict = [[arrRecent objectAtIndex:k] mutableCopy];
                int count = 0;
                [dict removeObjectForKey:@"count"];
                [dict setValue:[NSNumber numberWithInt:count] forKey:@"count"];
                [arrRecent replaceObjectAtIndex:k withObject:dict];
                [kPref setObject:arrRecent forKey:kRecentChatArray];
                break;
            }
        }
    }
}



@end
