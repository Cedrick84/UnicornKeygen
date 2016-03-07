//
//  ViewController.m
//  Unicorn Keygen
//
//  Created by Cedrick Gout on 04/03/16.
//  Copyright © 2016 CRMedia. All rights reserved.
//

#import "ViewController.h"
#import "CocoaCryptoHashing.h"


@interface ViewController () <NSControlTextEditingDelegate>

@property (weak) IBOutlet NSTextField *nameTextField;
@property (weak) IBOutlet NSTextField *serialTextField;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    NSTextField *textField = obj.object;
    _serialTextField.stringValue = [self generateSerialForName:textField.stringValue];
}

- (NSString *) generateSerialForName:(NSString *)name
{
    NSString *s = [NSString stringWithFormat:@"%@+unicorn", name];
    NSString *md5 = [s md5HexHash];
    NSString *up = md5.uppercaseString;
    
    return [up substringToIndex:20];
}




@end
