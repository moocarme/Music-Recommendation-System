library(readr)
library(dplyr)
library(tidyr)
library(RSQLite)
library(ggplot2)
library(e1071)

train_data <- read_csv('data/train_triplets.csv')
con = dbConnect(drv=RSQLite::SQLite(), 
                                dbname="data/MillionSongSubset/AdditionalFiles/track_metadata.db")
songs <- dbGetQuery(con, 'SELECT song_id, artist_name FROM songs')

NumArtistsperUser <- train_data %>%
  dplyr::left_join(songs, by = c('Song_ID' = 'song_id')) %>%
  dplyr::select(User_ID, Song_ID, artist_name) %>%
  dplyr::group_by(User_ID) %>%
  dplyr::distinct(artist_name) %>%
  dplyr::summarise(Total.Artists = n())
  
MeanArtistPlays <- train_data %>%
  dplyr::left_join(songs, by = c('Song_ID' = 'song_id')) %>%
  dplyr::select(User_ID, Plays, artist_name) %>%
  dplyr::group_by(User_ID, artist_name) %>%
  dplyr::summarise(Total.Artist.Plays = sum(Plays)) %>%
  dplyr::ungroup() %>%
  dplyr::group_by(User_ID) %>%
  dplyr::summarise(Mean.Artist.Plays = mean(Total.Artist.Plays))

tot_data_df <- NumArtistsperUser %>%
  inner_join(MeanArtistPlays, by = 'User_ID')

ggplot() + geom_bin2d(data = tot_data_df, 
                      aes(x = Total.Artists, y = Mean.Artist.Plays),
                      binwidth = c(1,3)) +
  scale_fill_gradient(trans="log10") + 
  labs(x = 'Total Artists', y = 'Mean Plays per Artist', 
       title = 'Characterization of Users Listening Histories') +
  xlim(0,500) + ylim(0,300) +
  theme(text = element_text(size=20))

logArtistIndex <- log(tot_data_df$Total.Artists/tot_data_df$Mean.Artist.Plays)
ggplot() + geom_histogram(aes(logArtistIndex), bins = 200) +
  labs(x = 'Play Index', title = 'Distribution of Play Index') + 
  geom_vline(aes(xintercept = mean(logArtistIndex)), colour = 'red') +
  theme(text = element_text(size=20))


kurtosis(logArtistIndex)
skewness(logArtistIndex)

tot_data_df[which.max(logArtistIndex),]
  tot_data_df[which.min(logArtistIndex),]