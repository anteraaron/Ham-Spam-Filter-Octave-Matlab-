%#Turn off pagination of octave
more off;

%#Create log file
log = fopen('log.txt', 'w');

%#Assuming that trec06p is in same directory as main.m
printf('\n\n-----------------Program has started-----------------\n\n');
fprintf(log, '\n\n-----------------Program has started-----------------\n\n');

%#################################################################
%#   SPLIT DATA SET INTO 70-30 TRAINING AND TEST SET RANDOMLY.   #
%#################################################################

%#Notify user that reading file has started.
printf('-->Reading data files...\n\n');
fprintf(log, '-->Reading data files...\n\n');

%#Read the labels file and convert the content to a matrix. 
%#Array A will be ham/spam and Array B will be the filepaths
[A,B] = textread('trec06p/labels', '%s %s');

%#Change file paths relative to this file
B = strrep(B, '..', 'trec06p');

%#Combine the two array to form a matrix.
dataMatrix = [A, B];

%#Get size of matrix
nRows = size(dataMatrix, 1);

%#Print details
printf('\t%d number of files read.\n\n', nRows);
fprintf(log, '\t%d number of files read.\n\n', nRows);

%#Randomly separate 70-30 training and test set
printf('-->Randomly separating 70-30 training and test set...\n\n');
fprintf(log, '-->Randomly separating 70-30 training and test set...\n\n');

%#Randomize row indeces
randRows = randperm(nRows);

%#Create the upperlimit of ranges for 70-30
trainingLimit = floor(nRows * .70);

trainingMatrix = dataMatrix(randRows(1:trainingLimit), :);
testMatrix = dataMatrix(randRows(trainingLimit + 1:end), :);

%#Print details and write to log file
printf('\tSuccess!\n\n');
printf('\t%d - number of training data.\n', size(trainingMatrix, 1));
printf('\t%d - number of test data.\n', size(testMatrix, 1));
printf('\t-----\n');
printf('\t%d - total.\n\n', size(trainingMatrix, 1) + size(testMatrix, 1));

fprintf(log, '\tSuccess!\n\n');
fprintf(log, '\t%d - number of training data.\n', size(trainingMatrix, 1));
fprintf(log, '\t%d - number of test data.\n', size(testMatrix, 1));
fprintf(log, '\t-----\n');
fprintf(log, '\t%d - total.\n\n', size(trainingMatrix, 1) + size(testMatrix, 1));

%#Free up memory
clear A;
clear B;
clear dataMatrix;
clear trainingLimit;
clear randRows;


%#################################################################
%#                  CREATE AND COUNT VOCABULARY                  #
%#################################################################

%#Disable warning  for 'warning: range error for conversion to character value'
warning('off','all');

%#Start creating vocabulary.
printf('-->Creating vocabulary...\n\n');
fprintf(log, '-->Creating vocabulary...\n\n');


%#Total number of training data.
nRows = size(trainingMatrix, 1);

%#Vocabulary array
vocabulary = [];

hamCount = 0;
spamCount = 0;
hamMatrix = [];
spamMatrix = [];
nRows = 500;
for i = 1:nRows
  printf('\t%d out of %d. Reading %s ...\n', i, nRows, trainingMatrix{i,2});
  fprintf(log, '\t%d out of %d. Reading %s ...\n', i, nRows, trainingMatrix{i,2});
  
  %#Open file for reading.
  file = fopen(trainingMatrix{i,2}, 'r');
  
  %#Extract content separated by space and save the trimmed words to cell array.
  content = strtrim(textscan(file, '%s'){1});
  
  %#Close file handler.
  fclose(file);
  
  %#Regular expression to match:
  %#A-Z a-Z
  %#length of 3 to 21
  %#Ends with one (but not including) . , ! ? : ;
  expression = '^[A-Za-z]{3,21}[\.\?\!\,\;\:]{0,1}$';

  %#cellfun means it evaluates every cell in content cell array.
  %#Create a temporary function handle using @(x) which creates an anonymous function that accepts content cell array.
  %#isempty(...) is the body of the anonymous function
  %#This line means that if a cell in  matches the reg ex, isempty will return false, but since we negated it using ~, it will return true.
  %#This means that it will remove strings that does not match the reg ex. Also Converts all strings to lower case.
  extracted = tolower(content(cellfun(@(x)~isempty(regexp(x, expression, 'match')),content)));
  
  %#Remove trailing punctuations in the extracted text
  extracted = regexprep(extracted, "[\.\,\?\!\:\;]", "");
  
  %#Remove strings that contains three consecutive letters
  extracted = regexprep(extracted, '^[a-zA-Z]*([a-z])\1{2,}[a-zA-Z]*$', "");
  extracted = extracted(~cellfun('isempty', extracted));
  
  %#Count no. of ham and spam in emails
  if(strcmp(trainingMatrix(i, 1), 'ham'))
    hamCount++;
  else
    spamCount++;
  endif
  
  if(i == 1)
    hamMatrix(size(extracted, 1)) = 0;
    spamMatrix(size(extracted, 1)) = 0;
    vocabulary = [extracted];
  else
    %#Expand count matrix
    hamMatrix(size(vocabulary, 1) + 1 : size(vocabulary, 1) + size(setdiff(extracted, vocabulary), 1)) = 0;
    spamMatrix(size(vocabulary, 1) + 1 : size(vocabulary, 1) + size(setdiff(extracted, vocabulary), 1)) = 0;
    vocabulary = [vocabulary; setdiff(extracted, vocabulary)];    
  endif
  %#Determine which extracted elements matches the vocabulary to determine which words to increment
  matching = [find(ismember(vocabulary, extracted))];
  %#Create ham spam matrix to tell the number of times a word occurs in spam/ham email
  if(strcmp(trainingMatrix(i, 1), 'ham'))
    hamMatrix(matching) = hamMatrix(matching) + 1;
  else
    spamMatrix(matching) = spamMatrix(matching) + 1;
  endif
  
  %#print details
  printf('\tCurrent vocabulary size: %d \n\n', size(vocabulary, 1));
  fprintf(log, '\tCurrent vocabulary size: %d \n\n', size(vocabulary, 1));
endfor
clear matching;

%#Get words that has occurence of less than 100
removedWords = vocabulary(find(hamMatrix + spamMatrix < 3), 1);

%#Remove top 100 frequent words
threshold = sort(hamMatrix + spamMatrix, 'descend')(1, 200);
removedWords = [removedWords; vocabulary(find(hamMatrix + spamMatrix >= threshold), 1)];

%#Finished creating vocabulary.
printf('-->Removing candidate words from vocabulary...Please wait...\n\n');
fprintf(log, '-->Removing candidate words from vocabulary...Please wait...\n\n');

%#Remove the words from the vocabulary
hamMatrix(find(ismember(vocabulary, removedWords))) = [];
spamMatrix(find(ismember(vocabulary, removedWords))) = [];
vocabulary(find(ismember(vocabulary, removedWords))) = [];

%#Free up memory
clear trainingMatrix;
clear removedWords;
clear expression;

%#Finished creating vocabulary.
printf('-->Finished creating vocabulary. Final vocabulray size is %d\n\n', size(vocabulary, 1));
fprintf(log, '-->Finished creating vocabulary. Final vocabulary size is %d\n\n', size(vocabulary, 1));



%#################################################################
%#              CONSTRUCTING PROBABILITY MATRICES                #
%#################################################################

%# trainingMatrix{i, 1} = returns ham or spam for document i
%# trainingMatrix{i, 2} = returns the file path for document i
%# vocabulary{j, 1} = means word j
%# hamMatrix{i, j} = means if the word j exists in ham document i. 1 if yes, 0 if no
%# spamMatrix{i, j} = means if the word j exists in spam document i. 1 if yes, 0 if no
printf('-->Creating Probability Matrices...\n');
fprintf(log, '-->Creating Probability Matrices...\n');

%#Lambda for lambda smoothing
lambda = 1;

%#Class conditional likelihood for words with lambda smoothing (used logarithm in multiplying lambda and vocabulary for precision)
%#Count word occurence for ham
P_word_given_ham = [(hamMatrix + lambda) / (hamCount + (lambda * size(vocabulary, 1)))];

clear hamMatrix;

%#Count word occurence for spam
P_word_given_spam = [(spamMatrix + lambda) / (spamCount + (lambda * size(vocabulary, 1)))];

clear spamMatrix;


%#Convert the ALL results to logarithm for precision and transpose
%#P(word|ham) and multiplying weight to bias because it is desirable to be able to bias the filter towards classifying messages as legitimate
weight = 1.03; %#tuning knob

%#P(word|ham)
P_word_given_ham = reallog(P_word_given_ham * weight);
P_word_given_ham = P_word_given_ham';
%#P(word|spam)
P_word_given_spam = reallog(P_word_given_spam);
P_word_given_spam = P_word_given_spam';
%#P(Ham)
P_ham = reallog(hamCount) - reallog((hamCount + spamCount));
%#P(Spam)
P_spam = reallog(spamCount) - reallog((hamCount + spamCount));

printf('\t\tP(Ham): %d\n', exp(P_ham));
fprintf(log, '\t\tP(Ham): %d\n', exp(P_ham));

printf('\t\tP(Spam): %d\n\n', exp(P_spam));
fprintf(log, '\t\tP(Spam): %d\n\n', exp(P_spam));

%#Close program if training data set is not Ok
if(hamCount == 0)
  printf('-->Training set does not contain ham emails...\n');
  printf('-->Training Failed. Program will exit...\n\n');
  
  fprintf(log, '-->Training set does not contain ham emails...\n');
  fprintf(log, '-->Training Failed. Program will exit...\n\n');
  exit;
elseif(spamCount == 0)
  printf('-->Training set does not contain spam emails...\n');
  printf('-->Training Failed. Program will exit...\n\n');
  
  fprintf(log, '-->Training set does not contain spam emails...\n');
  fprintf(log, '-->Training Failed. Program will exit...\n\n');
  exit;
endif

printf('-----------------Training has finished!-----------------\n\n');
fprintf(log, '-----------------Training has finished!-----------------\n\n');




%#################################################################
%#           USING NAIVE BAYESIAN CLASSIFIER TO TEST             #
%#################################################################
printf('-->Start classifying test set...\n\n');
fprintf(log, '-->Start classifying test set...\n\n');

%#Set number of rows as the number of testMatrix documents
nRows = size(testMatrix, 1);

%#Create results file
results = fopen('results.txt', 'w');
fprintf(results, '-->Start classifying test set...\n\n');

%#Classification details
truePositives = 0;
trueNegatives = 0;
falsePositives = 0;
falseNegatives = 0;
nRows = 50;
for i = 1:nRows
  printf('\t%d out of %d. Processing %s ...\n', i, nRows, testMatrix{i,2});
  fprintf(log, '\t%d out of %d. Processing %s ...\n', i, nRows, testMatrix{i,2});
  fprintf(results, '\t%d out of %d. Processing %s ...\n', i, nRows, testMatrix{i,2});
  
  printf('\t\tActual label: %s\n', testMatrix{i,1});
  fprintf(log, '\t\tActual label: %s\n', testMatrix{i,1});
  fprintf(results, '\t\tActual label: %s\n', testMatrix{i,1});
  
  %#Open file for reading.
  file = fopen(testMatrix{i,2}, 'r');
  
  %#Extract content separated by space and save the trimmed words to cell array.
  content = strtrim(tolower(textscan(file, '%s'){1}));
  
  %#Remove trailing punctuations in the extracted text
  content = regexprep(content, "[\.\,\?\!\:\;]", "");
  
  %#Close file handler.
  fclose(file);
  
  %#Get words that are existing in the vocabulary
  members = ismember(vocabulary, content);
  
  %#Find indeces of rows that is 1 or 0 (exist in the class or not)
  A = find(members);
  
  %#Get the P(word_i|ham)
  P_word_i_given_ham = [P_word_given_ham(A,1)];
  
  
  %#Get the P(word_i|spam)
  P_word_i_given_spam = [P_word_given_spam(A,1)];
  
  %#Free up memory
  clear A;
  
  %#Get the denominator of the bayesian classifier
  denominator = exp(sum(P_word_i_given_ham) + P_ham) + exp(sum(P_word_i_given_spam) + P_spam);
  
  %#Ham bayesian classifier result
  ham = exp((sum(P_word_i_given_ham) + P_ham) - reallog(denominator));
  %#Spam bayesian classifier result
  spam = exp((sum(P_word_i_given_spam) + P_spam) - reallog(denominator));
  
  %#Convert results to percentage
  ham = ham * 100;
  spam = spam * 100;
  
  %#Precision threshold
  if (ham >= 100 - 0.001 || ham == Inf)
    ham = 100;
    spam = 0;
  elseif (spam >= 100 - 0.001 || spam == Inf)
    spam = 100;
    ham = 0;
  endif
  
  %#Decide wether the mail is ham or spam
  if(ham >= spam)
    predicted = 'ham';
  else
    predicted = 'spam';
  endif
  
  %#Count the number of TP, TN, FP, FN
  label = 'n/a';
  if(strcmp(testMatrix(i,1), 'spam') && strcmp(predicted, 'spam'))
    truePositives++;
    label = 'True Positive';
  elseif(strcmp(testMatrix(i,1), 'ham') && strcmp(predicted, 'ham'))
    trueNegatives++;
    label = 'True Negative';
  elseif(strcmp(testMatrix(i,1), 'ham') && strcmp(predicted, 'spam'))
    falsePositives++;
    label = 'False Positive';
  elseif(strcmp(testMatrix(i,1), 'spam') && strcmp(predicted, 'ham'))
    falseNegatives++;
    label = 'False Negative';
  endif
 
  %#print details to console and log file
  printf('\t\tHam Percentage = %d%% \n', ham);
  fprintf(log,'\t\tHam Percentage = %d%% \n', ham);
  printf('\t\tSpam Percentage = %d%% \n', spam);
  fprintf(log,'\t\tSpam Percentage = %d%% \n', spam);
  printf('\t\tPredicted label: %s\n', predicted);
  fprintf(log, '\t\tPredicted label: %s\n', predicted);
  printf('\t\tType: %s\n\n', label);
  fprintf(log, '\t\tType: %s\n\n', label);
  
  %#Save to results
  fprintf(results,'\t\tHam Percentage = %d%% \n', ham);
  fprintf(results,'\t\tSpam Percentage = %d%% \n', spam);
  fprintf(results, '\t\tPredicted label: %s\n', predicted);
  fprintf(results, '\t\tType: %s\n\n', label);
  
endfor


%#Summary of testing
fprintf('--------------------Summary--------------------\n\n');
fprintf(log, '--------------------Summary--------------------\n\n');
fprintf(results, '--------------------Summary--------------------\n\n');

%#Computer for recall and precision
precision = truePositives/(truePositives + falsePositives);
recall = truePositives/(truePositives + falseNegatives);

%#Console
printf('\tTrue Positives (Spam classified as spam) = %d\n', truePositives);
printf('\tTrue Negatives (Ham classified as ham) = %d\n', trueNegatives);
printf('\tFalse Positives (Ham misclassified as spam) = %d\n', falsePositives);
printf('\tFalse Negatives (Spam misclassified as ham) = %d\n\n', falseNegatives);
printf('\tCorrectly classified emails (True Positives & True Negatives) = %d (%d%%)\n', truePositives + trueNegatives, ((truePositives + trueNegatives)/nRows)*100);
printf('\tMisclassified emails (False Positives & False Negatives) = %d(%d%%)\n', falsePositives + falseNegatives, ((falsePositives + falseNegatives)/nRows)*100);
printf('\tPrecision (%% of positive predictions were correct) = %d (%d%%)\n', precision, precision*100);  
printf('\tRecall (%% of positive cases catched) = %d (%d%%)\n', recall, recall*100);


%#Log File
fprintf(log,'\tTrue Positives (Spam classified as spam) = %d\n', truePositives);
fprintf(log, '\tTrue Negatives (Ham classified as ham) = %d\n', trueNegatives);
fprintf(log, '\tFalse Positives (Ham misclassified as spam) = %d\n', falsePositives);
fprintf(log, '\tFalse Negatives (Spam misclassified as ham) = %d\n\n', falseNegatives);
fprintf(log, '\tCorrectly classified emails (True Positives & True Negatives) = %d (%d%%)\n', truePositives + trueNegatives, ((truePositives + trueNegatives)/nRows)*100);
fprintf(log, '\tMisclassified emails (False Positives & False Negatives) = %d(%d%%)\n', falsePositives + falseNegatives, ((falsePositives + falseNegatives)/nRows)*100);
fprintf(log, '\tPrecision (%% of positive predictions were correct) = %d (%d%%)\n', precision, precision*100);  
fprintf(log, '\tRecall (%% of positive cases catched) = %d (%d%%)\n', recall, recall*100);


%#Results File
fprintf(results,'\tTrue Positives (Spam classified as spam) = %d\n', truePositives);
fprintf(results, '\tTrue Negatives (Ham classified as ham) = %d\n', trueNegatives);
fprintf(results, '\tFalse Positives (Ham misclassified as spam) = %d\n', falsePositives);
fprintf(results, '\tFalse Negatives (Spam misclassified as ham) = %d\n\n', falseNegatives);
fprintf(results, '\tCorrectly classified emails (True Positives & True Negatives) = %d (%d%%)\n', truePositives +trueNegatives, ((truePositives + trueNegatives)/nRows)*100);
fprintf(results, '\tMisclassified emails (False Positives & False Negatives) = %d(%d%%)\n', falsePositives +falseNegatives, ((falsePositives + falseNegatives)/nRows)*100);
fprintf(results, '\tPrecision (%% of positive predictions were correct) = %d (%d%%)\n', precision, precision*100);  
fprintf(results, '\tRecall (%% of positive cases catched) = %d (%d%%)\n', recall, recall*100);


%#Close results file
fclose(results);
%#Close log file
fclose(log);