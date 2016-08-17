# -*- coding: utf-8 -*-
"""
Created on Tue Aug 16 20:39:47 2016

@author: matt-666
"""

# Import libraries
import spotipy
import spotipy.util as util
import pickle

# API details 
scope = 'user-library-read'
token = util.prompt_for_user_token('Matt Moocarme', scope, 
                                   client_id = 'ca7b704534b94eaa8a5ff45763423971', 
                                   client_secret = '3d575d58d08440ea94afbbb81972f57f',
                                   redirect_uri = 'https://www.google.com')

sp = spotipy.Spotify(auth = token)

# get categories
categories = sp.categories(limit = 50)

# use max limit
limit = 50

# Get list of category ids
ids = []
for cat_id in (categories['categories']).items()[0][1]:
    ids.append(cat_id['id'])


# Initialise lists and dict
playlist_ids, playlist_owners, playlist_metadata = [], [], {}

# Get playlist IDs, owners and metadata 
for category_id in ids:
    all_playlists = sp.category_playlists(category_id = category_id, 
                                          limit = limit)
    # go through all playlist items
    for playlist in all_playlists['playlists']['items']:
        playlist_ids.append(playlist['id'])             # get id
        playlist_owners.append(playlist['owner']['id']) # get owner
        playlist_metadata[playlist['name']] = playlist  # get metadata

# Initialise lists
playlist_descs, playlist_names, playlist_followers = [], [], []

# Iterate through playlists
for playlist_id, playlist_owner in zip(playlist_ids, playlist_owners):
    the_playlist = sp.user_playlist(user = playlist_owner, 
                                    playlist_id = playlist_id)
    playlist_names.append(the_playlist['name'])        # get name
    playlist_descs.append(the_playlist['description']) # get description
    playlist_followers.append(the_playlist['followers']['total']) # get total followers
    
# dump in pickle file
pickleFile = open('playlistData.p', 'w')
pickle.dump((playlist_names, playlist_descs, playlist_followers, 
             playlist_ids, playlist_owners, playlist_metadata), pickleFile)
pickleFile.close()

