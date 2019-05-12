#!/bin/sh
## creato da marco barbieri, 2018
## licenza GPL versione 3
## genera le tiles della mappa 1 grado per 1 grado

## PARAMETERS
## 1 LON
## 2 LAT
## 3 ZOOM
## 4 WORKING_PATH
## 5 TILES_REMOTE_PATH

LON=$1
LAT=$2
LON2=$(expr $LON + 1)
LAT2=$(expr $LAT + 1)
ZOOM=$3
WORKING_PATH=$4
TILES_REMOTE_PATH=$5

echo "CREATING TILES LON:$LON-$LON2 LAT:$LAT-$LAT2 ZOOM:$ZOOM"

cd $WORKING_PATH
rm -rf "$LON"-"$LAT".mbtiles
tl copy -z $ZOOM -Z $ZOOM -b "$LON $LAT $LON2 $LAT2" http://localhost:8080/{z}/{x}/{y}.png mbtiles://./"$LON"-"$LAT".mbtiles

## START RSYNC
rsync -avz "$LON"-"$LAT".mbtiles $TILES_REMOTE_PATH
psql -U webmapp -d general -h localhost -c "update grid_1x1 set z$ZOOM = CURRENT_DATE WHERE grid_1x1.left = $LON AND grid_1x1.bottom = $LAT;"
