# -*- coding: utf-8 -*-
"""
Created on Tue Aug 16 21:15:07 2016

@author: matt-666
"""

# Import libraries
import pickle
import nltk
import pandas as pd
from sklearn import linear_model
from sklearn.cross_validation import train_test_split
import numpy as np 
import matplotlib.pyplot as plt
import scipy.stats as sp


# get data from pickle file ========================
with open(r"playlistData.p", "rb") as input_file:
    e = pickle.load(input_file)

playlist_names, playlist_descs, playlist_followers = e[0], e[1], e[2]
playlist_ids, playlist_owners, playlist_metadata  = e[3], e[4], e[5]

# =================================================

# remove null values
playlist_followers = [0 if number is None else number for number in playlist_followers]


# nltk.help.upenn_tagset() # list of tags
# Create dataframe
totdf = pd.DataFrame(columns = ('CC', 'CD', 'DT', 'EX', 'FW', 'IN', 'JJ', 'JJR',
                             'JJS', 'LS', 'MD', 'NN', 'NNP', 'NNPS', 'NNS', 
                             'PDT', 'POS', 'PRP', 'PRP$', 'RB', 'RBR', 'RP', 
                             'SYM', 'TO', 'UH', 'VB', 'VBD', 'VBG', 'VBN', 
                             'VBP', 'VBZ', 'WDT', 'WP', 'WP$', 'WRB', 
                             'Num_Words', 'Num_Chars'))

# Create dict from analysing playlist titles
word_ref = {}
for playlist_name in playlist_names:
    numchars = len(playlist_name) # get number of chars in playlist name
    numwords = len(playlist_name.split()) # get number of words in playlist name
    text = nltk.word_tokenize(playlist_name.lower()) # tokenise 
    tags = nltk.pos_tag(text)
    
    # get just the word type tags, i.e., VB for verb
    type_list = []
    for (word, word_type) in tags:
        type_list.append(word_type)
        try:
            tmp_list = word_ref[word_type]  # get list from dictionary 
            tmp_list.append(word)           # append to list
            word_ref[word_type] = tmp_list  # put back in dictionary
        except AttributeError:
            word_ref[word_type] = []
        except KeyError:
            word_ref[word_type] = []
            
    # count each instance and insert to dict
    word_type_count = {}
    for word_type in list(totdf.columns.values[:-2]):
        word_type_count[word_type] = (type_list.count(word_type))

    word_type_count['Num_Words'] = numwords
    word_type_count['Num_Chars'] = numchars
    
    # append to dict
    totdf = totdf.append([word_type_count])

# ===============================================

# More exploratory data analysis ================
# Count instance of each word
word_type_count_type, word_type_count_list = [], []
for key, value in word_ref.iteritems():
    word_type_count_type.append(key)
    word_type_count_list.append(len(value))
    
# Dependence on number of characters with numer of followers
sp.ttest_ind(totdf['Num_Chars'], playlist_followers)
# p-value less than 0.05

# Look at dependence of number of chars and followers
plt.figure(292)
plt.scatter(totdf['Num_Chars'], playlist_followers)
slope, intercept, r_value, p_value, slope_std_error = sp.linregress(totdf['Num_Chars'], playlist_followers)
y_predict = intercept + totdf['Num_Chars']*slope
plt.plot(totdf['Num_Chars'], y_predict)
plt.xlim(0, 80); plt.xlabel('Number of Characters', fontsize = 20)
plt.ylim(-0.1e7, 1.1e7); plt.ylabel('Number of Followers', fontsize = 20)

# ========================================================

# Regression ===========================================

# Split into test-train
X_train, X_test, y_train, y_test = train_test_split(totdf, playlist_followers,
                                                    test_size=0.2, random_state=42)

# Train with Linear regression
LinRegress = linear_model.LinearRegression()
LinRegress.fit(X_train, y_train) 
print('Residual sum of squares is %.5e' % np.mean((LinRegress.predict(X_test) 
                                                  - y_test) ** 2))
# 2.03816e+11

# =========================================

# Train with ridge regression ==============
alphas_rr = np.logspace(1, 3, 60)
train_errors_rr, test_errors_rr = [], []
for alpha in alphas_rr:
    clf = linear_model.Ridge(alpha = alpha)
    clf.fit(X_train, y_train) 
    train_errors_rr.append(clf.score(X_train, y_train))
    test_errors_rr.append(clf.score(X_test, y_test))

alpha_optim_rr = alphas_rr[np.argmax(test_errors_rr)]
clf.set_params(alpha = alpha_optim_rr)
clf.fit(X_train, y_train)
print("Optimal regularization parameter : %s" % alpha_optim_rr)
print('Residual sum of squares is %.5e' % np.mean((clf.predict(X_test) - y_test) ** 2))
# 1.57414e+11

plt.rc('ytick', labelsize = 20)
plt.rc('xtick', labelsize = 20)
plt.figure(110); plt.clf()
plt.semilogx(alphas_rr, train_errors_rr, label = 'Train Score', linewidth = 3)
plt.semilogx(alphas_rr, test_errors_rr, label = 'Test score', linewidth = 3)
plt.semilogx(alpha_optim_rr, max(test_errors_rr),'o', label = 'Optimised')
plt.xlabel('alpha', fontsize = 20); plt.ylabel('Score', fontsize = 20)
plt.legend(loc = 2, fontsize = 20); 
plt.title('Ridge Regression Scores', fontsize = 20)

# =====================================


# Train with Lasso regression =========
alphas_l = np.logspace(4, 7, 60)
train_errors_l, test_errors_l = [], []
for alpha in alphas_l:
    las = linear_model.Lasso(alpha = alpha)
    las.fit(X_train, y_train) 
    train_errors_l.append(las.score(X_train, y_train))
    test_errors_l.append(las.score(X_test, y_test))

alpha_optim_l = alphas_l[np.argmax(test_errors_l)]
las.set_params(alpha = alpha_optim_l)
las.fit(X_train, y_train)
print("Optimal regularization parameter : %s" % alpha_optim_l)
print('Residual sum of squares is %.5e' % np.mean((las.predict(X_test) - y_test) ** 2))
# 1.55680e+11

plt.figure(111); plt.clf()
plt.semilogx(alphas_l, train_errors_l, label = 'Train Score', linewidth = 3)
plt.semilogx(alphas_l, test_errors_l, label = 'Test score', linewidth = 3)
plt.semilogx(alpha_optim_l, max(test_errors_l),'o', label = 'Optimised')
plt.xlabel('alpha', fontsize = 20); plt.ylabel('Score', fontsize = 20)
plt.title('Lasso Scores', fontsize = 20)
plt.legend(fontsize = 20)

# ====================================

# Elastic Net Training ===============
alphas = np.logspace(-1, 3, 60)
ratios = np.linspace(0, 1, 20)
train_errors, test_errors = [],[]

# iterate through parameters
for ratio in ratios:
    enet = linear_model.ElasticNet(l1_ratio=ratio)
    alpha_train_errors, alpha_test_errors = [], []
    for alpha in alphas:
        enet.set_params(alpha=alpha)
        enet.fit(X_train, y_train)
        alpha_train_errors.append(enet.score(X_train, y_train))
        alpha_test_errors.append(enet.score(X_test, y_test))
    train_errors.append(alpha_train_errors)
    test_errors.append(alpha_test_errors)
    
i_alpha_ratio_optim = np.unravel_index(np.array(test_errors).argmax(), 
                                    np.array(test_errors).shape) # max because retuerns R^2 value 
ratio_optim = ratios[i_alpha_ratio_optim[0]]
alpha_optim = alphas[i_alpha_ratio_optim[1]]
print("Optimal ratio parameter : %s" % ratio_optim)
print("Optimal regularization parameter : %s" % alpha_optim)

# Estimate the coef_ on full data with optimal regularization parameter
enet.set_params(alpha=alpha_optim, l1_ratio = ratio_optim)
enet.fit(X_train, y_train)
print('Residual sum of squares is %.5e' % np.mean((enet.predict(X_test) - y_test) ** 2))
#  1.57383e+11

plt.figure(112); plt.clf()
for i in range(int(len(ratios)/2)):
    plt.semilogx(alphas, np.array(test_errors)[2*i,:], 
                 label = 'Ratio:' +str(round(ratios[2*i], 4)),
                 color = plt.cm.RdYlBu(ratios[2*i]),
                 linewidth = 3)
plt.legend(loc = 2, fontsize = 16)
plt.xlabel('alpha', fontsize = 20); plt.ylabel('Score', fontsize = 20)
plt.title('Elastic Net Test Scores', fontsize = 20)

# =====================================

# Exain coefficients ==================
colnames = list(totdf.columns.values)
sorted_colnames = [x for (y,x) in sorted(zip(enet.coef_,colnames))]
sorted_coefs = sorted(enet.coef_)

plt.figure(666); plt.clf()
plt.bar(range(len(sorted_coefs)), sorted_coefs)

# ====================================