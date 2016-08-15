library(readr)
library(dplyr)
library(tidyr)
library(RSQLite)
library(ggplot2)
library(Matrix)
library(plyr)
library(pbapply)
library(lsa)
library(recommenderlab)
library(plyr)

# # Load in data and create data frames
# user_data <- as.data.frame(read.table('data/kaggle/kaggle_users.txt'))
# colnames(user_data) <- c('User_ID')
# user_data <- mutate(user_data, UID = row(user_data))
# 
# song_data <- as.data.frame(read.table('data/kaggle/kaggle_songs.txt'))
# colnames(song_data) <- c('Song_ID', 'index')
# 
triplets <- as.data.frame(read.table('data/kaggle/kaggle_visible_evaluation_triplets.txt'))
colnames(triplets) <- c('User_ID', 'Song_ID', 'Plays')
# 
# song2track <- as.data.frame(read.table('data/kaggle/taste_profile_song_to_tracks.txt', 
#                                        fill= TRUE))
# colnames(song2track) <- c('Song_ID', 'Track_ID')
# 
# totdf <- left_join(triplets, song2track, by = "Song_ID")
# 
# con = dbConnect(drv=RSQLite::SQLite(), 
#                 dbname="data/MillionSongSubset/AdditionalFiles/track_metadata.db")
# songs <- dbGetQuery(con, 'SELECT * FROM songs')
# 
# con_meta = dbConnect(drv=RSQLite::SQLite(), dbname="song_metadata.sqlite")
# song_metadata <- dbGetQuery(con_meta, 'SELECT track_id, loudness, time_signature, 
#                             song_hotttnesss FROM song_metadata')
# 
# con_simArt = dbConnect(drv=RSQLite::SQLite(), 
#                        dbname="data/MillionSongSubset/AdditionalFiles/artist_similarity.db")
# sim_Artists <- dbGetQuery(con_simArt, 'SELECT * FROM songs')
# 
# totdf2 <- totdf %>% left_join(songs, by = c('Track_ID' = 'track_id')) %>%
#   filter(!is.na(title)) %>% 
#   left_join(song_metadata, by = c('Track_ID' = 'track_id')) %>%
#   select(-song_id, -track_7digitalid, -shs_perf, -shs_work)

# ==========================================================

source('helperFunctions.R')

# Training dataset
train_data <- triplets %>%
  dplyr::group_by(User_ID) %>%
  dplyr::sample_frac(0.8) %>%
  dplyr::ungroup()

# Validation dataset
valid_data <- setdiff(triplets, train_data)

# Get top 1000 songs by total plays over all users
top1000songs <- train_data %>% 
  dplyr::group_by(Song_ID) %>%
  dplyr::summarise(Total.Plays = sum(Plays)) %>%
  dplyr::arrange(desc(Total.Plays)) %>%
  dplyr::top_n(1000) %>%
  dplyr::ungroup()

# Get unique users/songs, prep dataframes for sparse matrix
unique_users <- unique(train_data$User_ID)
unique_songs <- unique(train_data$Song_ID)

unique_users <- as.character(unique_users)
unique_songs <- as.character(unique_songs)

unique_users <- cbind(unique_users, as.numeric(seq(nrow(as.data.frame(unique_users)))))
unique_songs <- cbind(unique_songs, as.numeric(seq(nrow(as.data.frame(unique_songs)))))

colnames(unique_users) <- c('User_ID', 'UID')
colnames(unique_songs) <- c('Song_ID', 'SID')

train_data$User_ID <- as.character(train_data$User_ID)
train_data$Song_ID <- as.character(train_data$Song_ID)

# Add relative plays
train_data_2 <- train_data %>% 
  dplyr::left_join(as.data.frame(unique_users), by = 'User_ID') %>%
  dplyr::left_join(as.data.frame(unique_songs), by =  'Song_ID') %>%
  dplyr::group_by(User_ID) %>%
  dplyr::mutate(Relative.Plays = Plays/sum(Plays))

# Remove any NAs
train_data_2[is.na(train_data_2)] <- 0 

# Put into sparse matrix
sparse_rating_df <- sparseMatrix(i = as.integer(levels(train_data_2$UID))[train_data_2$UID], 
                                 j = as.integer(train_data_2$SID), 
                                 x = train_data_2$Relative.Plays)

# Song similarity matrix
multMat1 <- t(sparse_rating_df) %*% (sparse_rating_df)

# User similarity Matrix
multMat2 <- (sparse_rating_df) %*% t(sparse_rating_df)


unique_users <- as.data.frame(unique_users)
unique_users$UID <- as.numeric(levels(unique_users$UID))[unique_users$UID]

unique_songs <- as.data.frame(unique_songs)
unique_songs$SID <- as.numeric(levels(unique_songs$SID))[unique_songs$SID]

# Get average precision for baseline (recommend same top 500 songs to all users)
getBaseline_AveragePrecision <- function(user){
  actual.songs <- filter(valid_data, User_ID == unique_users$User_ID[user])
  avg.Pres <- average_precision_at_k(k=500, actual = actual.songs$Song_ID, 
                                     predicted = top1000songs$Song_ID[1:500])
  return(avg.Pres)
}

# Get average precision for user-user similarity strategy
getUser_Average_Precision<- function(user){
  user1_sim <- multMat2[user,] 
  user1_sim <- as.data.frame(cbind(user1_sim, seq(length(user1_sim))))
  colnames(user1_sim) <- c('Similarity', 'UID')
  user1_sim <- user1_sim %>%
    dplyr::arrange(desc(Similarity)) %>%
    dplyr::top_n(100, Similarity) %>%
    dplyr::left_join(unique_users, by = 'UID')
  
  rec.songs <- data.frame()
  i = 1
  while(nrow(rec.songs) < 500){
    if(user1_sim$Similarity[i] > 0.00000){
      new.songs <- recommend_by_user(user1_sim$User_ID[user], user1_sim$User_ID[i])
      rec.songs <- unique(rbind(rec.songs, new.songs))
    } else{
      new.songs <- as.data.frame(top1000songs$Song_ID[1:(1000-nrow(rec.songs))+1], 
                                 stringsAsFactors = FALSE)
      colnames(new.songs) <- 'Song_ID'
      rec.songs <- unique(rbind(rec.songs, new.songs))
    }
    i = i + 1
  }
  actual.songs <- filter(valid_data, User_ID == unique_users$User_ID[user])
  avg.Pres <- average_precision_at_k(k=500, actual = actual.songs$Song_ID, predicted = rec.songs$Song_ID)
  return(avg.Pres)
}

# Get average precision for item-item similarity strategy
getSong_AveragePrecision<- function(user){
  songs <- train_data_2 %>%
    filter(UID == user) %>%
    select(SID)
  
  # If SID is of factor class change to integer
  if (class(songs$SID) == "factor"){
    songs$SID <- as.integer(levels(songs$SID))[songs$SID]
  }
  top500total <- ldply(songs$SID, gettop500simSong) %>%
    anti_join(songs, by = 'SID') %>%
    distinct() %>%
    arrange(desc(Similarity)) %>%
    top_n(500, Song_ID)
  
  actual.songs <- filter(valid_data, User_ID == unique_users$User_ID[user])
  avg.Pres <- average_precision_at_k(k=500, actual = actual.songs$Song_ID, predicted = top500total$Song_ID)
  return(avg.Pres)
}

# Take mean of average precisions
mAP_baseline <- pbsapply(seq(3000), getBaseline_AveragePrecision)
mean(mAP_baseline)

mAP <- pbsapply(seq(300), getUser_Average_Precision)
mean(mAP)

mAP2 <- pbsapply(seq(500), getSong_AveragePrecision)
mean(mAP2)

train_data_2$SID <- as.numeric(levels(train_data_2$SID))[train_data_2$SID]

# Discover new artists
discoverNewSongs<- function(user){
  usersongs <- train_data_2 %>%
    filter(UID == user) %>%
    select(SID)
  
  # If SID is of factor class change to integer
  if (class(usersongs$SID) == "factor"){
    usersongs$SID <- as.integer(levels(usersongs$SID))[usersongs$SID]
  }
  top500total <- ldply(usersongs$SID, gettop500simSong) %>%
    dplyr::anti_join(usersongs, by = 'SID') %>%
    dplyr::distinct() %>%
    dplyr::top_n(500, Similarity) %>%
    dplyr::left_join(songs, by = c('Song_ID' = 'song_id')) %>%
    dplyr::arrange(artist_familiarity) %>%
    dplyr::select(artist_name, title, artist_familiarity, Song_ID) 
  return(top500total)
}

# Find songs with low tempo
downbeatSongs<- function(user){
  usersongs <- train_data_2 %>%
    filter(UID == user) %>%
    select(SID)
  
  # If SID is of factor class change to integer
  if (class(usersongs$SID) == "factor"){
    usersongs$SID <- as.integer(levels(usersongs$SID))[usersongs$SID]
  }
  top500total <- ldply(usersongs$SID, gettop500simSong) %>%
    dplyr::anti_join(usersongs, by = 'SID') %>%
    dplyr::distinct() %>%
    dplyr::top_n(500, Similarity) %>%
    dplyr::left_join(song2track, by = 'Song_ID') %>%
    dplyr::left_join(song_metadata, by = c('Track_ID' = 'track_id')) %>%
    dplyr::arrange(time_signature) %>%
    dplyr::select(Song_ID, time_signature) %>%
    dplyr::filter(!is.na(Song_ID))
  return(top500total)
}
downbeatSongs(2)

# Find songs with high tempo
upbeatSongs<- function(user){
  usersongs <- train_data_2 %>%
    filter(UID == user) %>%
    select(SID)
  
  # If SID is of factor class change to integer
  if (class(usersongs$SID) == "factor"){
    usersongs$SID <- as.integer(levels(usersongs$SID))[usersongs$SID]
  }
  top500total <- ldply(usersongs$SID, gettop500simSong) %>%
    dplyr::anti_join(usersongs, by = 'SID') %>%
    dplyr::distinct() %>%
    dplyr::top_n(500, Similarity) %>%
    dplyr::left_join(song2track, by = 'Song_ID') %>%
    dplyr::left_join(song_metadata, by = c('Track_ID' = 'track_id')) %>%
    dplyr::arrange(desc(time_signature)) %>%
    dplyr::select(Song_ID, time_signature) %>%
    dplyr::filter(!is.na(Song_ID))
  return(top500total)
}

# SVD
s1 <- irlba(sparse_rating_df, 5, 5)