###-------------Configure Settings-------------------###
options(scipen=999)

###--------Install packages and load libraries--------------###
#install.packages("dplyr")
#install.packages("sqldf")
#install.packages("fpp2")
#install.packages("caret")
#install.packages("GGally")
#install.packages("ggplot2")
#install.packages("foreign")
#install.packages("MASS")
#install.packages("prophet")
library(caret)
library(fpp2)
library(sqldf)
library(dplyr)
library(GGally)
library(zoo)
library(xts)
library(ggplot2)
library(foreign)
library(MASS)
library(prophet)


###------------------OTHER SETUP------------------###

##-----CREATE REGRESSION FIT PLOTTING FUNCTION-----##
#sourced from: https://sejohnston.com/2012/08/09/a-quick-and-easy-function-to-plot-lm-results-in-r/

regplot <- function (fit) {
  
  require(ggplot2)
  
  ggplot(
    fit$model,
    aes_string(
      x = names(fit$model)[2],
      y = names(fit$model)[1]
    )
  ) + 
    geom_point() +
    stat_smooth(method = "lm", col = "steelblue") +
    labs(
      title = paste(
        "Adj R2 = ",
        signif(summary(fit)$adj.r.squared,5),
        "Intercept =",
        signif(fit$coef[[1]],5 ),
        " Slope =",signif(fit$coef[[2]], 5),
        " P =",signif(summary(fit)$coef[2,4], 5)
      )
    )
}

###-------------Import & Cleanup Data-------------###

data<-read.csv("input.csv")
names(data)[1]<-"date"
names(data)[5]<-"month"
names(data)[22]<-"mon"
#Coerce to factors
cols<-c("dow","dowc","wkd","month","ssn","jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec","sun","mon","tue","wed","thu","fri","sat","hol","ishol","hol3","hol5","hol7","holwknd")
data[cols] <- lapply(data[cols], factor)
data$bkngadj<-data$bkng/data$ssnidx
data<-data[1:1825,]

###-----------EDA-------------------------###

#Check shape of bookings : regular price and seasonally adjusted price

ggplot(data=data, aes(pact, bkng)) +
  geom_point()

ggplot(data=data, aes(pactadj, bkng)) +
  geom_point()

##Here we see that seasonality is already partially priced in by the hotel - as price increases, bookings also increase. This is likely not a reliable assumption for our profit model.

ggplot(data=data, aes(pactadj, bkng)) +
  geom_point()

##Here we see something more logical - a logrithmic relationship between the seasonally adjusted price and bookings. The price adjustment

ggplot(data=data, aes(pactadj, bkngadj)) +
  geom_point()

###----------Feature Extraction-----------###

##LM Models


model01<-lm(bkng~log(pactadj),data=data)

ggplot(data, aes(pactadj, bkng)) +
  geom_point() +
  stat_smooth(method="lm",formula=y~log(x),fill="steelblue")

model02<-lm(bkng~pactadj, data=data)
regplot(model02)

#Reference model with ALL features
model03<-lm(bkng~log(pactadj)+jan+feb+mar+apr+may+jun+jul+aug+sep+oct+nov+sun+mon+tue+wed+thu+fri+sat+ishol+hol3+hol5+hol7+holwknd+vis+vis30+vis45+vis60+vis714+seo+seo30+seo45+seo60+seo714+hit+hit30+hit45+hit60+hit714+pv+pv30+pv45+pv60+pv714+clk+clk30+clk45+clk60+clk714+imp+imp30+imp45+imp60+imp714+cvr+cvr30+cvr45+cvr60+tmin+tmax+prcp+lwsnw+lwsnwdp+hisnwdp,data=data)
summary(model03)

model04<-lm(bkng~log(pactadj)+ssn:tmax+ssn:tmin+ssn:prcp+ssn:hisnwdp+wkd:prcp:tmax+jan:tmax+feb+mar:tmax+apr+may:tmax+jun:fri+jun:sat+jul:fri+jul:sat+aug:fri+aug:sat+sep+oct+nov+dec:sat+dec:fri+sun+mon+tue+wed+thu+ishol+hol3+holwknd+pv45+pv60+imp45+imp714+lwsnwdp, data=data[1:1460,])

#Final Model Outputs
summary(model04)
plot(model04)
CV(model04)

model05<-lm(bkng~log(pactadj)+ssn*tmax+jan*tmax+feb*hisnwdp+mar+apr+may+jul+aug+sep+oct+nov:wkd+sun+wed+thu+fri+sat+ishol+hol3+holwknd+vis+vis30+vis45+vis714+hit+hit60+pv45+clk45+imp45+imp60+imp714+lwsnwdp,
            data=data[1:1460,])
summary(model05)

#Build DF of Squared Residuals from each model
residuals<-data.frame(
  "model"=c(
#    "Model01",
#    "Model02",
    "Model03",
    "Model04",
    "Model05"
    ),
  "sqerror"=c(
#    sum(resid(model01)^2),
#    sum(resid(model02)^2),
    sum(resid(model03)^2),
    sum(resid(model04)^2),
    sum(resid(model05)^2)
    )
  )
 
#Check sum of squared residuals
resplot<-ggplot(data=residuals, aes(model, sqerror))+
  geom_bar(stat="identity",fill="steelblue")
resplot

#Other model fit evaluation metrics
#CV(model01)
#CV(model02)
CV(model03)
CV(model04)
CV(model05)
#checkresiduals(model01)
#checkresiduals(model02)
checkresiduals(model03)
checkresiduals(model04)
checkresiduals(model05)

##-------EVALUATING MODEL PREDICTIVE ACCURACY---------##

#Help here: https://www.youtube.com/watch?v=OwPQHmiJURI

#Cross-validation - historical observations only
set.seed(42)
cvmodel<-train(bkng~log(pactadj)+ssn:tmax+ssn:tmin+ssn:prcp+ssn:hisnwdp+wkd:prcp:tmax+jan:tmax+feb+mar:tmax+apr+may:tmax+jun:fri+jun:sat+jul:fri+jul:sat+aug:fri+aug:sat+sep+oct+nov+dec:sat+dec:fri+sun+mon+tue+wed+thu+ishol+hol3+holwknd+pv45+pv60+imp45+imp714+lwsnwdp,
               data=data[1:1460,],
               method="lm",
               trControl=trainControl(
                 method="cv", number=10,
                 verboseIter=TRUE
               )
)
print(cvmodel)
#Model fit with cross-validation is almost identical to the full regression model, so it's suitable at least for the historical data.


###---------------Forecasting------------###
modelcol<-c("date","bkng","pact","ssnidx","pactadj","ssn","tmax","jan","feb","hisnwdp","mar","apr","may","jun","jul","aug","sep","oct","nov","dec","wkd","sun","mon","wed","thu","fri","sat","ishol","hol3","holwknd","vis","vis30","vis45","vis714","hit","hit60","pv45","clk45","imp45","imp60","imp714","lwsnwdp")
modeldata<-data[modelcol]

#Convert data to time-series vector
tsdata<-ts(modeldata,start=c(2015,1),frequency=365.25)

#Columns we need a ts forecast for:

predictcol<-c("tmax","tmin","prcp","hisnwdp","pv45","pv60","imp45","imp714","lwsnwdp")

#Parameterize frequency for ts vector and forecast horizon
horizon<-365.25

#Subset data for forecasting
fcstpredictors<-data[1:1460,predictcol]

#Create forecasts for predictors with unknown future values
fcsttmax<-    stlf(ts(fcstpredictors$tmax, start=c(2015,1), frequency = horizon), h=horizon)
fcsttmin<-    stlf(ts(fcstpredictors$tmin, start=c(2015,1), frequency = horizon), h=horizon)
fcstprcp<-    stlf(ts(fcstpredictors$prcp, start=c(2015,1), frequency = horizon), h=horizon)
fcsthisnwdp<- stlf(ts(fcstpredictors$hisnwdp, start=c(2015,1), frequency = horizon), h=horizon)
fcstpv45<-    stlf(ts(fcstpredictors$pv45, start=c(2015,1), frequency = horizon), h=horizon)
fcstpv60<-    stlf(ts(fcstpredictors$pv60, start=c(2015,1), frequency = horizon), h=horizon)
fcstimp45<-   stlf(ts(fcstpredictors$imp45, start=c(2015,1), frequency = horizon), h=horizon)
fcstimp714<-  stlf(ts(fcstpredictors$imp714, start=c(2015,1), frequency = horizon), h=horizon)
fcstlwsnwdp<- stlf(ts(fcstpredictors$lwsnwdp, start=c(2015,1), frequency = horizon), h=horizon)

#Add forecasted values to empty rows in master model dataset

data$tmax[1461:1825]<-as.matrix(fcsttmax$mean)
data$tmin[1461:1825]<-as.matrix(fcsttmin$mean)
data$prcp[1461:1825]<-as.matrix(fcstprcp$mean)
data$hisnwdp[1461:1825]<-as.matrix(fcsthisnwdp$mean)
data$pv45[1461:1825]<-as.matrix(fcstpv45$mean)
data$pv60[1461:1825]<-as.matrix(fcstpv60$mean)
data$imp45[1461:1825]<-as.matrix(fcstimp45$mean)
data$imp714[1461:1825]<-as.matrix(fcstimp714$mean)
data$lwsnwdp[1461:1825]<-as.matrix(fcstlwsnwdp$mean)

#The forecast package only works on linear models, so hardcoding the log of seasonally normalized price for use in the forecast.
data$logpactadj<-log(data$pactadj)

#Produce regression forecast for bookings in 2019 using known and forecasted future predictors. As well, implement 0<=x<=90 constraints on regression forecast (real data has some instances of up to 92 bookings when overbooked, so fudging limits to avoid breaking the formula)
a<-0
b<-93
finaldata<-data
finaldata$bkng<-log((finaldata$bkng-a)/(b-finaldata$bkng))
finalmodel<-lm(bkng~logpactadj+ssn:tmax+ssn:tmin+ssn:prcp+ssn:hisnwdp+wkd:prcp:tmax+jan:tmax+feb+mar:tmax+apr+may:tmax+jun:fri+jun:sat+jul:fri+jul:sat+aug:fri+aug:sat+sep+oct+nov+dec:sat+dec:fri+sun+mon+tue+wed+thu+ishol+hol3+holwknd+pv45+pv60+imp45+imp714+lwsnwdp,
               data=finaldata[1:1460,])
summary(finalmodel)
fc<-forecast(finalmodel, newdata=finaldata, h=horizon)
fc$mean<-(b-a)*exp(fc$mean)/(1+exp(fc$mean))+a
fc$lower<-(b-a)*exp(fc$lower)/(1+exp(fc$lower))+a
fc$upper<-(b-a)*exp(fc$upper)/(1+exp(fc$upper))+a

accuracy(fc)

#Add booking forecast to full dataset
data$bkng[1461:1825]<-as.matrix(fc$mean[1461:1825])

###Further validation - check forecast fit against actuals for 2018
test2data<-finaldata[1:1460,]
test2data$bkng[1096:1460]<-""
test2fc<-forecast(finalmodel, newdata=test2data, h=horizon)

#Transform forecasted log bookings to standard unit scale
test2fc$mean<- (b-a)*exp(test2fc$mean)/(1+exp(test2fc$mean))+a
test2fc$lower<-(b-a)*exp(test2fc$lower)/(1+exp(test2fc$lower))+a
test2fc$upper<-(b-a)*exp(test2fc$upper)/(1+exp(test2fc$upper))+a

#Create a new dataframe with actual and fcst bookings
fcvalidation<-data.frame(data$bkng[1096:1460])
names(fcvalidation)[1]<-"actual"
fcvalidation$date<-time(data$date[1096:1460])
fcvalidation$regforecast<-test2fc$mean[1096:1460]
fcvalidation$diffpct<-(fcvalidation$actual-fcvalidation$regforecast)/fcvalidation$actual

#Check summary statistics for the difference
summary(fcvalidation$diffpct)
#So, in aggregate our forecast over-states bookings by +7.5%. Not perfect, but not too shabby!

#Plot daily forecasts
valplot<-ggplot(fcvalidation,aes(date))+
  xlab("2018 Day of Year")+
  ylab("Rooms Booked")+
  geom_line(aes(y=fcvalidation$regforecast, colour="Regression Forecast"))+
  geom_line(aes(y=fcvalidation$actual, colour="Actual"))
valplot

#Plot loess line
valavg<-ggplot(fcvalidation,aes(date))+
  xlab("2018 Day of Year")+
  ylab("Rooms Booked")+
  geom_smooth(aes(y=fcvalidation$regforecast, colour="Regression Forecast"))+
  geom_smooth(aes(y=fcvalidation$actual, colour="Actual"))
valavg

###-----------------------------------------------------------More forecasting - Test Facebook Prophet-----------------------------------------------------###

#Set up data frame for prophet model fitting (https://facebook.github.io/prophet/docs/quick_start.html#r-api)
fbdf<-data[1:1460,]
names(fbdf)[1]<-"ds"
names(fbdf)[7]<-"y"

#Fit model
fbmodel<-prophet(fbdf)

#Predict the future
future<- make_future_dataframe(fbmodel, periods=horizon)
fbfcst<-predict(fbmodel,future)

#Have a look
plot(fbmodel, fbfcst)
prophet_plot_components(fbmodel, fbfcst)

#Now I want to compare the FB Forecast to our regression forecast for a measurable date range - 2018.

fbdf<-data[1:1095,]
names(fbdf)[1]<-"ds"
names(fbdf)[7]<-"y"
fbmodel<-prophet(fbdf)
future<- make_future_dataframe(fbmodel, periods=horizon)
fbfcst<-predict(fbmodel,future)
plot(fbmodel, fbfcst)

#Add 2018 to pre-existing validation data.frame
fcvalidation$fbforecast<-fbfcst$yhat[1096:1460]
names(fcvalidation)[4]<-"regdiffpct"
fcvalidation$fbdiffpct<-(fcvalidation$actual-fcvalidation$fbforecast)/fcvalidation$actual

#Summarize difference
summary(fcvalidation$fbdiffpct)

sum(fcvalidation$regforecast)
sum(fcvalidation$actual)
sum(fcvalidation$fbforecast)

#So, our regression forecast on average is 30% closer to actuals than the Prophet forecast, and the +/-2 SD distance is smaller as well. However, because we just did a cursory overview of Prophet it's possible more tuning could get the two approaches closer in performance.

#Plot daily forecasts
valplot<-valplot+
  geom_line(aes(y=fcvalidation$fbforecast, colour="Facebook Forecast"))
valplot

#Plot weekly trend
valavg<-valavg+
  geom_smooth(aes(y=fcvalidation$fbforecast, colour="Facebook Forecast"))
valavg

###---------------------------------------------------------------BEGIN PROFIT MODEL------------------------------------------------------------------------------------###

#Pass relevant rows (2019 - rows 1461:1825) and columns (ssnidx, pactadj, bkng) to a new data frame

which(colnames(data)=="ssnidx")
which(colnames(data)=="pactadj")
which(colnames(data)=="bkng")

profit<-data[1461:1825,c(1,7,70,71)]

#Profit equation inputs:
a<- -3392.57 #Theoretical fixed daily overhead for the hotel
b<- -0.05 #Adjustment to forecast bookings based on cross-validation results
c<- -50 #Nightly cost to service occupied room
d<- 50 #Nightly per-adult upsell
e<- 2.08 #Avg adults per room booked
f<- -31.85348098 #Log(pactadj) estimate from regression model
g<-93 #Max capacity (+3 to avoid errors from 0 or neg numbers)

#Profit max data frame to append rows to:
profitmax<-data.frame(
  "Date"="",
  "Baseline Bookings"="",
  "Baseline Price"="",
  "Baseline Profit"="",
  "Profit Max Bookings"="",
  "Profit Max Price"="",
  "Profit Max Profit"="",
  stringsAsFactors=FALSE)

#Create marginal returns steps data frame
scenarios<-data.frame("step"=1:81)
scenarios$mult<-seq(0.6,1.4,by=0.01)
scenarios$pactadj<-""
scenarios$pact<-""
scenarios$bkng<-""
scenarios$profit<-""

###---------------------------------------------------------------------BEGIN LOOP-----------------------------------------------------###

### First, mapping out steps from my Excel "pseudo-code" or working model

#For loop to run all 365 days

for(i in 1:365) {
  row<-i
  
  date<-as.character(profit[row,1,])
  bkng<-profit[row,2]*(1+b)
  ssnidx<-profit[row,3]
  pactadj<-profit[row,4]
  scenarios$pactadj<-pactadj*scenarios$mult
  scenarios$pact<-ssnidx*scenarios$pactadj
  scenarios$bkng<-((log(scenarios$pactadj)-log(pactadj))*f)+bkng
  scenarios$profit<-a+(scenarios$pact*scenarios$bkng)+(scenarios$bkng*d*e)+((g-scenarios$bkng)*h)+(scenarios$bkng*c)
  max<-which.max(scenarios$profit)
  profitmax[row,]<-c(date,
                     bkng,
                     scenarios[41,4],
                     scenarios[41,6],
                     scenarios[max,5],
                     scenarios[max,4],
                     scenarios[max,6])
}

###Visualize marginal returns curve for final day in loop
marginalplot<-ggplot(scenarios,aes(pact))+
  xlab("Price")+
  ylab("Profit")+
  geom_point(aes(y=scenarios$profit), col = "steelblue")+
  geom_line(aes(y=scenarios$profit), col = "steelblue")
marginalplot

###Visualize baseline vs. max profit, price

profitmax$doy<-c(1:365)
profitmax$Baseline.Profit<-as.numeric(profitmax$Baseline.Profit)
profitmax$Profit.Max.Profit<-as.numeric(profitmax$Profit.Max.Profit)
profitmax$Baseline.Price<-as.numeric(profitmax$Baseline.Price)
profitmax$Profit.Max.Price<-as.numeric(profitmax$Profit.Max.Price)
profitmax$Baseline.Bookings<-as.numeric(profitmax$Baseline.Bookings)
profitmax$Profit.Max.Bookings<-as.numeric(profitmax$Profit.Max.Bookings)

#Compare baseline & max profit
profitplot<-ggplot(profitmax,aes(doy))+
  xlab("2018 Day of Year")+
  ylab("Profit")+
  geom_smooth(aes(y=profitmax$Baseline.Profit, colour="Baseline Profit"))+
  geom_smooth(aes(y=profitmax$Profit.Max.Profit, colour="Max Profit"))

#Compare baseline & profit max bookings
bookingplot<-ggplot(profitmax,aes(doy))+
  xlab("2018 Day of Year")+
  ylab("Bookings")+
  geom_smooth(aes(y=profitmax$Baseline.Bookings, colour="Baseline Bookings"))+
  geom_smooth(aes(y=profitmax$Profit.Max.Bookings, colour="Profit Max Bookings"))

#Compare baseline & profit max price
priceplot<-ggplot(profitmax,aes(doy))+
  xlab("2018 Day of Year")+
  ylab("Price")+
  geom_smooth(aes(y=profitmax$Baseline.Price, colour="Baseline Price"))+
  geom_smooth(aes(y=profitmax$Profit.Max.Price, colour="Profit Max Price"))

priceplotdaily<-ggplot(profitmax,aes(doy))+
  xlab("2018 Day of Year")+
  ylab("Price")+
  geom_line(aes(y=profitmax$Baseline.Price, colour="Baseline Price"))+
  geom_line(aes(y=profitmax$Profit.Max.Price, colour="Profit Max Price"))

profitplot
bookingplot
priceplot
priceplotdaily


###Baseline Metrics
mean(profitmax$Baseline.Price)
mean(profitmax$Baseline.Bookings)
sum(profitmax$Baseline.Profit)
###Profit Max Metrics
mean(profitmax$Profit.Max.Price)
mean(profitmax$Profit.Max.Bookings)
sum(profitmax$Profit.Max.Profit)

###Summarize Recommended Changes
pricediff<-mean(profitmax$Profit.Max.Price)-mean(profitmax$Baseline.Price)
pricediffpct<-pricediff/mean(profitmax$Baseline.Price)
pricediff
pricediffpct

bookingsdiff<-sum(profitmax$Profit.Max.Bookings)-sum(profitmax$Baseline.Bookings)
bookingsdiffpct<-bookingsdiff/sum(profitmax$Baseline.Bookings)
bookingsdiff
bookingsdiffpct

profitdiff<-sum(profitmax$Profit.Max.Profit)-sum(profitmax$Baseline.Profit)
profitdiffpct<-profitdiff/sum(profitmax$Baseline.Profit)
profitdiff
profitdiffpct

###--------------APPENDIX, CITATIONS, RESOURCES-----------------------------###

#Citations
citation(package="fpp2")
citation(package="base")
citation(package="prophet")
