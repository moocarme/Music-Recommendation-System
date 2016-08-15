library(rhdf5)
library(rechonest)
library(readr)
library(dplyr)
library(tidyr)
library(RSQLite)
library(ggplot2)
library(Matrix)
library(recommenderlab)
# api_key <- 'J0ILER0LQESUBJQZC' # echonest api key

# Load in data and create data frames
user_data <- as.data.frame(read.table('data/kaggle/kaggle_users.txt'))
colnames(user_data) <- c('User_ID')
user_data <- mutate(user_data, UID = row(user_data))

song_data <- as.data.frame(read.table('data/kaggle/kaggle_songs.txt'))
colnames(song_data) <- c('Song_ID', 'index')

triplets <- as.data.frame(read.table('data/kaggle/kaggle_visible_evaluation_triplets.txt'))
colnames(triplets) <- c('User_ID', 'Song_ID', 'Plays')

song2track <- as.data.frame(read.table('data/kaggle/taste_profile_song_to_tracks.txt', fill= TRUE))
colnames(song2track) <- c('Song_ID', 'Track_ID')

totdf <- left_join(triplets, song2track, by = "Song_ID")

con = dbConnect(drv=RSQLite::SQLite(), dbname="data/MillionSongSubset/AdditionalFiles/track_metadata.db")
songs <- dbGetQuery(con, 'SELECT * FROM songs')

con_meta = dbConnect(drv=RSQLite::SQLite(), dbname="song_metadata.sqlite")
song_metadata <- dbGetQuery(con_meta, 'SELECT track_id, loudness, time_signature, song_hotttnesss FROM song_metadata')

con_simArt = dbConnect(drv=RSQLite::SQLite(), dbname="data/MillionSongSubset/AdditionalFiles/artist_similarity.db")
sim_Artists <- dbGetQuery(con_simArt, 'SELECT * FROM songs')

totdf2 <- totdf %>% left_join(songs, by = c('Track_ID' = 'track_id')) %>%
  filter(!is.na(title)) %>% 
  left_join(song_metadata, by = c('Track_ID' = 'track_id')) %>%
  select(-song_id, -track_7digitalid, -shs_perf, -shs_work)

# Exploratory data analysis
popular_songs <- totdf2 %>% 
  dplyr::group_by(title, artist_name) %>% 
  dplyr::summarise(Total.plays = sum(Plays)) %>% 
  dplyr::arrange(desc(Total.plays)) %>%
  dplyr::top_n(500)

popular_artists <- totdf2 %>% 
  dplyr::group_by(artist_name) %>% 
  dplyr::summarise(Total.plays = sum(Plays)) %>% 
  dplyr::arrange(desc(Total.plays)) %>%
  dplyr::top_n(500)

hottest_artists<- totdf2 %>%
  dplyr::select(artist_name, artist_hotttnesss) %>%
  dplyr::distinct() %>%
  dplyr::arrange(desc(artist_hotttnesss)) %>%
  dplyr::top_n(100)

hottest_songs <- totdf2 %>%
  dplyr::select(artist_name, title, song_hotttnesss) %>%
  dplyr::distinct() %>%
  dplyr::arrange(desc(song_hotttnesss)) %>%
  dplyr::top_n(100)

songs_per_user <- totdf2 %>%
  dplyr::select(User_ID, Song_ID) %>% 
  dplyr::group_by(User_ID) %>%
  dplyr::summarize(Total.Songs = n()) %>%
  dplyr::arrange(Total.Songs) %>%
  dplyr::group_by(Total.Songs) %>%
  dplyr::summarise(Total.Count = n()) %>%
  dplyr::mutate(Cum.Sum = cumsum(Total.Count))

png('../Website/moocarme.github.io/MusicRec/figs/songs_per_user.png', width = 700)
ggplot() + geom_line(data = songs_per_user, aes(x = Total.Songs, y = Cum.Sum)) +
  labs(title = 'Cumulative Number of Songs per User', x= 'Total Songs', y = 'Cumulative Sum')+ 
  theme(plot.title = element_text(size=22), axis.text.x = element_text(size=18),
        axis.text.y = element_text(size=18), text = element_text(size = 20))
dev.off()


users_per_song <- totdf2 %>%
  dplyr::select(User_ID, Song_ID) %>%
  dplyr::group_by(Song_ID) %>%
  dplyr::summarise(Total.Users = n()) %>%
  dplyr::group_by(Total.Users) %>%
  dplyr::summarise(Total.Count = n()) %>%
  dplyr::mutate(Cum.Sum = cumsum(Total.Count))

png('../Website/moocarme.github.io/MusicRec/figs/users_per_song.png', 
    width = 700, pointsize = 200)
ggplot() + 
  geom_line(data = users_per_song, aes(x = Total.Users, y = Cum.Sum)) + 
  scale_x_log10() + labs(title = 'Cumulative Sum of Users per Song', 
                         x = 'Total Users', y = 'Cumulative Sum')+ 
  theme(plot.title = element_text(size=22), axis.text.x = element_text(size=18),
        axis.text.y = element_text(size=18), text = element_text(size = 20))
dev.off()

png('../Website/moocarme.github.io/MusicRec/figs/songs_per_year.png', 
    width = 700, pointsize = 200)
ggplot() + geom_histogram(data = filter(totdf2, year>1900), aes(x = year), binwidth = 1, 
                          fill = '#18BC9C', color = '#2C3E50') +  xlim(1940,2012) + 
  labs(title = 'Number of Songs per Year', x = 'Year', y = 'Count')+
  theme(plot.title = element_text(size=22), axis.text.x = element_text(size=18),
        axis.text.y = element_text(size=18), text = element_text(size = 20))
dev.off()

png('../Website/moocarme.github.io/MusicRec/figs/loudness_per_year.png', 
    width = 900, pointsize = 20)
ggplot(data = filter(totdf2, year>1900), 
       aes(x = as.factor(year), y = loudness) ) + geom_boxplot(aes(fill = (year))) +
  scale_fill_gradient(low = 'yellow', high = 'red') + 
  scale_x_discrete(breaks = seq(1920, 2010, 10)) + 
  labs(title = 'Loudness vs Year', x = 'Year', y = 'Loudness (dB)')+
  theme(plot.title = element_text(size=22), axis.text.x = element_text(size=18),
        axis.text.y = element_text(size=18), text = element_text(size = 20))
dev.off()
