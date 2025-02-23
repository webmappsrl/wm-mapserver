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
rm -rf map
## comandi per tiles a doppia risoluzione @2x
#echo tl copy -z $ZOOM -Z $ZOOM -b "$LON $LAT $LON2 $LAT2" http://localhost:8080/{z}/{x}/{y}@2x.png file://./map
#tl copy -z $ZOOM -Z $ZOOM -b "$LON $LAT $LON2 $LAT2" http://localhost:8080/{z}/{x}/{y}@2x.png file://./map &> /dev/null
## comandi per tiles a risoluzione normale:
echo tl copy -z $ZOOM -Z $ZOOM -b "$LON $LAT $LON2 $LAT2" http://localhost:8080/{z}/{x}/{y}.png file://./map
tl copy -z $ZOOM -Z $ZOOM -b "$LON $LAT $LON2 $LAT2" http://localhost:8080/{z}/{x}/{y}.png file://./map &> /dev/null

## START RSYNC (non includere il metadata.json)
echo rm -f map/metadata.json
rm -f map/metadata.json &> /dev/null
echo rsync -avz map/ $TILES_REMOTE_PATH
rsync -avz map/ $TILES_REMOTE_PATH &> /dev/null
echo psql -U webmapp -d general -h localhost -c "update grid_1x1 set z$ZOOM = CURRENT_DATE WHERE grid_1x1.left = $LON AND grid_1x1.bottom = $LAT;"
psql -U webmapp -d general -h localhost -c "update grid_1x1 set z$ZOOM = CURRENT_DATE WHERE grid_1x1.left = $LON AND grid_1x1.bottom = $LAT;" &> /dev/null
