#!/bin/sh
## creato da marco barbieri, 2018
## licenza GPL versione 3
## crea sfumo e curve di livello 1 grado per 1 grado

## TODO struttura della WORKING_PATH se non esistesse
## TODO Parametrizzare i parametri della connessione PostGis

## PARAMETRI
## 1 LON
## 2 LAT
## 3 WORKING PATH

LON=$1
LAT=$2
LON2=$(expr $LON + 1)
LAT2=$(expr $LAT + 1)
echo "PROCESSING SQUARE LON:$LON} LAT:$LAT"

## Valore iniziale $HOME/mapdata
WORKING_PATH=$3

rm -f $WORKING_PATH/hs/10m/*
rm -f $WORKING_PATH/slope/10m/*

psql -U webmapp -d general -h localhost -c "TRUNCATE contourlines_hr;"
psql -U webmapp -d general -h localhost -c "COPY (select id from grid where ST_Intersects(grid.geom,ST_SetSRID(ST_GeomFromText('POLYGON((${LON} ${LAT},${LON} ${LAT2},${LON2} ${LAT2},${LON2} ${LAT},${LON} ${LAT}))'),4326)) IS TRUE) TO '/tmp/E${LON}N${LAT}.txt';"

while read dem
do
  rm $WORKING_PATH/dem/temp/*
# creo i file geojson per clippare raster e curve di livello:
  echo "*************** create clip geojson ${dem}"
  rm $WORKING_PATH/dem/box/${dem}.geojson $WORKING_PATH/dem/box/${dem}buf.geojson $WORKING_PATH/dem/box/${dem}wmbuf.geojson
  psql -U webmapp -d general -h localhost -c "UPDATE grid SET done = 'yes' WHERE id = '${dem}'"
  ogr2ogr -f GeoJSON $WORKING_PATH/dem/box/${dem}.geojson "PG:host=localhost dbname=general user=webmapp" -sql "select geom, id from grid where id = '${dem}'"
  ogr2ogr -f GeoJSON $WORKING_PATH/dem/box/${dem}wm.geojson "PG:host=localhost dbname=general user=webmapp" -sql "select st_transform(st_setsrid(geom,4326),3857) as geom, id from grid where id = '${dem}'"
  ogr2ogr -f GeoJSON $WORKING_PATH/dem/box/${dem}buf.geojson "PG:host=localhost dbname=general user=webmapp" -sql "select ST_Buffer(geom, 0.005, 'join=mitre mitre_limit=5.0') as geom, id from grid where id = '${dem}'"
  ogr2ogr -f GeoJSON $WORKING_PATH/dem/box/${dem}wmbuf.geojson "PG:host=localhost dbname=general user=webmapp" -sql "select ST_Buffer(st_transform(st_setsrid(geom,4326),3857), 100, 'join=mitre mitre_limit=5.0') as geom, id from grid where id = '${dem}'"
# croppo i dem originali di mondo, europa, europa hr
  echo "*************** crop original dem ${dem} -> world e deu e deu_hgt"
  gdalwarp -s_srs EPSG:4326 -t_srs EPSG:3857 -crop_to_cutline -cutline $WORKING_PATH/dem/box/${dem}buf.geojson -of GTiff -tr 25 25 -r cubicspline $WORKING_PATH/dem/world_original/mosaic.vrt $WORKING_PATH/dem/temp/world.tif
  gdalwarp -s_srs EPSG:3035 -t_srs EPSG:3857 -crop_to_cutline -cutline $WORKING_PATH/dem/box/${dem}buf.geojson -of GTiff -tr 25 25 -r cubicspline $WORKING_PATH/dem/eu_original/mosaic_eu.vrt $WORKING_PATH/dem/temp/deu.tif
  gdalwarp -s_srs EPSG:4326 -t_srs EPSG:3857 -crop_to_cutline -cutline $WORKING_PATH/dem/box/${dem}buf.geojson -of GTiff -tr 25 25 -r cubicspline $WORKING_PATH/dem/eu_hgt_original/mosaic_dem.vrt $WORKING_PATH/dem/temp/deu_hgt.tif
# tolgo valori nulli ai dem
  echo "*************** calc_py ${dem} -> world1 e deu1"
  gdal_calc.py -A $WORKING_PATH/dem/temp/world.tif --outfile=$WORKING_PATH/dem/temp/world1.tif --calc="A*(A>-5)" --NoDataValue=-5
  gdal_calc.py -A $WORKING_PATH/dem/temp/deu.tif --outfile=$WORKING_PATH/dem/temp/deu1.tif --calc="A*(A>-5)" --NoDataValue=-5
# tolgo i valori anomali ai dem
  echo "*************** despeckle ${dem} -> world2 e deu2"
  otbcli_Despeckle -in $WORKING_PATH/dem/temp/world1.tif -out $WORKING_PATH/dem/temp/world2.tif -filter lee -filter.lee.rad 1.5
  otbcli_Despeckle -in $WORKING_PATH/dem/temp/deu1.tif -out $WORKING_PATH/dem/temp/deu2.tif -filter lee -filter.lee.rad 1.5
# modifico tipo file in integer 16
  echo "*************** filter ${dem} -> world3 e deu3"
  gdal_translate  -ot Int16 $WORKING_PATH/dem/temp/world2.tif  $WORKING_PATH/dem/temp/world3.tif
  gdal_translate  -ot Int16 $WORKING_PATH/dem/temp/deu2.tif  $WORKING_PATH/dem/temp/deu3.tif
# metto insieme i 3 dem:
  echo "*************** compongo dem hgt (deu_hgt) + dem aster europa (deu) + dem world -> dlr.vrt"
  gdalbuildvrt $WORKING_PATH/dem/temp/dlr.vrt  $WORKING_PATH/dem/temp/world3.tif $WORKING_PATH/dem/temp/deu3.tif $WORKING_PATH/dem/temp/deu_hgt.tif

# ricampiono il dem a 5m di risoluzione
  echo "*************** resample dlr.vrt -> dlr5m.tif"
  gdalwarp -s_srs EPSG:3857 -t_srs EPSG:3857 -ot Float32 -of GTiff -tr 5 5 -r cubicspline $WORKING_PATH/dem/temp/dlr.vrt $WORKING_PATH/dem/temp/dlr5m.tif

# compongo i dem in alta risoluzione in unico dem a 5 m di risoluzione che è la base di partenza per creare lo sfumo
  echo "*************** costruisco vrt dhr da dem hr vari"
  #TODO: croppare in anticipo i raster vari e mettere nella cartella $WORKING_PATH/dem/hr/
  gdalbuildvrt -resolution user -tr 5 5 -overwrite $WORKING_PATH/dem/temp/dhr.vrt $WORKING_PATH/dem/temp/dlr5m.tif $WORKING_PATH/dem/hr/tinitaly${dem}.tif $WORKING_PATH/dem/hr/calabria${dem}.tif $WORKING_PATH/dem/hr/veneto${dem}.tif $WORKING_PATH/dem/hr/liguria${dem}.tif $WORKING_PATH/dem/hr/piemonte${dem}.tif $WORKING_PATH/dem/hr/friuli${dem}.tif $WORKING_PATH/dem/hr/emilia_romagna${dem}.tif $WORKING_PATH/dem/hr/toscana${dem}.tif $WORKING_PATH/dem/hr/lombardia${dem}.tif $WORKING_PATH/dem/hr/austria${dem}.tif $WORKING_PATH/dem/hr/alto_adige${dem}.tif $WORKING_PATH/dem/hr/trentino${dem}.tif $WORKING_PATH/dem/hr/vaosta${dem}.tif $WORKING_PATH/dem/hr/sardegna${dem}.tif

# filtro il dem alta risoluzione
  echo "*************** filter vrt dhr -> dhrf"
  otbcli_Smoothing -in $WORKING_PATH/dem/temp/dhr.vrt -out $WORKING_PATH/dem/temp/dhrf.tif -type gaussian -type.gaussian.radius 1.5

# creo lo sfumo orografico
  echo "*************** hillshade10m ${dem} -> hs10m"
  gdaldem hillshade  -z 3.0 -az 315.0 -alt 55.0 $WORKING_PATH/dem/temp/dhr.vrt $WORKING_PATH/dem/temp/hs10m.tif

# creo il file slope
  echo "*************** creo slope1 ${dem}"
  gdaldem slope $WORKING_PATH/dem/temp/dhr.vrt $WORKING_PATH/dem/temp/ds_10m.tif

# applico la scala colori al file slope per le falesie
  echo "*************** apply coloramp ${dem}"
  gdaldem color-relief $WORKING_PATH/dem/temp/ds_10m.tif $WORKING_PATH/dem/procedures/slope-ramp.txt $WORKING_PATH/dem/temp/ds1_10m.tif

# croppo il file slope con scala colori applicata
  echo "*************** crop slope ${dem}"
  rm $WORKING_PATH/slope/10m/${dem}.tif
  gdalwarp -crop_to_cutline -s_srs EPSG:3857 -t_srs EPSG:3857 -cutline $WORKING_PATH/dem/box/${dem}wm.geojson -of GTiff -tr 5 5 -r cubicspline -dstalpha $WORKING_PATH/dem/temp/ds1_10m.tif $WORKING_PATH/slope/10m/${dem}.tif

  gdaladdo -r cubic $WORKING_PATH/slope/10m/${dem}.tif 2 4 8 16 32

# croppo lo sfumo orografico
  echo "*************** crop hillshade ${dem}"
  rm $WORKING_PATH/hs/10m/${dem}.tif
  gdalwarp -crop_to_cutline -s_srs EPSG:3857 -t_srs EPSG:3857 -cutline $WORKING_PATH/dem/box/${dem}wm.geojson -of GTiff -tr 5 5 -r cubicspline -dstalpha $WORKING_PATH/dem/temp/hs10m.tif $WORKING_PATH/hs/10m/${dem}.tif

  gdaladdo -r cubic $WORKING_PATH/hs/10m/${dem}.tif 2 4 8 16 32

### contour lines hr:
# creo le contourlines in formato shp
  echo "*************** contour lines hr ${dem}"
  gdal_contour -a quota $WORKING_PATH/dem/temp/dhrf.tif $WORKING_PATH/dem/temp/contour.shp -i 25.0
# croppo le contour lines
  echo "*************** contour lines crop ${dem}"
  # ogr2ogr -clipsrc clipping_polygon.shp output.shp input.shp
  ogr2ogr -clipsrc $WORKING_PATH/dem/box/${dem}wm.geojson $WORKING_PATH/dem/temp/${dem}cl.shp $WORKING_PATH/dem/temp/contour.shp

# inserisco le contour lines nella tabella postgis su general:
  #insert into postgis - # Attenzione: ho tolto l’opzione -S che prende solo le features non multi-
  shp2pgsql -i -a -W latin1 -s 3857:3857 $WORKING_PATH/dem/temp/${dem}cl.shp contourlines_hr > $WORKING_PATH/dem/temp/cl.sql
# eseguo gli update sui valori delle tabelle postgis per le curve di livello
  psql -U webmapp -f $WORKING_PATH/dem/temp/cl.sql -d general -h localhost
  psql -U webmapp -d general -h localhost -c "update contourlines_hr set cella = '${dem}' where cella IS NULL;"
  psql -U webmapp -d general -h localhost -c "DELETE FROM contourlines_hr WHERE cella = '${dem}' AND quota = 0;"
  psql -U webmapp -d general -h localhost -c "update contourlines_hr set type = 'cs25' WHERE cella = '${dem}';"
  psql -U webmapp -d general -h localhost -c "update contourlines_hr set type = 'cs50' WHERE quota IN (50,150,250,350,450,550,650,750,850,950,1050,1150,1250,1350,1450,1550,1650,1750,1850,1950,2050,2150,2250,2350,2450,2550,2650,2750,2850,2950,3050,3150,3250,3350,3450,3550,3650,3750,3850,3950,4050,4150,4250,4350,4450,4550,4650,4750,4850,4950,5050,5150,5250,5350,5450,5550,5650,5750,5850,5950,6050,6150,6250,6350,6450,6550,6650,6750,6850,6950,7050,7150,7250,7350,7450,7550,7650,7750,7850,7950,8050,8150,8250,8350,8450,8550,8650,8750,8850,8950) AND cella = '${dem}';"
  psql -U webmapp -d general -h localhost -c "update contourlines_hr set type = 'cp25' where quota IN (100,300,500,700,900,1100,1300,1500,1700,1900,2100,2300,2500,2700,2900,3100,3300,3500,3700,3900,4100,4300,4500,4700,4900,5100,5300,5500,5700,5900,6100,6300,6500,6700,6900,7100,7300,7500,7700,7900,8100,8300,8500,8700,8900) AND cella = '${dem}';"
  psql -U webmapp -d general -h localhost -c "update contourlines_hr set type = 'cp50' where quota IN (200,400,600,800,1000,1200,1400,1600,1800,2000,2200,2400,2600,2800,3000,3200,3400,3600,3800,4000,4200,4400,4600,4800,5000,5200,5400,5600,5800,6000,6200,6400,6600,6800,7000,7200,7400,7600,7800,8000,8200,8400,8600,8800,9000) AND cella = '${dem}';"
  rm $WORKING_PATH/dem/temp/contour.shp

done < "/tmp/E${LON}N${LAT}.txt"

# rimuovo e ricostruisco i mosaici di sfumo e slope
rm $WORKING_PATH/hs/10m/mosaic_hs.vrt
gdalbuildvrt -vrtnodata "0 0 0" $WORKING_PATH/hs/10m/mosaic_hs.vrt $WORKING_PATH/hs/10m/*.tif

rm $WORKING_PATH/slope/10m/mosaic_slope.vrt
gdalbuildvrt -vrtnodata "0 0 0" $WORKING_PATH/slope/10m/mosaic_slope.vrt $WORKING_PATH/slope/10m/*.tif

# creo indici spaziali e vacuum analyze sulla tabella contourlines_hr
psql -U webmapp -d general -h localhost -c "DROP INDEX contourlines_hr_geom_idx;"
psql -U webmapp -d general -h localhost -c "CREATE INDEX contourlines_hr_geom_idx  ON contourlines_hr  USING GIST (geom);"
psql -U webmapp -d general -h localhost -c "VACUUM ANALYZE contourlines_hr;"

# eseguo il comando subdivide per scomporre le curve di livello
psql -U webmapp -d general -h localhost -c "DROP TABLE cl_hr_subd;"
psql -U webmapp -d general -h localhost -c "CREATE TABLE cl_hr_subd AS SELECT gid, st_subdivide(geom) as geom, quota, cella, type from contourlines_hr;"
psql -U webmapp -d general -h localhost -c "CREATE INDEX cl_hr_subd_geom_idx  ON cl_hr_subd  USING GIST (geom);"
psql -U webmapp -d general -h localhost -c "VACUUM ANALYZE cl_hr_subd;"

# export curve di livello
ogr2ogr -f "ESRI Shapefile" -overwrite $WORKING_PATH/contourlines_hr/E${LON}N${LAT}.shp -nlt LINESTRING "PG: dbname=general user=webmapp host=localhost" -sql "SELECT * from cl_hr_subd"
