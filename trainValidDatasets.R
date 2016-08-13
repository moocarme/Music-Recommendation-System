library(readr)
library(dplyr)
library(tidyr)

userdata1M <- as.data.frame(read.table('data/MillionSongSubset/data/Triplets for 1M Users/train_triplets.txt'))
colnames(userdata1M) <- c('User_ID', 'Song_ID', 'Plays')
train_data <- userdata1M %>% 
  dplyr::group_by(User_ID) %>%
  dplyr::sample_frac(0.5)
valid_data <- setdiff(userdata1M, train_data)
write_csv(train_data, 'data/train_triplets.csv')
write_csv(valid_data, 'data/valid_triplets.csv')