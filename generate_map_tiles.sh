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

echo "\n\nCREATING TILES E${LON}N${LAT} ZOOM=$ZOOM\n\n"

cd $WORKING_PATH
rm -f map/metadata.json
rm -rf map
echo tl copy -z $ZOOM -Z $ZOOM -b "'${LON} ${LAT} ${LON2} ${LAT2}'" http://95.216.11.110:8080/{z}/{x}/{y}.png file://./map

## START RSYNC (non includere il metadata.json)
