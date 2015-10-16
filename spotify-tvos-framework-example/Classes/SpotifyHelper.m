//
//  SpotifyHelper.m
//  spotify-tvos-framework-example
//
//  Created by Loreto Parisi on 16/10/15.
//  Copyright © 2015 loretoparisi. All rights reserved.
//

#import "SpotifyHelper.h"
#import "Spotify.h"

// Spotify Defaults: put this in app configuration
static NSString * const kSpotifyClientId = @"";
static NSString * const kSpotifyCallbackURL = @"mytest://oauth/sp/callback";
static NSString * const kSpotifySwapURL = @"";
static NSString * const  kSpotifyTokenRefreshServiceURL = @"";

NSString * const kSpotifyDefaultSessionKey                                   = @"SpotifySession";
NSString * const kSpotifyDefaultException                                    = @"SpotiyException";
NSString * const kSpotifyPlayerException                                     = @"SpotiyPlayerException";

@interface SpotifyHelper()<SPTAudioStreamingDelegate,SPTAudioStreamingPlaybackDelegate> {
    SPTSession *session;
    SPTAudioStreamingController *streamingPlayer;
    SPTPlaylistSnapshot *currentPlaylist;
}

/** Spotify User Session */
@property(nonatomic,strong) SPTSession *session;

@end

@implementation SpotifyHelper

@synthesize session;

+ (instancetype)sharedInstance {
    static dispatch_once_t pred;
    static SpotifyHelper *shared = nil;
    dispatch_once(&pred, ^{
        shared = [[SpotifyHelper alloc] init];
    });
    return shared;
}


/**
 * Initialize the Spotify client
 */
- (void)initSpotify {
    
    [SPTAuth defaultInstance].clientID = kSpotifyClientId;
    [SPTAuth defaultInstance].requestedScopes = [self getAccessTokenScopes];
    [SPTAuth defaultInstance].redirectURL = [NSURL URLWithString:kSpotifyCallbackURL];
    [SPTAuth defaultInstance].tokenRefreshURL = [NSURL URLWithString:kSpotifyTokenRefreshServiceURL];
    [SPTAuth defaultInstance].tokenSwapURL = [NSURL URLWithString:kSpotifySwapURL];
    [SPTAuth defaultInstance].sessionUserDefaultsKey = kSpotifyDefaultSessionKey;
    
    if(streamingPlayer == nil) { // lazy init the streaming player
        streamingPlayer = [[SPTAudioStreamingController alloc] initWithClientId:kSpotifyClientId];
        [streamingPlayer setDelegate:self];
        [streamingPlayer setPlaybackDelegate:self];
        [streamingPlayer setTargetBitrate:SPTBitrateHigh callback:^(NSError *error) {
            if(error) {
                NSLog(@"Bitrate setup error %@", error.localizedDescription);
            }
        }];
    }
    
    NSLog(@"SPTAuth %@", [SPTAuth defaultInstance]);
    NSLog(@"SPTAudioStreamingController %@", streamingPlayer);
    
}

- (void)renewSession:(SPTSession*)aSession completion:(void (^)(NSError* error))completion {
    [[SPTAuth defaultInstance] renewSession:aSession callback:^(NSError *error, SPTSession *newSession) {
        if (error) {
            if(completion) completion(error);
        } else if(newSession) {
            NSLog(@"Renewed Session USER:%@\nTOKEN:%@\nREFRESH TOKEN(ENCRYPTED):%@\nEXPIRES:%@\nVALID:%d",
             [newSession canonicalUsername],
             [newSession accessToken],
             [newSession encryptedRefreshToken],
             [newSession expirationDate],
             [newSession isValid]
             );
            if(completion) {
                completion(nil);
            }
        }
    }];
}

#pragma mark - Spotify Web API

/**
 * Login the Spotify client with access token, refresh token and expiration timeinterval
 */
-(void)loginWithAccessToken:(NSString *)accessToken
            refreshToken:(NSString*)refreshToken
            expirationTimeInterval:(NSTimeInterval)timeInterval
            completion:(void (^)(NSError* error))completion {
    SpotifyHelper *weakSelf = self;
    [self fetchUserProfileWithAccessToken:accessToken completion:^(id result, NSError *error) {
        if(!error && result) {
            NSLog(@"%@", result);
            if( [result objectForKey:@"id"] ) {
                NSString *userName =  [result objectForKey:@"id"];
                SPTSession *newSession = [[SPTSession alloc] initWithUserName:userName
                                                                accessToken:accessToken
                                                      encryptedRefreshToken:refreshToken
                                                             expirationDate:[NSDate dateWithTimeInterval:timeInterval sinceDate:[NSDate date]]];
                [weakSelf setSession:newSession];
                [self renewSession:weakSelf.session completion:^(NSError *error) {
                    if(error==nil) {
                        NSLog(@"Session was renewed\n%@", weakSelf.session);
                    }
                }];
                
            } else {
                if(completion) completion(error);
            }
        }
        if(completion) completion(error);
    }];
}

/**
 * Fetch a Track through the WebAPI
 * @return SPTTrack
 */
-(void)fetchTrack:(NSString*)trackId
       useCountry:(BOOL)useCountry
       completion:(void (^)(id results, NSError* error))completion {
    NSString *apiUrl = [NSString stringWithFormat:@"https://api.spotify.com/v1/tracks/%@", trackId];
    if(useCountry) {
        NSString *cc = [[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode] uppercaseString];
        apiUrl = [apiUrl stringByAppendingFormat:@"?market=%@",cc];
    }
    NSURL *url = [NSURL URLWithString:apiUrl];
    [[[NSURLSession sharedSession] dataTaskWithURL:url
                                 completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                     if (error) {
                                         completion(nil,error);
                                     }
                                     else {
                                         
                                         NSError *err=nil;
                                         NSDictionary *jsonResult = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&err];
                                         
                                         NSLog(@"%@", jsonResult);
                                         
                                         if(completion) completion(jsonResult, error);
                                         
                                     }
                                 }] resume];
}

/**
 * Fetch Categories through the WebAPI
 * @return Categories List JSON Object
 
 Optional parameters
 
 locale es_MX
 lmit max number of categories
 offset pagination
 country IT -  ISO 3166
 
 Response  Body
 
 {
 "categories" : {
 "limit" : 20,
 "next" : null,
 "offset" : 0,
 "previous" : null,
 "total" : 12
 "items" : [ ]
 }
 }
 
 */
-(void)fetchCategories:(NSDictionary*)options
           accessToken:(NSString*)accessToken
            completion:(void (^)(id results, NSError* error))completion {
    NSString *apiUrl = @"https://api.spotify.com/v1/browse/categories";
    if(options) {
        NSString *qs = [self queryStringFromDictionary:options];
        apiUrl = [apiUrl stringByAppendingString:qs];
    }
    NSURL *url = [NSURL URLWithString:apiUrl];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    NSString *headersAuth = [NSString stringWithFormat:@"Bearer %@", accessToken];
    [urlRequest setValue:headersAuth forHTTPHeaderField:@"Authorization"];
    [[[NSURLSession sharedSession] dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            completion(nil,error);
        }
        else {
            
            NSError *err=nil;
            NSDictionary *jsonResult = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&err];
            NSLog(@"%@", jsonResult);
            SPTTrack *track = [[SPTTrack alloc] initWithDecodedJSONObject:jsonResult error:&error];
            if(!err) {
                completion(track,nil);
            } else {
                completion(nil,err);
            }
        }
    }] resume];
}

/**
 * Fetch Featured Playlists through the WebAPI
 * @return Playlists List JSON Object
 
 Optional parameters
 
 lmit max number of categories
 offset pagination
 country IT -  ISO 3166
 timestamp UTC time: "2014-10-23T09:00:00" - user's local time
 
 Response  Body
 
 {
 "playlists" : {
 "limit" : 20,
 "next" : null,
 "offset" : 0,
 "previous" : null,
 "total" : 12
 "items" : [ ]
 }
 }
 
 */
- (void)fetchFeaturedPlaylists:(NSDictionary*)options accessToken:(NSString*)accessToken
                   completion:(void (^)(id results, NSError* error))completion {
    NSString *apiUrl = @"https://api.spotify.com/v1/browse/featured-playlists";
    if(options) {
        NSString *qs = [self queryStringFromDictionary:options];
        apiUrl = [apiUrl stringByAppendingString:qs];
    }
    NSURL *url = [NSURL URLWithString:apiUrl];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    NSString *headersAuth = [NSString stringWithFormat:@"Bearer %@",accessToken];
    [urlRequest setValue:headersAuth forHTTPHeaderField:@"Authorization"];
    [[[NSURLSession sharedSession] dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            completion(nil,error);
        }
        else {
            NSError *err=nil;
            NSDictionary *jsonResult = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&err];
            if( !err && [jsonResult objectForKey:@"playlists"] ) {
                NSLog(@"%@", jsonResult);
                NSArray *list  = [[jsonResult objectForKey:@"playlists"] objectForKey:@"items"];
                NSMutableArray *results = [[NSMutableArray alloc] init];
                for (NSDictionary *playlistObj in list) {
                    NSError *error=nil;
                    SPTPlaylistSnapshot *playlist = [[SPTPlaylistSnapshot alloc] initWithDecodedJSONObject:playlistObj error:&error];
                    if(!error) {
                        [results addObject:playlist];
                    }
                }
                completion(results,nil);
            } else {
                completion(nil,err);
            }
        }
    }] resume];
}

/**
 * Fetch New Reelases through the WebAPI
 * @return Album List JSON Object
 
 Optional parameters
 
 lmit max number of categories
 offset pagination
 country IT -  ISO 3166
 
 Response  Body
 
 {
 "albums" : {
 "limit" : 20,
 "next" : null,
 "offset" : 0,
 "previous" : null,
 "total" : 12
 "items" : [ ]
 }
 }
 
 */
- (void)fetchNewReleases:(NSDictionary*)options
             accessToken:(NSString*)accessToken
             completion:(void (^)(id results, NSError* error))completion {
    NSString *apiUrl = @"https://api.spotify.com/v1/browse/new-releases";
    if(options) {
        NSString *qs = [self queryStringFromDictionary:options];
        apiUrl = [apiUrl stringByAppendingString:qs];
    }
    NSURL *url = [NSURL URLWithString:apiUrl];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    NSString *headersAuth = [NSString stringWithFormat:@"Bearer %@",accessToken];
    [urlRequest setValue:headersAuth forHTTPHeaderField:@"Authorization"];
    [[[NSURLSession sharedSession] dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            completion(nil,error);
        }
        else {
            NSError *err=nil;
            NSDictionary *jsonResult = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&err];
            if( !err && [jsonResult objectForKey:@"albums"] ) {
                NSLog(@"%@", jsonResult);
                NSArray *albums  = [[jsonResult objectForKey:@"albums"] objectForKey:@"items"];
                NSMutableArray *results = [[NSMutableArray alloc] init];
                for (NSDictionary *albumObj in albums) {
                    NSError *error=nil;
                    SPTAlbum *album = [[SPTAlbum alloc] initWithDecodedJSONObject:albumObj error:&err];
                    if(!error) {
                        [results addObject:album];
                    }
                }
                completion(results,nil);
            } else {
                completion(nil,err);
            }
        }
    }] resume];
}

/**
 * Fetch a Category through the WebAPI
 * @param NSString name Category Id
 * @return Category JSON Object
 
 Optional parameters
 
 locale es_MX
 country IT -  ISO 3166
 
 
 */
- (void)fetchCategory:(NSString*)categoryId options:(NSDictionary*)options
          accessToken:(NSString*)accessToken
          completion:(void (^)(id results, NSError* error))completion {
    NSString *apiUrl = [NSString stringWithFormat:@"https://api.spotify.com/v1/browse/categories/%@", categoryId];
    if(options) {
        NSString *qs = [self queryStringFromDictionary:options];
        apiUrl = [apiUrl stringByAppendingString:qs];
    }
    NSURL *url = [NSURL URLWithString:apiUrl];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    NSString *headersAuth = [NSString stringWithFormat:@"Bearer %@",accessToken];
    [urlRequest setValue:headersAuth forHTTPHeaderField:@"Authorization"];
    [[[NSURLSession sharedSession] dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            completion(nil,error);
        }
        else {
            NSError *err=nil;
            NSDictionary *jsonResult = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&err];
            NSLog(@"%@", jsonResult);
            if(!err) {
                completion(jsonResult,nil);
            } else {
                completion(nil,err);
            }
        }
    }] resume];
}

/**
 * Fetch Category's Playlists through the WebAPI
 * @param NSString category_id Category Id
 * @return JSON Array of Playlists
 
 Optional parameters
 
 lmit max number of categories
 offset pagination
 country IT -  ISO 3166
 
 */
- (void)fetchCategoryPlaylists:(NSString*)categoryId options:(NSDictionary*)options
                   accessToken:(NSString*)accessToken
                    completion:(void (^)(id results, NSError* error))completion {
    NSString *apiUrl = [NSString stringWithFormat:@"https://api.spotify.com/v1/browse/categories/%@/playlists", categoryId];
    if(options) {
        NSString *qs = [self queryStringFromDictionary:options];
        apiUrl = [apiUrl stringByAppendingString:qs];
    }
    NSURL *url = [NSURL URLWithString:apiUrl];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    NSString *headersAuth = [NSString stringWithFormat:@"Bearer %@",accessToken];
    [urlRequest setValue:headersAuth forHTTPHeaderField:@"Authorization"];
    [[[NSURLSession sharedSession] dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            completion(nil,error);
        }
        else {
            NSError *err=nil;
            NSDictionary *jsonResult = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&err];
            if( !err && [jsonResult objectForKey:@"playlists"] ) {
                NSLog(@"%@", jsonResult);
                NSArray *list  = [[jsonResult objectForKey:@"playlists"] objectForKey:@"items"];
                NSMutableArray *results = [[NSMutableArray alloc] init];
                for (NSDictionary *playlistObj in list) {
                    NSError *error=nil;
                    SPTPartialPlaylist *playlist = [[SPTPartialPlaylist alloc] initWithDecodedJSONObject:playlistObj error:&error];
                    if(!error) {
                        [results addObject:playlist];
                    }
                }
                completion(results,nil);
            } else {
                completion(nil,err);
            }
        }
    }] resume];
}

/**
 * Fetch Playlists through the WebAPI
 * @return Array of SPTPlaylist objects
 */
- (void)fetchPlayistsForUserInSession:(NSString*)username accessToken:(NSString*)accessToken
                          completion:(void (^)(id results, NSError* error))completion {
    NSString *apiUrl = [NSString stringWithFormat:@"https://api.spotify.com/v1/users/%@/playlists", username];
    NSURL *url = [NSURL URLWithString:apiUrl];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    NSString *headersAuth = [NSString stringWithFormat:@"Bearer %@",accessToken];
    [urlRequest setValue:headersAuth forHTTPHeaderField:@"Authorization"];
    [[[NSURLSession sharedSession] dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            completion(nil,error);
        }
        else {
            NSError *err=nil;
            NSDictionary *jsonResult = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&err];
            NSLog(@"%@", jsonResult);
            if(!err) {
                completion(jsonResult,nil);
            } else {
                completion(nil,err);
            }
        }
    }] resume];
}

/**
 * Load User Profle
 * @param completion Completion handler
 * @return An object
 */
- (void)fetchUserProfileWithAccessToken:(NSString*)accessToken
                             completion:(void (^)(id results, NSError* error))completion {
    NSString *apiUrl = [NSString stringWithFormat:@"https://api.spotify.com/v1/me/?access_token=%@", accessToken];
    NSURL *url = [NSURL URLWithString:apiUrl];
    [[[NSURLSession sharedSession] dataTaskWithURL:url
                                 completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                     if (error) {
                                         completion(nil,error);
                                     }
                                     else {
                                         NSError *err=nil;
                                         NSDictionary *jsonResult = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&err];
                                         NSLog(@"%@", jsonResult);
                                         if(!err) {
                                             completion(jsonResult,nil);
                                         } else {
                                             completion(nil,err);
                                         }
                                     }
                                 }] resume];
}

#pragma mark - Spotify Helpers

/**
 * Get scopes for login service
 * @return NSArray Scopes of login
 */
- (NSArray*)getAccessTokenScopes {
    
    return @[
             // Streaming
             SPTAuthStreamingScope,
             
             // User
             SPTAuthUserReadEmailScope,
             SPTAuthUserReadPrivateScope,
             
             // Playlists
             SPTAuthPlaylistModifyPublicScope,
             SPTAuthPlaylistModifyPrivateScope,
             SPTAuthPlaylistReadPrivateScope,
             
             // User Playlists
             SPTAuthPlaylistReadPrivateScope,
             SPTAuthPlaylistModifyPrivateScope,
             
             // User Library
             SPTAuthUserLibraryReadScope,
             SPTAuthUserLibraryModifyScope
             
             ];
    
}

#pragma mark - Class Utils

- (NSString *)escapeUnicodeWithString:(NSString*)stringToEscape {
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                 (CFStringRef)stringToEscape,
                                                                                 NULL,
                                                                                 (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                                                 kCFStringEncodingUTF8 ));
}

- (NSString *)queryStringFromDictionary:(NSDictionary*)dict {
    NSMutableString *queryString = nil;
    NSArray *keys = [dict allKeys];
    if ([keys count] > 0) {
        for (id key in keys) {
            id value = [dict objectForKey:key];
            if (nil == queryString) {
                queryString = [[NSMutableString alloc] init];
                [queryString appendFormat:@"?"];
            } else {
                [queryString appendFormat:@"&"];
            }
            
            if (nil != key && nil != value) {
                if( ![value isKindOfClass:[NSString class]] ) {
                    value = [value stringValue];
                }
                [queryString appendFormat:@"%@=%@", [self escapeUnicodeWithString:key], [self escapeUnicodeWithString:value]];
            } else if (nil != key) {
                [queryString appendFormat:@"%@", [self escapeUnicodeWithString:key]];
            }
        }
    }
    return queryString;
}

@end
