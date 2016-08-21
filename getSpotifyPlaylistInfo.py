# -*- coding: utf-8 -*-
"""
Created on Tue Aug 16 20:39:47 2016

@author: matt-666
"""

# Import libraries
import spotipy
import spotipy.util as util
import pickle
from wordcloud import WordCloud
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np

# =====================================

# API details and log in ======================
scope = 'user-library-read'
token = util.prompt_for_user_token('Matt Moocarme', scope, 
                                   client_id = '-client-id-', 
                                   client_secret = '-client-secret-',
                                   redirect_uri = 'https://www.google.com')

sp = spotipy.Spotify(auth = token)

# ===========================================

# use max limit
limit = 50

# get categories
categories = sp.categories(limit = limit)

# Get list of category ids
ids = []
for cat_id in (categories['categories']).items()[0][1]:
    ids.append(cat_id['id'])


# Initialise lists and dict
playlist_ids, playlist_owners, playlist_metadata, playlist_categories = [], [], {}, []

# Get playlist IDs, owners and metadata 
for category_id in ids:
    all_playlists = sp.category_playlists(category_id = category_id, 
                                          limit = limit)
    # go through all playlist items
    for playlist in all_playlists['playlists']['items']:
        playlist_ids.append(playlist['id'])             # get id
        playlist_owners.append(playlist['owner']['id']) # get owner
        playlist_metadata[playlist['name']] = playlist  # get metadata
        playlist_categories.append(category_id)
        
# Initialise lists
playlist_descs, playlist_names, playlist_followers = [], [], []

# Iterate through playlists and get all relevent info
for playlist_id, playlist_owner in zip(playlist_ids, playlist_owners):
    the_playlist = sp.user_playlist(user = playlist_owner, 
                                    playlist_id = playlist_id)
    playlist_names.append(the_playlist['name'])        # get name
    playlist_descs.append(the_playlist['description']) # get description
    playlist_followers.append(the_playlist['followers']['total']) # get total followers

# =======================================

# Create wordclouds =====================
all_names = ' '.join(playlist_names)
wordcloud = WordCloud(width = 700, height = 300, 
                      max_font_size=90, relative_scaling=.7).generate(all_names)
plt.figure(13)
plt.imshow(wordcloud)
plt.axis('off')

playlist_descs = ['' if desc is None else desc for desc in playlist_descs]
all_descs = ' '.join(playlist_descs)
wordcloud_descs = WordCloud().generate(all_descs)
plt.figure(-13)
plt.imshow(wordcloud_descs)
plt.axis('off')
# =======================================

# Exploratory daya analysis =============

# find mean number of followers per owner
df_dict = {'Name' : playlist_names, 
           'Owner' : playlist_owners,
           'followers' : playlist_followers,
           'category': playlist_categories}
           
df = pd.DataFrame(df_dict)

mean_followers_per_user = df.groupby(['Owner']).mean().sort('followers', ascending = False)
plt.figure(222); plt.clf()
plt.bar(range(len(mean_followers_per_user)), mean_followers_per_user['followers'])

mean_followers_per_category = df.groupby(['category']).mean().sort('followers', ascending = False)
plt.figure(223); plt.clf()
plt.bar(range(len(mean_followers_per_category)), 
        np.round(mean_followers_per_category['followers']))

# ========================================
        
        
# dump in pickle file ====================
pickleFile = open('playlistData.p', 'w')
pickle.dump((playlist_names, playlist_descs, playlist_followers, 
             playlist_ids, playlist_owners, playlist_metadata, 
             playlist_categories), pickleFile)
pickleFile.close()

# ========================================