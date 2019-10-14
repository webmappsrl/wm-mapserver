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

echo "CREATING TILES LON:$LON-$LON2 LAT:$LAT-$LAT2 ZOOM:$ZOOM"

cd $WORKING_PATH
echo tl copy -z $ZOOM -Z $ZOOM -b "$LON $LAT $LON2 $LAT2" http://localhost:8080/{z}/{x}/{y}@2x.png file://./map
tl copy -z $ZOOM -Z $ZOOM -b "$LON $LAT $LON2 $LAT2" http://localhost:8080/{z}/{x}/{y}@2x.png file://./map &> /dev/null

## START RSYNC (non includere il metadata.json)
echo rm -f map/metadata.json
rm -f map/metadata.json &> /dev/null
