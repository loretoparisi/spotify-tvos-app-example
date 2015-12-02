//
//  SpotifyHelper.h
//  spotify-tvos-framework-example
//
//  Created by Loreto Parisi on 16/10/15.
//  Copyright © 2015 loretoparisi. All rights reserved.
//

@import Foundation;

@interface SpotifyHelper : NSObject

+ (instancetype)sharedInstance;

- (void)initSpotify;

#pragma mark - Spotify Player API

/**
 * Play a Spotify Track Id
 * @param spotifyId NSString The Spotify Track Id
 */
- (void)playTrackWithSpotifyId:(NSString*)spotifyId
                        queue:(BOOL)queue
                        completion:(void (^)(NSError *error))completion;

#pragma mark - Web API

/**
 * Login the Spotify client with access token, refresh token and expiration timeinterval
 */
-(void)loginWithAccessToken:(NSString *)accessToken
               refreshToken:(NSString*)refreshToken
     expirationTimeInterval:(NSTimeInterval)timeInterval
                 completion:(void (^)(NSError* error))completion;

/**
 * Load User Profle
 * @param completion Completion handler
 * @return An object
 */
- (void)fetchUserProfileWithAccessToken:(NSString*)accessToken
                             completion:(void (^)(id results, NSError* error))completion;
/**
 * Fetch Playlists through the WebAPI
 * @return Array of SPTPlaylist objects
 */
- (void)fetchPlayistsForUserInSession:(NSString*)username
                          accessToken:(NSString*)accessToken
                          completion:(void (^)(id results, NSError* error))completion;


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
                    completion:(void (^)(id results, NSError* error))completion;

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
          completion:(void (^)(id results, NSError* error))completion;

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
            completion:(void (^)(id results, NSError* error))completion;

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
- (void)fetchFeaturedPlaylists:(NSDictionary*)options
                accessToken:(NSString*)accessToken
                completion:(void (^)(id results, NSError* error))completion;

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
            completion:(void (^)(id results, NSError* error))completion;

/**
 * Fetch a Track through the WebAPI
 * @return SPTTrack
 */
-(void)fetchTrack:(NSString*)trackId
       useCountry:(BOOL)useCountry
       completion:(void (^)(id results, NSError* error))completion;

#pragma mark -
#pragma mark SDK Search API

/**
 * Search Spotify Track
 */
-(void)searchSpotifyTrackWithQuery:(NSString *)searchQuery
                       accessToken:(NSString*)accessToken
                        completion:(void (^)(id results, NSError* error))completion;

/**
 * Search Spotify Artist
 */
-(void)searchSpotifyArtistWithQuery:(NSString *)searchQuery
                        accessToken:(NSString*)accessToken
                         completion:(void (^)(id results, NSError* error))completion;
/**
 * Search Spotify Album
 */
-(void)searchSpotifyAlbumWithQuery:(NSString *)searchQuery
                       accessToken:(NSString*)accessToken
                        completion:(void (^)(id results, NSError* error))completion;

@end
