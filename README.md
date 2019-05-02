# Hotel Price Recommendation
## Introduction
The objective for this project is to recommend optimal pricing in order to maximize profit for a local hotel owner. I was fortunate enough to be able to partner with a local ML startup for this project, and the foundational data used for the exercise was real historical data from one of their clients - a local hotel owner. In order to preserve privacy, the real prices have been transformed and the data provided does not contain any identifiable attributes.

This repository is specifically related to enhancements to a previous project. For a full overview of the initial approach, please visit https://github.com/cmeade001/hotel-price-recommender.

## Approach
The approach for this project can be boiled down to 4 steps:
1. Determine the relationship between the independent variable Price, and the dependent variable Rooms Booked. (Using multiple-regression model's regression coefficient for price)
2. Establish a baseline forecast for Rooms Booked assuming constant price.
3. Determine expected profit for the baseline forecast, using additional inputs for a comprehensive profit calculation.
4. Compute resultant profit from changes to the independent variable price, given the relationship between price, rooms booked, and profit.

## Project Phases
1. Data Collection, Cleanup & Exploration
2. Feature Extraction & Model Validation
3. Forecasting
4. Marginal Returns
5. Optimal Price & Maximum Profit Outputs

## Data Collection, Cleanup & Exploration
One primary objective for the V2 of this project was to procure granular bookings data from the customer, and build individual forecasts and profit variables for each room type. Unfortunately, the customer was unable to provide room-type granularity for historical bookings data, so this was one failure in the overall scope of enhancements I'd initially planned for V2. However, in addition to the base data from the initial project, I was able to add several additional attributes, most of which ended up as features in the enhanced regression model:

1. **Seasonality Index** - This will be discussed later, but was the single most helpful attribute in improving model fit and forecast accuracy.
2. **Weather Data** - See references for a link to NOAA resources. Pulled in precipitation, temperature and nearby snow accumulation for winter months
3. **Additional Local Event Data** - Hotel bookings are influenced by local, regional and national events. For V2, I captured some of the smaller / more local events I missed in V1, and this aided in forecasting.
4. **Revised Lagged Predictor Windows** - Added new T-7-14 and T-14-30 windows for lagged predictors, which proved more helpful for web metrics than others

## Normalization approach
Day of week is more important than date of the year (apart from several holidays) in predicting rooms booked for this hotel. So, my normalization approach was to track seasonality for the nth occurrence of each day of the week: eg 1st Friday, 2nd Friday, -> 52nd Friday. Then, I averaged 5 years of historical bookings data for each [Day of Week x Occurrence in Cal Yr] into an index by dividing the average daily bookings by the annual average 1-day bookings. The output is a range of values from roughly ~0.5 -1.5. This is the booking seasonality index. "pactadj" in the dataset is just the actual price for each day divided by that day's booking seasonality index.

This approach has provided a logarithmic relationship between price and bookings, which is much more in-line with expectations. An added benefit of this process is the model fit - in the old linear approach our adjusted r-square was ~55.7% including all predictors. In the new approach, adjusted r-square jumped to 67% with just log(normalized price) as a predictor. Adding other predictors got us up to 82.2%

Finally, with price normalized the final model coefficient for price : bookings is negative, which is a key enhancement. In V1, I had to make an arbitrary manual adjustmenet to the price coefficient in order to use it to compute the different profit scenarios (result to bookings from changing price). In the new model, it is appropriate to use the model coefficient for price as an input to the final profit calculation, without making any manual transformations.

## Forecasting Approach
In V2, you'll find R code from investigating two primary packages for forecasting - FPP2, built by Rob Hyndman. And Prophet, build by Facebook. I found both to be very useful and have pros and cons - Prophet was a little more user-friendly and didn't require as much knowledge, but in my limited exploration also seemed slightly less flexible. While FPP2 is a little trickier to use, it also allowed me to do two key things I couldn't with Prophet: implement upper and lower limits on the forecast (eg: can't book more than 90 rooms or fewer than 0). As well, I was able to use my regression model to forecast with FPP2, and it wasn't clear whether Prophet allows forecasting with regression.

More details as follow:

### Regression Forecast in FPP2
* Forecast() is only configured to work with linear regression models. To get around this, I had to hardcode log(seasonally normalized price) into a new column and substitute this hardcoded column to the lm model
* Implementing min, max bounds for the forecast package requires transformation of the y value to a log scale with a formula to input the bounds during log transformation, and then exponentiating the output. The problem with this approach for a regression model is that it presumes the model is built on the log-transformed y value, which slightly alters the fit of our chosen regression approach. In this case, the adjusted r-squared only decreased from 82.26 -> 80.65%. So, still a great fitting model, but worth noting that the approach in general feels like a hack and could cause issues for other models. Once the model is fit, the forecast package produces forecasted values on the log scale and then another formula is applied to the forecast output to get back to our original scale, with min, max bounds now applied.
* A final issue with using the regression model for forecasting is that regardless how well it performs during cross-validation, the future dates will still be using forecasted values for a subset of the model's predictors. So, we won't truly know how well the forecast performs until later. But, this would technically also be true of a univariate time-series forecast for rooms booked

### Facebook Prophet
* I also fit a model using Facebook Prophet, just to try it out. It's actually a really cool function, though from reading the documentation it seems like it's not quite as flexible as the forecast() package in r. The pros relative to the forecast package however are the model object is actually a lot more intuitive in FB prophet - you can explore it and actually get a pretty good understanding of the seasonalities and trends in the data. In my case, the model easily picked out the annual and weekly cyclical seasonality, which is pretty cool. Not unlike similar functionality in forecast() but a bit more plug-and-play - basically it seems like the Prophet package does more work with less user input and understanding. 
* Our regression forecast on average is 30% closer to actuals than the Prophet forecast, and the +/-2 SD distance is smaller as well. However, because we just did a cursory overview of Prophet it's possible more tuning could get the two approaches closer in performance. For instance, much of the overprediction in the FB model could be resolved by enforcing min/max constraints as we did in the regression forecast, and this alone could make the performance much better. Worth saving this insight for a rainy day, since it's possible the predictive capability of the regression forecast will be much reduced for future dates.

### Forecast Conclusions
A couple of other callouts for forecasting with regression. The main constraing with this approach is that regression models require contemporary observations of predictors in order to provide a prediction. This means that any feature in your model which you can't know in advance is going to limit your ability to forecast with your model. In our case, the final model fromt he V2 project used mostly features which can be known in advance - price, seasonality, holidays, etc. However, some features couldn't - temperature, snow accumulation, web visits, among others. The way I got around this was to produce univariate time-series forecasts to fabricate future observations of these attributes, and then add the forecasted values to the data frame used for the final regression forecast of rooms booked. In the end, forecasting with regression got our mean VtF for a 2018 cross-validation exercise to +/-8%, vs. +/-40% in V1 - a pretty significant lift. But, we won't know until the end of 2019 whether using forecasted predictors as described above led to decreased forecast performance.

## Calculating Max Profit
This is probably the enhancement which is least impressive to everyone else and most exciting for me. I do not have any kind of programming background, and the task of writing a function which would:
1. Produce simulations
2. Find the most optimal point in the simulation and return the associated values
3. Repeat for all days in the forecast horizon
Was very daunting to me. But I did it! So while it's unlikely that anyone tried to use my r script from the V1 project and got far enough to be frustrated with how manual the previous simulations were, if any such person is out there, try the new script and you'll be very pleased :)

The thing I like best about the new automated approach to profit-maximization simulations is that it enables the startup I'm working with to adjust any inputs and produce all new recommendations on the fly in real time. Including:

1. Profit inputs (like fixed costs, variable labor costs, upsell opportunities for guests, etc.)
2. Model coefficients - so if we continue improving the model or adding granularity, the idea is to return the latest coefficient for price rather than hardcoding (though since it's pulling from a model matrix object if new features get added it'll break)
3. Range of output values - so if we wanted to remove the +/-40% constraint on price changes as we begin to trust the model more, it's 1 line of code to change.

### Conclusions
While the conclusions from the model output are heavily influenced by the profit formula inputs, the outputs are very simple to understand. The core summary is that over the course of 2019, this exercise resulted in a recommendation to increase price by an average of 19% in order to drive an extra $575k in profit. This would result in -5% fewer total bookings, but again coems with a 15% increase in profit.

One feature of V2 I'm particularly pleased with is that the model no longer recommends to increase profit for every day of the year. The log scale of price : bookings coupled with more nuanced profit formula inputs resulted in a much more realistic set of daily pricing recommendations. This opens up one additional use-case for the model apart from just aiding in the customer's bi-annual price-setting cadence - that is, it can actually provide the customer a recommendation for the magnitude of promotions which would yield additional bookings, and forecast the results. So it can now be used in two important decision processes for the customer.

## References
* Hyndman, R.J., & Athanasopoulos, G. (2018) Forecasting: principles and practice, 2nd edition, OTexts: Melbourne, Australia. OTexts.com/fpp2. Accessed on 3/9/18
* Rob Hyndman (2018). fpp2: Data for "Forecasting: Principles and Practice" (2nd Edition). R package version 2.3.  https://CRAN.R-project.org/package=fpp2
* R Core Team (2018). R: A language and environment for statistical computing. R Foundation for Statistical Computing, Vienna, Austria. URL https://www.R-project.org/.
* NOAA’s self-service tools for weather data by zip code was MUCH better than I expected and had heard it would be. Assuming it’s best for US geos since it’s a federal agency, but within US makes things super easy: https://www.climate.gov/maps-data/dataset/past-weather-zip-code-data-table

