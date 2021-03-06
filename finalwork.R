library(sf)
library(tmap)
library(tmaptools)
library(maptools)
library(plyr)
library(tidyverse)
library(rgdal)
library(spatstat)
library(rgdal)
library(rgeos)
library(raster)
library(adehabitatHR)
library(spdep)
library(classInt)
library(gstat)
library(spgwr)
library(ggcorrplot)

# a function for spatial join
spatialJoin <- function(data1, data2) {
  # join OSM and London boroughs
  joined <- st_join(data1, data2, join = st_within)
  
  countno <- as.data.frame(plyr::count(joined$CODE))
  
  counted <-left_join(data2, countno, by=c("CODE"="x"))
  
  return(counted)
}
# read data 
bikesort <- read_csv("data/bikesort29.csv") #night bike 
shenzhenst <- st_read("data/shenzhen/szarea.shp") #shenzhen in sub-district level
shenzhen <- st_read("data/shenzhen/pj_shenzhen.shp")#shenzhen in district level

# change into polygon
shenzhenstOGR <- as(shenzhenst, "Spatial")
shenzhenOGR <- as(shenzhen, "Spatial")
#read poi files
cinemas <- read_csv("data/POI/cinema_concert.csv") #performing
game <- read_csv("data/POI/game.csv") #gaming
pub_disco <- read_csv("data/POI/pub_disco.csv") #clubs
sports <- read_csv("data/POI/sports.csv") #sports

## manipulate night-time bike data
# Destinations
time=as.POSIXct(bikesort$D_Time) 
D_hour=strftime(time,"%H")
# D_hour<- lapply(D_hour,as.numeric)
D_hour <- data.frame(D_hour = c(D_hour))
bikesort <- cbind(bikesort,D_hour)
bikesort$D_hour <- as.numeric(bikesort$D_hour)

# Origins
time=as.POSIXct(bikesort$Time) 
O_hour=strftime(time,"%H")
O_hour <- data.frame(O_hour = c(O_hour))
bikesort <- cbind(bikesort,O_hour)
bikesort$O_hour <- as.numeric(bikesort$O_hour)

# extract sample data
nighttimebike <-  bikesort[which(bikesort$D_hour< 6 | bikesort$D_hour >= 18),]
samplerate <- 0.02
samplentb <-  nighttimebike[sample(nrow(nighttimebike), nrow(nighttimebike)*samplerate), ]

# pattern anaylysis -- Temporal 
# origins
# plot the frequency of origins
temporal_table_o=as.data.frame(table(bikesort$O_hour))
x <-temporal_table_o$Var1 
plot(temporal_table_o$Freq,type = "o",ylab = 'Frequency',xlab = 'Time'
     ,main = 'Frequency of origins')

axis(1, 1:24)
# destinations
# plot the frequency of returns
temporal_table=as.data.frame(table(bikesort$D_hour))
x <-temporal_table$Var1 
plot(temporal_table$Freq,type = "o",ylab = 'Frequency',xlab = 'Time'
     ,main = 'Frequency of returns')

axis(1, 1:24)
# difference
# calculate the difference between returns and origins
diff_table <- cbind(temporal_table$Var1)
diff_table <- transform(diff_table,diff=0)
for (i in 1:nrow(diff_table)){
  diff_table[i,'diff'] <- temporal_table[i,'Freq'] - temporal_table_o[i,'Freq']
}

# plot the difference
plot(diff_table$diff,type = "o",ylab = 'Difference',xlab = 'Time'
     ,main = 'Difference between returns and origins',xaxt='n',yaxt='n')
y_axis <- c(-200000,-100000,0,100000,200000)
xlim(3,24)
axis(1, 1:24)
options(scipen = 200)
axis(2, y_axis)

# just show the difference froam 3pm-24pm
diff_table_3_24 <- diff_table[3:24,]
plot(diff_table_3_24$diff,type = "o",ylab = 'Difference',xlab = 'Time'
     ,main = 'Difference between returns and origins (3am - 24pm)',xaxt='n')
axis(1,at = 1:22, labels = c(3:24))

# change nightbike data into sf data
samplentbSF <- st_as_sf(samplentb, coords =c("D_X","D_Y"), crs = 4326)
samplentbOGR <- as(samplentbSF, "Spatial")


#KDE

# calculate the KDE of returns of DLB
WGS = "+init=epsg:4326"
shenzhenWGS <- spTransform(shenzhenOGR, WGS)
nightbike.kde.output <- kernelUD(samplentbOGR, h="href", grid = 1000)
nightbike.kde <- raster(nightbike.kde.output)
projection(nightbike.kde) <- CRS("+init=EPSG:4326")
bounding_box <- shenzhenWGS@bbox
nightbike.masked_kde <- mask(nightbike.kde, shenzhenWGS)
# plot the result
tm_shape(nightbike.masked_kde, bbox = bounding_box) + tm_raster("ud", style = "quantile", n = 1000, legend.show = FALSE, palette = "YlGnBu") +
  tm_shape(shenzhenWGS) + tm_borders(alpha=.3, col = "white")+tm_compass(position = c(0.9,0.8)) +
  tm_layout(frame = FALSE)


#calculate KDE result of POIs

# change into sf datatype
cinemasSF <- st_as_sf(cinemas, coords =c("WGS84_X","WGS84_Y"), crs = 4326)
gamesSF <- st_as_sf(game, coords =c("WGS84_X","WGS84_Y"), crs = 4326)
pub_discoSF <- st_as_sf(pub_disco, coords =c("WGS84_X","WGS84_Y"), crs = 4326)
sportsSF <- st_as_sf(sports, coords =c("WGS84_X","WGS84_Y"), crs = 4326)

# change into spatial dataframe
cinemasOGR <- as(cinemasSF, "Spatial")
gameOGR <- as(gamesSF, "Spatial")
pub_discoOGR <- as(pub_discoSF, "Spatial")
sportsOGR <- as(sportsSF, "Spatial")



# performing_KDE
cinemas.kde.output <- kernelUD(cinemasOGR, h="href", grid = 1000)
cinemas.kde <- raster(cinemas.kde.output)
projection(cinemas.kde) <- CRS("+init=EPSG:4326")
bounding_box <- shenzhenWGS@bbox
cinemas.masked_kde <- mask(cinemas.kde, shenzhenWGS)
# plot the KDE result of performing type
tm_kde_cinemas <- tm_shape(cinemas.masked_kde, bbox = bounding_box) + tm_raster("ud", style = "quantile", n = 1000, legend.show = FALSE, palette = "YlGnBu") +
  tm_shape(shenzhenWGS) + tm_borders(alpha=.3, col = "white")+tm_compass(position = c(0.85,0.8)) +
  tm_layout(frame = FALSE)+
  tm_layout("Performing",title.position = c(0.4,0.98)) 
tm_kde_cinemas

# gaming_KDE
games.kde.output <- kernelUD(gameOGR, h="href", grid = 1000)
games.kde <- raster(games.kde.output)
projection(games.kde) <- CRS("+init=EPSG:4326")
bounding_box <- shenzhenWGS@bbox
games.masked_kde <- mask(games.kde, shenzhenWGS)
# plot the KDE result of gaming type
tm_kde_games <- tm_shape(games.masked_kde, bbox = bounding_box) + tm_raster("ud", style = "quantile", n = 1000, legend.show = FALSE, palette = "YlGnBu") +
  tm_shape(shenzhenWGS) + tm_borders(alpha=.3, col = "white")+tm_compass(position = c(0.85,0.8)) +
  tm_layout(frame = FALSE)+
  tm_layout("Gaming",title.position = c(0.4,0.98)) 
tm_kde_games

# clubs_KDE

pub_disco.kde.output <- kernelUD(pub_discoOGR, h="href", grid = 1000)
pub_disco.kde <- raster(pub_disco.kde.output)
projection(pub_disco.kde) <- CRS("+init=EPSG:4326")
bounding_box <- shenzhenWGS@bbox
pub_disco.masked_kde <- mask(pub_disco.kde, shenzhenWGS)
# plot the KDE result of clubs type
tm_kde_pubs <- tm_shape(pub_disco.masked_kde, bbox = bounding_box) + tm_raster("ud", style = "quantile", n = 1000, legend.show = FALSE, palette = "YlGnBu") +
  tm_shape(shenzhenWGS) + tm_borders(alpha=.3, col = "white")+tm_compass(position = c(0.85,0.8)) +
  tm_layout(frame = FALSE)+
  tm_layout("Gaming",title.position = c(0.4,0.98)) 
tm_kde_pubs
# sports_KDE
sports.kde.output <- kernelUD(sportsOGR, h="href", grid = 1000)
sports.kde <- raster(sports.kde.output)
projection(sports.kde) <- CRS("+init=EPSG:4326")
bounding_box <- shenzhenWGS@bbox
sports.masked_kde <- mask(sports.kde, shenzhenWGS)
# plot the KDE result of clubs type
tm_kde_sports <- tm_shape(sports.masked_kde, bbox = bounding_box) + tm_raster("ud", style = "quantile", n = 1000, legend.show = FALSE, palette = "YlGnBu") +
  tm_shape(shenzhenWGS) + tm_borders(alpha=.3, col = "white")+tm_compass(position = c(0.85,0.8)) +
  tm_layout(frame = FALSE)+
  tm_layout("Sports",title.position = c(0.4,0.98)) 
tm_kde_sports
# show all the KDE result in the same window
t_kde <- tmap_arrange(tm_kde_cinemas,tm_kde_games,tm_kde_pubs,tm_kde_sports)
t_kde

# calculate the number of each kind of point in the szst

# dockless bike
table_nbike <- spatialJoin(samplentbSF, shenzhenst)
table_nbike[is.na(table_nbike)] = 0

#show the distribution of night-time bikes
tm_shape(shenzhenstOGR) +
  tm_polygons(col = NA) +
  tm_shape(samplentbOGR) +
  tm_dots(col = 'red') +
  tm_compass()

# performing
table_cinemas <- spatialJoin(cinemasSF, shenzhenst)
table_cinemas[is.na(table_cinemas)] = 0
#show the distribution of performing POI
tm_cinemas <- tm_shape(shenzhenstOGR) +
  tm_polygons(col = NA) +
  tm_shape(cinemasOGR) +
  tm_dots(col = 'blue') +
  tm_layout("Performing",main.title.position = "center") 
tm_cinemas

# games
table_games <- spatialJoin(gamesSF, shenzhenst)
table_games[is.na(table_games)] = 0
#show the distribution of gaming POI
tm_games <- tm_shape(shenzhenstOGR) +
  tm_polygons(col = NA) +
  tm_shape(gameOGR) +
  tm_dots(col = 'blue')+
  tm_layout("Gaming",main.title.position = "center")  
tm_games

# pubs
table_pub_disco <- spatialJoin(pub_discoSF, shenzhenst)
table_pub_disco[is.na(table_pub_disco)] = 0
#show the distribution of clubs POI
tm_pubs <- tm_shape(shenzhenstOGR) +
  tm_polygons(col = NA) +
  tm_shape(pub_discoOGR) +
  tm_dots(col = 'blue') +
  tm_layout("Clubs",main.title.position = "center")
tm_pubs
# sports
table_sports <- spatialJoin(sportsSF, shenzhenst)
table_sports[is.na(table_sports)] = 0
#show the distribution of sports POI
tm_sports <- tm_shape(shenzhenstOGR) +
  tm_polygons(col = NA) +
  tm_shape(sportsOGR) +
  tm_dots(col = 'blue')+
  tm_layout("Sports",main.title.position = "center") 
tm_sports
# show all of them in the same windows
t = tmap_arrange(tm_cinemas,tm_games,tm_pubs,tm_sports)
t
# Moran's I

nb_nb<- poly2nb(shenzhenstOGR, queen = T)

#create a spatial weights matrix object from these weights
nb.lw <- nb2listw(nb_nb, style="C")

#now run a moran's I test on the residuals
#first using queens neighbours
moran.test <- moran.test(table_nbike$freq, nb.queens_weight)
moran.test

#use the localmoran function to generate I for each ward in the city
I_nbike_Local <- localmoran(table_nbike$freq, nb.lw)
table_nbikeOGR <- as(table_nbike, "Spatial")

#show the distribution of local Moran's I 
head(I_nbike_Local)
table_nbikeOGR$bikeI <- I_nbike_Local[,1]
table_nbikeOGR$bikeIz <- I_nbike_Local[,4]

breaks1<-c(-Inf,-2.58,-1.96,1.96,2.58,Inf)
tm_shape(table_nbikeOGR) +
  tm_polygons("bikeIz",
              style="fixed",
              palette="-RdGy",
              breaks = breaks1,
              alpha = 0.7,
              midpoint=NA,
              title="Local Moran's I,\n DLB (Returns) in Shenzhen")+
  tm_layout(legend.format = list(digits=3),legend.position = c(0.6,0),frame = FALSE,title.size = 0.1)+
  tm_compass(position = c(0.85,0.8))


# GWR 

# record the number of each kind of POI in each sub-district
shenzhenst$DLB = table_nbikeOGR$freq
shenzhenst$Performing = table_cinemas$freq
shenzhenst$Gaming = table_games$freq
shenzhenst$Clubs = table_pub_disco$freq
shenzhenst$Sports = table_sports$freq


variables <- c('DLB','Performing','Gaming','Clubs','Sports')

#first drop the geometry column from the dataframe as it will cause problems
tempdf <- st_set_geometry(shenzhenst,NULL)
# calculate the correlation matrix
cormat <- cor(tempdf[variables], use="complete.obs", method="pearson")
# create a new window
plot.new()
# show the correlation heatmap
ggcorrplot(cormat, hc.order = TRUE, type = "lower",
           lab = TRUE) 
# For GWR model
coords_nb <- coordinates(shenzhenstOGR)
GWRbandwidth <- gwr.sel(`DLB` ~ `Performing` + `Gaming` + `Clubs` + `Sports` , data = tempdf, coords=coords_nb,adapt=T)

#run the gwr model
gwr.model = gwr(`DLB` ~ `Performing` + `Gaming` + `Clubs` + `Sports`, data = tempdf, coords=coords_nb, adapt=GWRbandwidth, hatmatrix=TRUE, se.fit=TRUE)

#print the results of the model
gwr.model
# record the results
results<-as.data.frame(gwr.model$SDF)

# save the coeffecient into the original variable
shenzhenstOGR$coefPerforming<-results$Performing
shenzhenstOGR$coefGaming<-results$Gaming
shenzhenstOGR$coefClubs<-results$Clubs
shenzhenstOGR$coefSports<-results$Sports

#run the significance test
sigTest_cinemas = abs(gwr.model$SDF$Performing) -1.96 * gwr.model$SDF$Performing_se
sigTest_games = abs(gwr.model$SDF$Gaming) -1.96 * gwr.model$SDF$Gaming_se
sigTest_pubs_disco = abs(gwr.model$SDF$Clubs) -1.96 * gwr.model$SDF$Clubs_se
sigTest_sports = abs(gwr.model$SDF$Sports) -1.96 * gwr.model$SDF$Sports_se


#store significance results
shenzhenstOGR$SigPerforming<-sigTest_cinemas
shenzhenstOGR$SigGaming<-sigTest_games
shenzhenstOGR$SigClubs<-sigTest_pubs_disco
shenzhenstOGR$SigSports<-sigTest_sports

# show the coeficient
# Performing
tm_coef_Performing <- tm_shape(shenzhenstOGR) +
  tm_polygons(col = "coefPerforming", palette = "-RdBu", alpha = 0.5)+
  tm_legend(position = c(0.65,0.05))+
  tm_compass(position = c(0.85,0.8))+
  tm_layout("Performing",title.position = c(0.4,0.98)) 
tm_coef_Performing
# Gaming
tm_coef_Gaming <-
  tm_shape(shenzhenstOGR) +
  tm_polygons(col = "coefGaming", palette = "-RdBu", alpha = 0.5)+
  tm_legend(position = c(0.65,0))+
  tm_compass(position = c(0.85,0.8))+
  tm_layout("Gaming",title.position = c(0.4,0.98)) 
tm_coef_Gaming
# Clubs
tm_coef_Clubs <- tm_shape(shenzhenstOGR) +
  tm_polygons(col = "coefClubs", palette = "-RdBu", alpha = 0.5)+
  
  tm_legend(position = c(0.65,0))+
  tm_compass(position = c(0.85,0.8))+
  tm_layout("Clubs",title.position = c(0.4,0.98)) 
tm_coef_Clubs
# Sports
tm_coef_Sports <- tm_shape(shenzhenstOGR) +
  tm_polygons(col = "coefSports", palette = "-RdBu", alpha = 0.5)+
  tm_legend(position = c(0.65,0))+
  tm_compass(position = c(0.85,0.8))+
  tm_layout("Sports",title.position = c(0.4,0.98)) 
tm_coef_Sports
# show all the coefficient in one window
tm_coef = tmap_arrange(tm_coef_Performing,tm_coef_Gaming,tm_coef_Clubs,tm_coef_Sports)
tm_coef
# show the significance
# Performing
tm_sig_Performing <- tm_shape(shenzhenOGR)+
  tm_polygons(col = "white")+
  tm_shape(shenzhenstOGR[(shenzhenstOGR@data$SigPerforming>0),]) +
  tm_text("PNAME",size = .6,fontface="bold")+
  tm_polygons(col = "SigPerforming", palette = "Blues", alpha =0.4 )+
  tm_legend(position = c(0.65,0.05))+
  tm_compass(position = c(0.85,0.8))+
  tm_layout("Performing",title.position = c(0.4,0.98))
tm_sig_Performing
# Gaming
tm_sig_Gaming <- tm_shape(shenzhenOGR)+
  tm_polygons(col = "white")+
  tm_shape(shenzhenstOGR[(shenzhenstOGR@data$SigGaming>0),]) +
  tm_text("PNAME",size = .6,fontface="bold")+
  tm_polygons(col = "SigGaming", palette = "Blues", alpha =0.4 )+
  tm_legend(position = c(0.65,0.05))+
  tm_compass(position = c(0.85,0.8))+
  tm_layout("Gaming",title.position = c(0.4,0.98))
tm_sig_Gaming
# Clubs
tm_sig_Clubs <- tm_shape(shenzhenOGR) +
  tm_polygons(col = "white")+
  tm_shape(shenzhenstOGR[(shenzhenstOGR@data$SigClubs>0),]) +
  tm_text("PNAME",size = .6,fontface="bold")+
  tm_polygons(col = "SigClubs", palette = "Blues", alpha = 0.4)+
  tm_legend(position = c(0.65,0.05))+
  tm_compass(position = c(0.85,0.8))+
  tm_layout("Clubs",title.position = c(0.4,0.98))
# Sports
tm_sig_Sports<- tm_shape(shenzhenOGR) +
  tm_polygons(col = "white")+
  tm_shape(shenzhenstOGR[(shenzhenstOGR@data$SigSports>0),]) +
  tm_text("PNAME",size = .6,fontface="bold")+
  tm_polygons(col = "SigSports", palette = "Blues", alpha = 0.4)+
  tm_legend(position = c(0.65,0.05))+
  tm_compass(position = c(0.85,0.8))+
  tm_layout("Sports",title.position = c(0.4,0.98))
# show all the significance coefficient in one window
tm_sig = tmap_arrange(tm_sig_Performing,tm_sig_Gaming,tm_sig_Clubs,tm_sig_Sports)
tm_sig

# show the coefficient and significance coefficient of the same POI in one window
coef_sig_Performing <- tmap_arrange(tm_coef_Performing,tm_sig_Performing)
coef_sig_Gaming <- tmap_arrange(tm_coef_Gaming,tm_sig_Gaming)
coef_sig_Clubs <- tmap_arrange(tm_coef_Clubs,tm_sig_Clubs)
coef_sig_Sports <- tmap_arrange(tm_coef_Sports,tm_sig_Sports)

coef_sig_Performing
coef_sig_Gaming
coef_sig_Clubs
coef_sig_Sports
