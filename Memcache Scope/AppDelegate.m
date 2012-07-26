//
//  AppDelegate.m
//  Memcache Scope
//
//  Created by Michael Cianni on 7/10/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "AppDelegate.h"
#import "GCDAsyncSocket.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "DispatchQueueLogFormatter.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_OFF;

// Private methods
@interface AppDelegate()

- (void) _connectToHost:(NSString *)h onPort:(uint16_t)p;
- (void) _initializeVariables:(dispatch_queue_t)queue;
- (void) _queryDatastore;

@end

@implementation AppDelegate

@synthesize window = _window;
@synthesize detailView, keyValueView, statusLabel;
@synthesize hostField, portField;
@synthesize keys;
@synthesize tableData, expiresData;
@synthesize host, port;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    DispatchQueueLogFormatter *formatter = [[DispatchQueueLogFormatter alloc] init];
	[formatter setReplacementString:@"socket" forQueueLabel:GCDAsyncSocketQueueName];
	[formatter setReplacementString:@"socket-cf" forQueueLabel:GCDAsyncSocketThreadName];
    
	[[DDTTYLogger sharedInstance] setLogFormatter:formatter];
    
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    [self _initializeVariables:mainQueue];
    [self _connectToHost:host onPort:port];
}

- (void)_initializeVariables:(dispatch_queue_t)queue
{
    asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:queue];
    tableData = [[NSMutableDictionary alloc] init];
    expiresData = [[NSMutableDictionary alloc] init];
    [keyValueView setDelegate:self];
    [keyValueView setRowHeight:50.0];

    // Set default host and port
    host = @"127.0.0.1";
    port = 11211;
    [hostField setStringValue:host];
    [portField setStringValue:[[NSString alloc] initWithFormat:@"%i", port]];
    
}

- (void) _connectToHost:(NSString *)_host onPort:(uint16_t)_port
{
    NSError *error = nil;
    if (![asyncSocket connectToHost:_host onPort:_port error:&error]) {
		DDLogError(@"Unable to connect to due to invalid configuration: %@", error);
        [statusLabel setStringValue:@"Unable to connect!"];
    }
    else {
        [statusLabel setStringValue:@"Connecting..."];
        DDLogVerbose(@"Connecting...");
    }
}

- (void) _queryDatastore
{
    NSData *requestData = [@"stats items\n" dataUsingEncoding:NSUTF8StringEncoding];
    [asyncSocket writeData:requestData withTimeout:-1.0 tag:0];
    
    NSData *termination = [@"END" dataUsingEncoding:NSUTF8StringEncoding];
    [asyncSocket readDataToData:termination withTimeout:20 tag:0];    
}

#pragma mark Socket Delegate
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)_host port:(uint16_t)_port
{
    [statusLabel setStringValue:@"Connected!"];
    [self _queryDatastore];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	DDLogVerbose(@"socket:didWriteDataWithTag: %li", tag);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSData *end = [@"END" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSArray *lines = [response componentsSeparatedByString:@"\r\n"];
    
    if (tag == 0) { //The initial request for all items
        NSMutableArray *ids = [[NSMutableArray alloc] init];
        for (NSString *line in lines) {
            NSArray *tokens = [line componentsSeparatedByString:@":"];
            if ([tokens count] > 1 && ![ids containsObject:[tokens objectAtIndex:1]]) { // Not the END line and a new id
                [ids addObject:[tokens objectAtIndex:1]];
            }
        }

        for (NSString *id in ids) {
            NSData *nextRequest = [[NSString stringWithFormat:@"stats cachedump %@ 10000\n", id] dataUsingEncoding:NSUTF8StringEncoding];
            [asyncSocket writeData:nextRequest withTimeout:-1.0 tag:1];
            [asyncSocket readDataToData:end withTimeout:-1.0 tag:1]; 
        }
    }
    
    if (tag == 1) { 
        for (NSString *line in lines) {
            NSArray *tokens = [line componentsSeparatedByString:@" "];
            if ([tokens count] > 1) {                      // Not the END line
                NSString *key = [tokens objectAtIndex:1];
                [keys addObject:key];                      // Store the key
                if ([tokens count] > 4) {                  // Store the expiration
                    NSDate *expires_at = [[NSDate alloc] initWithTimeIntervalSince1970:[[tokens objectAtIndex:4] doubleValue]];
                    [expiresData setValue:[expires_at description] forKey:key];
                }
                
                NSData *nextRequest = [[NSString stringWithFormat:@"get %@\r\n", [tokens objectAtIndex:1]] dataUsingEncoding:NSASCIIStringEncoding];
                [asyncSocket writeData:nextRequest withTimeout:-1.0 tag:2];
                [asyncSocket readDataToData:end withTimeout:-1.0 tag:2];
            }
        }
        [asyncSocket readDataToData:end withTimeout:-1.0 tag:1];
    }
    
    if (tag == 2) {
        if ([lines objectAtIndex:1] != NULL) { // make sure this isn't a blank line
            NSArray *tokens = [[lines objectAtIndex:1] componentsSeparatedByString:@" "];

            if ([tokens count] > 1) {          // make sure this isn't an END
                NSArray *tokens = [[lines objectAtIndex:1] componentsSeparatedByString:@" "];
                NSString *key = [tokens objectAtIndex:1];
                
                NSString *value = [lines objectAtIndex:2];
                [tableData setValue:value forKey:key];
                [keyValueView reloadData];
            }
        }
        [asyncSocket readDataToData:end withTimeout:-1.0 tag:2];
    }
}

- (IBAction)connect:(id)sender
{

}

- (IBAction)reload:(id)sender
{

}

#pragma mark tableview delegate methods
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView 
{
    return [tableData count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *key = [[tableData allKeys] objectAtIndex:row];
    if ([[tableColumn identifier] isEqualToString:@"keys"]) {
        return key;
    }
    else if ([[tableColumn identifier] isEqualToString:@"expires"]) {
        return [expiresData objectForKey:key];
    }
    else {        
        return [tableData objectForKey:key];
    }
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    [detailView setString:[tableData objectForKey:[[tableData allKeys] objectAtIndex:[keyValueView selectedRow]]]];
}


@end
