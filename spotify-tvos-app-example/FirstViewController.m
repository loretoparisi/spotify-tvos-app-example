//
//  FirstViewController.m
//  spotify-tvos-app-example
//
//  Created by Loreto Parisi on 16/10/15.
//  Copyright © 2015 loretoparisi. All rights reserved.
//

#import "FirstViewController.h"
#import "spotify-tvos-framework-example.h"

@interface FirstViewController ()

@end

@implementation FirstViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [[SpotifyHelper sharedInstance] initSpotify];
    [[SpotifyHelper sharedInstance] fetchTrack:@"6RsWqX8zABZLhZydXxEFOm" useCountry:YES completion:^(id results, NSError *error) {
        if(error) {
            NSLog(@"Error %@", error.localizedDescription);
        }
        else {
            NSLog(@"Fetched track %@", results);
        }
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
