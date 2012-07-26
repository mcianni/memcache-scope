//
//  AppDelegate.h
//  Memcache Scope
//
//  Created by Michael Cianni on 7/10/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class GCDAsyncSocket;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate> {

@private 
    GCDAsyncSocket *asyncSocket;
}

@property (assign) IBOutlet NSWindow *window;
@property (nonatomic, retain) IBOutlet NSTableView *keyValueView;
@property (nonatomic, retain) IBOutlet NSTextField *statusLabel;
@property (nonatomic, retain) IBOutlet NSTextField *hostField;
@property (nonatomic, retain) IBOutlet NSTextField *portField;
@property (nonatomic, retain) IBOutlet NSTextView *detailView;
@property (nonatomic, retain) NSMutableDictionary *tableData;
@property (nonatomic, retain) NSMutableDictionary *expiresData;
@property (nonatomic, retain) NSMutableArray *keys;
@property (nonatomic, retain) NSString *host;
@property (nonatomic) unsigned short port;

- (IBAction)connect:(id)sender;
- (IBAction)reload:(id)sender;

@end
