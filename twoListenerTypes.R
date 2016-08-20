# load in libraries
library(readr)
library(dplyr)
library(tidyr)
library(RSQLite)
library(ggplot2)
library(e1071)

# Load in data
train_data <- read_csv('data/train_triplets.csv')
con = dbConnect(drv=RSQLite::SQLite(), 
                                dbname="data/MillionSongSubset/AdditionalFiles/track_metadata.db")
songs <- dbGetQuery(con, 'SELECT song_id, artist_name FROM songs')

# Get number of unique artists in users listening profiles 
NumArtistsperUser <- train_data %>%
  dplyr::left_join(songs, by = c('Song_ID' = 'song_id')) %>% # join with metadata
  dplyr::select(User_ID, Song_ID, artist_name) %>%           # select columns
  dplyr::group_by(User_ID) %>%                               # group by user
  dplyr::distinct(artist_name) %>%                           # filter unique artists
  dplyr::summarise(Total.Artists = n())                      # count unique artists
  
# Gent mean number of plays per artists for each user
MeanArtistPlays <- train_data %>%
  dplyr::left_join(songs, by = c('Song_ID' = 'song_id')) %>% # join with metadata
  dplyr::select(User_ID, Plays, artist_name) %>%             # select columns
  dplyr::group_by(User_ID, artist_name) %>%                  # group by users, artist
  dplyr::summarise(Total.Artist.Plays = sum(Plays)) %>%      # count number of plays per artist
  dplyr::ungroup() %>%                                       # ungroup
  dplyr::group_by(User_ID) %>%                               # group by user
  dplyr::summarise(Mean.Artist.Plays = mean(Total.Artist.Plays)) # mean num of plays


# Join dataframes
tot_data_df <- NumArtistsperUser %>%
  inner_join(MeanArtistPlays, by = 'User_ID')

# 2D histogram plot
ggplot() + geom_bin2d(data = tot_data_df, 
                      aes(x = Total.Artists, y = Mean.Artist.Plays),
                      binwidth = c(1,3)) +
  scale_fill_gradient(trans="log10") + 
  labs(x = 'Total Artists', y = 'Mean Plays per Artist', 
       title = 'Characterization of Users Listening Histories') +
  xlim(0,500) + ylim(0,300) +
  theme(text = element_text(size=20))

# Create play index
PlayIndex <- log(tot_data_df$Total.Artists/tot_data_df$Mean.Artist.Plays)

# Plot distribution
ggplot() + geom_histogram(aes(PlayIndex), bins = 200) +
  labs(x = 'Play Index', title = 'Distribution of Play Index') + 
  geom_vline(aes(xintercept = mean(PlayIndex)), colour = 'red') +
  theme(text = element_text(size=20))

# Caluculate kurtosis and skewness
kurtosis(logArtistIndex)
skewness(logArtistIndex)

# check out min and max play indices
tot_data_df[which.max(logArtistIndex),1]
tot_data_df[which.min(logArtistIndex),]