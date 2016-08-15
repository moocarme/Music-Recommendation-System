# Function that returns of all common listeners given 2 artist ids
common_listeners_by_id <- function(song1, song2) {
  Users1 <- subset(train_data, Song_ID == song1)
  Users2 <- subset(train_data, Song_ID == song2)
  Users_sameset <- intersect(Users1[,'User_ID'],
                             Users2[,'User_ID'])
  if (length(Users_sameset)==0) {
    NA
  } else {
    Users_sameset
  }
}

# table of artist_name and id
# artist_lookup <- totdf2 %>% dplyr::select(artist_id, artist_name) %>% distinct()
# artist_name_to_id <- function(artist){
#   subset(artist_lookup, artist_name == artist)$artist_id
# }

# Function that returns of all common listeners given 2 artist names
common_listeners_by_name <- function(artist_name1, artist_name2) {
  artist1 <- subset(artist_lookup, artist_name==artist_name1)$artist_id
  artist2 <- subset(artist_lookup, artist_name==artist_name2)$artist_id
  common_listeners_by_id(artist1, artist2)
}

get_plays_metrics <- function(song, listenerset) {
  song.data <- train_data %>% 
    dplyr::filter(Song_ID==song & User_ID %in% listenerset) %>%
    dplyr::group_by(Song_ID) %>%
    dplyr::summarise(Total.Plays = sum(Plays)) %>%
    dplyr::ungroup()
}


get_plays <- function(song, listenerset) {
  artist.data <- train_data %>% 
    dplyr::filter(Song_ID==song & User_ID %in% listenerset) %>%
    dplyr::group_by(Song_ID) %>%
    dplyr::summarise(Total.Plays = sum(Plays)) %>%
    dplyr::arrange(Song_ID) %>%
    dplyr::ungroup() %>%
    dplyr::select(Total.Plays)
}

# Function to calculate similarity of two artists given their common users
calc_similarity <- function(song1, song2) {
  common_listeners <- common_listeners_by_id(song1, song2)
  # if (is.na(common_listeners)) {
  #   return (NA)
  # }
  song1.reviews <- get_plays(song1, common_listeners)
  song2.reviews <- get_plays(song2, common_listeners)
  #this can be more complex; we're just taking a weighted average
  weights <- c(1)
  corrs <- sapply(names(song1.reviews), function(metric) {
    cosine(song1.reviews[metric], song2.reviews[metric])
  })
  sum(corrs * weights, na.rm=TRUE)
}

# Function to calculate similarity of two users given their common songs
calc_user_similarity <- function(user1, user2){
  user1.songPlays <- dplyr::filter(train_data, User_ID == user1)
  user2.songPlays <- dplyr::filter(train_data, User_ID == user2)
  common_songs <- as.data.frame(dplyr::union(user1.songPlays$Song_ID, 
                                             user2.songPlays$Song_ID),
                                stringsAsFactors = FALSE)
  colnames(common_songs) <- c('Song_ID')
  user1.songPlays.full <- dplyr::left_join(common_songs, 
                                           user1.songPlays, by = 'Song_ID')
  user2.songPlays.full <- dplyr::left_join(common_songs, 
                                           user2.songPlays, by = 'Song_ID')
  user1.songPlays.full[is.na(user1.songPlays.full)] <- 0
  user2.songPlays.full[is.na(user2.songPlays.full)] <- 0
  correlation <- cosine(user1.songPlays.full$Plays, 
                        user2.songPlays.full$Plays)
  return(correlation)
}

# Recommend songs by user-user similarity
recommend_by_user <- function(user1, user2){
  user1.songs <- train_data %>% 
    dplyr::filter(User_ID == user1) %>%
    dplyr::select(Song_ID, Plays)
  user2.songs <- train_data %>% 
    dplyr::filter(User_ID == user2) %>%
    dplyr::select(Song_ID, Plays)
  recommend.songs <- dplyr::anti_join(user2.songs, user1.songs, 
                                      by = 'Song_ID') %>%
    dplyr::arrange(desc(Plays)) %>%
    dplyr::select(-Plays)
  return(recommend.songs)
}

# Calculate precision at k
average_precision_at_k <- function(k, actual, predicted){
  score <- 0.0
  cnt <- 0.0
  for (i in 1:min(k,length(predicted)))
  {
    if (predicted[i] %in% actual && !(predicted[i] %in% predicted[0:(i-1)]))
    {
      cnt <- cnt + 1
      score <- score + cnt/i 
    }
  }
  score <- score / min(length(actual), k)
  return(score)
}

# return top 500 most similar songs
gettop500simSong <- function(song){
  user_sim <- multMat1[song,] 
  user_sim <- as.data.frame(cbind(user_sim, seq(length(user_sim))))
  colnames(user_sim) <- c('Similarity', 'SID')
  user_sim <- user_sim %>%
    dplyr::left_join(unique_songs, by = 'SID') %>%
    dplyr::arrange(desc(Similarity)) %>%
    dplyr::top_n(500, Similarity) 
  return(user_sim)
}
