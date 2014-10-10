//
//  ViewController.m
//  ABMockerObjC
//
//  Created by Sergii Kryvoblotskyi on 10/10/14.
//  Copyright (c) 2014 Alterplay. All rights reserved.
//

#import "ViewController.h"
#import <AddressBook/AddressBook.h>

static NSInteger contactsCount = 1000;

@interface ViewController () {
    dispatch_queue_t _privateQueue;
}

@property (weak, nonatomic) IBOutlet UILabel *workingLabel;
@property (weak, nonatomic) IBOutlet UIButton *createAccountsButton;
@end

@implementation ViewController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        /* Serial queue */
        _privateQueue = dispatch_queue_create("com.abmocker.privateQueue", 0x00);
    }
    return self;
}

#pragma mark - Accounts

- (void)createAccounts
{
#if TARGET_IPHONE_SIMULATOR
    
    /* Create the AddressBook */
    CFErrorRef error = NULL;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &error); // create address book record
    
    /* Semaphore it, until permissions granted */
    __block BOOL accessGranted = NO;
    if (ABAddressBookRequestAccessWithCompletion != NULL) {
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        
        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
            accessGranted = granted;
            dispatch_semaphore_signal(sema);
        });
        
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    } else {
        accessGranted = YES;
    }
    
    /* We've got the permissions! */
    if (accessGranted) {
        
        self.createAccountsButton.enabled = NO;
        self.workingLabel.hidden = NO;
        
        /* Dispatch on background queue */
        dispatch_async(_privateQueue, ^{
           
            NSArray *thePeople = (__bridge_transfer NSArray*)ABAddressBookCopyArrayOfAllPeople(addressBook);
            
            for (NSInteger i = thePeople.count; i < contactsCount + thePeople.count; i++) {
                
                ABRecordRef person = ABPersonCreate(); // create a person
                
                NSInteger randomNumber = arc4random() % 100000000;
                NSString *phone = [NSString stringWithFormat:@"%li", (long)randomNumber]; // the phone number to add
                NSString *email = [NSString stringWithFormat:@"%li@alexeytester.com", i]; // the phone number to add
                
                /* Phone */
                ABMutableMultiValueRef phoneNumberMultiValue = [self generatePhoneWithString:phone];
                ABRecordSetValue(person, kABPersonPhoneProperty, phoneNumberMultiValue, nil);
                
                /* Email */
                ABMutableMultiValueRef emailMultiValue = [self generateEmailWithString:email];
                ABRecordSetValue(person, kABPersonEmailProperty, emailMultiValue, nil);
                
                /* First name */
                NSString *firstName = [NSString stringWithFormat:@"First Name %ld", (long)i];
                ABRecordSetValue(person, kABPersonFirstNameProperty, (__bridge CFTypeRef)(firstName) , nil);
                
                /* Last name */
                NSString *lastName = [NSString stringWithFormat:@"Last Name %ld", i];
                ABRecordSetValue(person, kABPersonLastNameProperty, (__bridge CFTypeRef)(lastName), nil);
                
                /* Add a record to DB */
                ABAddressBookAddRecord(addressBook, person, nil);
                
                ABRecordRef group = ABGroupCreate();
                ABRecordSetValue(group, kABGroupNameProperty,@"ABMocker Group", nil);
                ABGroupAddMember(group, person, nil);
                ABAddressBookAddRecord(addressBook, group, nil);
                
                /* Release the memory */
                CFRelease(person);
                CFRelease(group);
                CFRelease(phoneNumberMultiValue);
                CFRelease(emailMultiValue);
                
            }
            
            /* Save to AB */
            ABAddressBookSave(addressBook, nil); //save the record
            
            /* Notify we are done */
            dispatch_async(dispatch_get_main_queue(), ^{
                
                self.createAccountsButton.enabled = YES;
                self.workingLabel.hidden = YES;
                
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Job is done" message:nil delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil];
                [alert show];
            });
        });
    }
    
#else
    
    NSLog(@"Do not do it on the device, man!");
    
#endif
    
}

#pragma mark - Actions

- (IBAction)createAccountsButtonClicked:(id)sender {
    [self createAccounts];
}

#pragma mark - Private

- (ABMutableMultiValueRef)generatePhoneWithString:(NSString *)string
{
    ABMutableMultiValueRef phoneNumberMultiValue = ABMultiValueCreateMutable(kABPersonPhoneProperty);
    ABMultiValueAddValueAndLabel(phoneNumberMultiValue ,(__bridge CFTypeRef)(string),kABPersonPhoneMobileLabel, NULL);
    return phoneNumberMultiValue;
}


- (ABMutableMultiValueRef)generateEmailWithString:(NSString *)string
{
    ABMutableMultiValueRef emailMultiValue = ABMultiValueCreateMutable(kABPersonEmailProperty);
    ABMultiValueAddValueAndLabel(emailMultiValue, (__bridge CFTypeRef)(string), kABOtherLabel, NULL);
    return emailMultiValue;
}


@end
