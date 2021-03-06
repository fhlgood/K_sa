library(data.table)
library(lubridate)
train <- data.table(train)
test <- data.table(test)

# a function to count number of words describing colors
word_count <- function(x){
    cleaned <- gsub("/", " ", x)
    parsed  <- strsplit(cleaned, " ")
    count <- length(unlist(parsed))
return(count)    
}

# create a name frequency table
train[, INI := substr(Name, 1, 1)]
train[INI == "3", Name := "Buster"]
train[INI == "'", Name := "Stache"]
train[INI == " ", Name := c("Joanie", "Mario")]
train[, INI := substr(Name, 1, 1)]

names <- c(train$Name)
name_freq <- table(names)/length(names)

# create a color frequency table
colors <- c(train$Color)
colors <- gsub("/", " ", colors)
split_col <- unlist(strsplit(colors, " "))
col_freq <- table(split_col)/length(split_col)

# a clean function for training and testing
clean <- function(df){
    dt <- data.table(df)
    # create a new feature named 1:Yes, 0:No
    cat("simplifying names...\n")
    dt[INI == "", named := 0]
    dt[INI != "", named := 1]
    
    # parse date
    cat("parsing date...\n")
    dt[, DateTime:= ymd_hms(DateTime)]
    dt[, time := .(hour(DateTime) + minute(DateTime)/60)]
    dt[, year := factor(lubridate::year(DateTime))]
    dt[, month := factor(lubridate::month(DateTime))]
    dt[, day := as.numeric(lubridate::day(DateTime))]
    dt[, weekday := lubridate::wday(DateTime)]
    
    # parse sex and status
    cat("parsing sex and status...\n")
    dt[, sex := "Unknown"]
    dt[SexuponOutcome %like% "Male", sex := "Male"]
    dt[SexuponOutcome %like% "Female", sex := "Female"]
    
    dt[, status := "Unknown"]
    dt[SexuponOutcome %like% "Neutered", status := "Sterilized"]
    dt[SexuponOutcome %like% "Spayed", status := "Sterilized"]
    dt[SexuponOutcome %like% "Intact", status := "Intact"]
    
    # form age in days
    cat("transform age into days...\n")
    dt[AgeuponOutcome == "", AgeuponOutcome := "unknown unknown"]
    parsed_age <- do.call(rbind, sapply(dt[, AgeuponOutcome], strsplit, " "))
    dt[, c("num", "unit") := .(parsed_age[, 1], parsed_age[, 2])]
    dt[unit %like% "year", age := as.numeric(num)*365]
    dt[unit %like% "month", age := as.numeric(num)*30.5]
    dt[unit %like% "week", age := as.numeric(num)*7]
    dt[unit %like% "day", age := as.numeric(num)]
    dt[unit == "unknown", age := NA]
    
    # paring breed
    cat("dividing breed groups...\n")
    dt[Breed %like% "Mix", Breed := "Mix"]
    dt[!Breed %like% "Mix", Breed := "Pure"]
    
    # simplify color
    cat("simplifying colors into numbers...\n")
    color_count <- vector("numeric", length = nrow(dt))
    for(i in seq_along(dt[, Color])){
        color_count[i] <- word_count(dt[i, Color])
    }
    dt[, color := .(color_count)]
    
    # further categorizing color.....
    cat("calculating color frequencies...\n")
    color_f <- vector("numeric", length = nrow(dt))
    dt[, Color := gsub("/", " ", Color)]
    for(i in 1:nrow(dt)){
        color_p <- unlist(strsplit(dt[i, Color], " "))
        color_f[i] <- sum(col_freq[color_p])
    }
    dt[, color_freq := .(color_f)]

    # drop orginal features
    cat("dropping orginal features...\n")
    if("OutcomeType" %in% colnames(df)){
        print("training set")
        dt <- dt[, .(OutcomeType, AnimalType, named, Breed, #to keep
                     year, month, day, weekday, age, color_f,
                     time, status)]
        to_factors <- c("OutcomeType", "AnimalType","named", "Breed",
                        "status")
    } else {
        print("testing set")
        dt <- dt[, .(AnimalType, named, Breed, year, # to keep
                     month, day, weekday, age, color_f, time,
                     status)]
        to_factors <- c("AnimalType", "named", "Breed",
                        "status")
    }
    
    # convert to factor
    for(col in to_factors){
        print(paste("converting to factors...", col))
        set(dt, j = col, value = as.factor(dt[[col]]))
    }
    
    for_imp <- which(is.na(dt), arr.ind = T)
    cat("these missing values need to be imputed: \n")
    print(for_imp)
return(dt)
}

dt.train <- clean(train)
dt.test <- clean(test)
