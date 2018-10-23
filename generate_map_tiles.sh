#!/bin/sh
## creato da marco barbieri, 2018
## licenza GPL versione 3
## genera le tiles della mappa 1 grado per 1 grado

LON=$1
LAT=$2
LON2=$(expr $LON + 1)
LAT2=$(expr $LAT + 1)
echo E${LON}N${LAT}

cd /mnt/volume-fra1-01/tiles_tmp/
tl copy -z 13 -Z 13 -b '${LON} ${LAT} ${LON2} ${LAT2}' 'http://95.216.11.110:8080/{z}/{x}/{y}.png' file://./map
rm map/metadata.json
cd /mnt/volume-fra1-01/
rsync --archive --recursive tiles_tmp/map/ tiles
cd /mnt/volume-fra1-01/tiles_tmp/
rm -rf map

cd /mnt/volume-fra1-01/tiles_tmp/
tl copy -z 14 -Z 14 -b '${LON} ${LAT} ${LON2} ${LAT2}' 'http://95.216.11.110:8080/{z}/{x}/{y}.png' file://./map
rm map/metadata.json
cd /mnt/volume-fra1-01/
rsync --archive --recursive tiles_tmp/map/ tiles
cd /mnt/volume-fra1-01/tiles_tmp/
rm -rf map

cd /mnt/volume-fra1-01/tiles_tmp/
tl copy -z 15 -Z 15 -b '${LON} ${LAT} ${LON2} ${LAT2}' 'http://95.216.11.110:8080/{z}/{x}/{y}.png' file://./map
rm map/metadata.json
cd /mnt/volume-fra1-01/
rsync --archive --recursive tiles_tmp/map/ tiles
cd /mnt/volume-fra1-01/tiles_tmp/
rm -rf map

cd /mnt/volume-fra1-01/tiles_tmp/
tl copy -z 16 -Z 16 -b '${LON} ${LAT} ${LON2} ${LAT2}' 'http://95.216.11.110:8080/{z}/{x}/{y}.png' file://./map
rm map/metadata.json
cd /mnt/volume-fra1-01/
rsync --archive --recursive tiles_tmp/map/ tiles
cd /mnt/volume-fra1-01/tiles_tmp/
rm -rf map
