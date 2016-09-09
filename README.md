# Building a Music Recommendation System
Build a Music recommendation system, that can provide custom mood-based playlists for 
individual users. Currently music service providers have generic (and popular), mood-based 
playlists, that are the same for all users. Here, I suggest improvements to these playlists
by offering custom playlists for each user based on song metadata.

Strategies used to recommend songs include recommending
- based on popular songs - choose the top 500 most played songs
- based on user-user similarity - choose songs that similar users listen to
- based on item-item similarity - choose songs share many common listeners 

Once a good strategy is found, custom recommendations are created based on metadata. For example, chillout playlists are created of recommended songs with low tempo.
