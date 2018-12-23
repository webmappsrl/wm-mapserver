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
  echo "*************** crop original dem ${dem} -> deu + deu_hgt"
  gdalwarp -s_srs EPSG:4326 -t_srs EPSG:3857 -crop_to_cutline -cutline $WORKING_PATH/dem/box/${dem}buf.geojson -of GTiff -tr 25 25 -r cubicspline $WORKING_PATH/dem/world_original/mosaic.vrt $WORKING_PATH/dem/temp/world.tif
  gdalwarp -s_srs EPSG:3035 -t_srs EPSG:3857 -crop_to_cutline -cutline $WORKING_PATH/dem/box/${dem}buf.geojson -of GTiff -tr 25 25 -r cubicspline $WORKING_PATH/dem/eu_original/mosaic_eu.vrt $WORKING_PATH/dem/temp/deu.tif
  gdalwarp -s_srs EPSG:4326 -t_srs EPSG:3857 -crop_to_cutline -cutline $WORKING_PATH/dem/box/${dem}buf.geojson -of GTiff -tr 25 25 -r cubicspline $WORKING_PATH/dem/eu_hgt_original/mosaic_dem.vrt $WORKING_PATH/dem/temp/deu_hgt.tif
  echo "*************** calc_py ${dem} -> deu1"
  gdal_calc.py -A $WORKING_PATH/dem/temp/world.tif --outfile=$WORKING_PATH/dem/temp/world1.tif --calc="A*(A>-5)" --NoDataValue=-5
  gdal_calc.py -A $WORKING_PATH/dem/temp/deu.tif --outfile=$WORKING_PATH/dem/temp/deu1.tif --calc="A*(A>-5)" --NoDataValue=-5
  echo "*************** despeckle ${dem} -> deu2"
  otbcli_Despeckle -in $WORKING_PATH/dem/temp/world1.tif -out $WORKING_PATH/dem/temp/world2.tif -filter lee -filter.lee.rad 1.5
  otbcli_Despeckle -in $WORKING_PATH/dem/temp/deu1.tif -out $WORKING_PATH/dem/temp/deu2.tif -filter lee -filter.lee.rad 1.5
  echo "*************** filter ${dem} -> deu3"
  gdal_translate  -ot Int16 $WORKING_PATH/dem/temp/world2.tif  $WORKING_PATH/dem/temp/world3.tif
  gdal_translate  -ot Int16 $WORKING_PATH/dem/temp/deu2.tif  $WORKING_PATH/dem/temp/deu3.tif

  echo "*************** compongo dem hgt (deu_hgt) + dem aster europa (deu) -> dlr.vrt"
  gdalbuildvrt $WORKING_PATH/dem/temp/dlr.vrt  $WORKING_PATH/dem/temp/world3.tif $WORKING_PATH/dem/temp/deu3.tif $WORKING_PATH/dem/temp/deu_hgt.tif

  echo "*************** resample dlr.vrt -> dlr5m.tif"
  gdalwarp -s_srs EPSG:3857 -t_srs EPSG:3857 -ot Float32 -of GTiff -tr 5 5 -r cubicspline $WORKING_PATH/dem/temp/dlr.vrt $WORKING_PATH/dem/temp/dlr5m.tif

  echo "*************** costruisco vrt dhr da dem hr vari"
  #crop 5x5 dem originali:
  ogr2ogr -f GeoJSON $WORKING_PATH/dem/temp/crop${dem}.geojson "PG:host=localhost dbname=general user=webmapp" -sql "select ST_Buffer(st_transform(st_setsrid(geom,4326),32632), 500, 'join=mitre mitre_limit=5.0') as geom, id from grid where id = '${dem}'"
  gdalwarp -s_srs EPSG:32632 -ot Float32 -t_srs EPSG:3857 -crop_to_cutline -cutline $WORKING_PATH/dem/temp/crop${dem}.geojson -of GTiff -tr 5 5 -r cubicspline $WORKING_PATH/dem/it_original/altoadige/dtm5p0m.asc $WORKING_PATH/dem/temp/altoadige${dem}.tif
  rm -f $WORKING_PATH/dem/temp/crop${dem}.geojson

  ogr2ogr -f GeoJSON $WORKING_PATH/dem/temp/crop${dem}.geojson "PG:host=localhost dbname=general user=webmapp" -sql "select ST_Buffer(st_transform(st_setsrid(geom,4326),31287), 500, 'join=mitre mitre_limit=5.0') as geom, id from grid where id = '${dem}'"
  gdalwarp -s_srs EPSG:31287 -ot Float32 -t_srs EPSG:3857 -crop_to_cutline -cutline $WORKING_PATH/dem/temp/crop${dem}.geojson -of GTiff -tr 5 5 -r cubicspline $WORKING_PATH/dem/it_original/austria/dhm_lamb_10m.tif $WORKING_PATH/dem/temp/austria${dem}.tif
  rm -f $WORKING_PATH/dem/temp/crop${dem}.geojson

  ogr2ogr -f GeoJSON $WORKING_PATH/dem/temp/crop${dem}.geojson "PG:host=localhost dbname=general user=webmapp" -sql "select ST_Buffer(st_transform(st_setsrid(geom,4326),32632), 500, 'join=mitre mitre_limit=5.0') as geom, id from grid where id = '${dem}'"
  gdalwarp -s_srs EPSG:32632 -ot Float32 -t_srs EPSG:3857 -crop_to_cutline -cutline $WORKING_PATH/dem/temp/crop${dem}.geojson -of GTiff -tr 5 5 -r cubicspline $WORKING_PATH/dem/it_original/lombardia/mosaic.vrt $WORKING_PATH/dem/temp/lombardia${dem}.tif
  rm -f $WORKING_PATH/dem/temp/crop${dem}.geojson

  ogr2ogr -f GeoJSON $WORKING_PATH/dem/temp/crop${dem}.geojson "PG:host=localhost dbname=general user=webmapp" -sql "select ST_Buffer(st_transform(st_setsrid(geom,4326),32632), 500, 'join=mitre mitre_limit=5.0') as geom, id from grid where id = '${dem}'"
  gdalwarp -s_srs EPSG:32632 -ot Float32 -t_srs EPSG:3857 -crop_to_cutline -cutline $WORKING_PATH/dem/temp/crop${dem}.geojson -of GTiff -tr 5 5 -r cubicspline $WORKING_PATH/dem/it_original/piemonte/mosaic.vrt $WORKING_PATH/dem/temp/piemonte${dem}.tif
  rm -f $WORKING_PATH/dem/temp/crop${dem}.geojson

  ogr2ogr -f GeoJSON $WORKING_PATH/dem/temp/crop${dem}.geojson "PG:host=localhost dbname=general user=webmapp" -sql "select ST_Buffer(st_transform(st_setsrid(geom,4326),3003), 500, 'join=mitre mitre_limit=5.0') as geom, id from grid where id = '${dem}'"
  gdalwarp -s_srs EPSG:3003  -ot Float32 -t_srs EPSG:3857 -crop_to_cutline -cutline $WORKING_PATH/dem/temp/crop${dem}.geojson -of GTiff -tr 5 5 -r cubicspline $WORKING_PATH/dem/it_original/sardegna/mosaic_dem.vrt $WORKING_PATH/dem/temp/sardegna${dem}.tif
  rm -f $WORKING_PATH/dem/temp/crop${dem}.geojson

  ogr2ogr -f GeoJSON $WORKING_PATH/dem/temp/crop${dem}.geojson "PG:host=localhost dbname=general user=webmapp" -sql "select ST_Buffer(st_transform(st_setsrid(geom,4326),3003), 500, 'join=mitre mitre_limit=5.0') as geom, id from grid where id = '${dem}'"
  gdalwarp -s_srs EPSG:3003  -ot Float32 -t_srs EPSG:3857 -crop_to_cutline -cutline $WORKING_PATH/dem/temp/crop${dem}.geojson -of GTiff -tr 5 5 -r cubicspline $WORKING_PATH/dem/it_original/toscana/mosaic.vrt $WORKING_PATH/dem/temp/toscana${dem}.tif
  rm -f $WORKING_PATH/dem/temp/crop${dem}.geojson

  gdalbuildvrt -resolution user -tr 5 5 -overwrite $WORKING_PATH/dem/temp/dhr.vrt $WORKING_PATH/dem/temp/dlr5m.tif $WORKING_PATH/dem/temp/veneto${dem}.tif $WORKING_PATH/dem/temp/liguria${dem}.tif $WORKING_PATH/dem/temp/piemonte${dem}.tif $WORKING_PATH/dem/temp/friuli${dem}.tif $WORKING_PATH/dem/temp/emilia${dem}.tif $WORKING_PATH/dem/temp/toscana${dem}.tif $WORKING_PATH/dem/temp/lombardia${dem}.tif $WORKING_PATH/dem/temp/trentino${dem}.tif $WORKING_PATH/dem/temp/altoadige${dem}.tif $WORKING_PATH/dem/temp/austria${dem}.tif $WORKING_PATH/dem/temp/sardegna${dem}.tif

  echo "*************** filter vrt dhr -> dhrf"
  otbcli_Smoothing -in $WORKING_PATH/dem/temp/dhr.vrt -out $WORKING_PATH/dem/temp/dhrf.tif -type gaussian -type.gaussian.radius 1.5


  echo "*************** hillshade10m ${dem} -> hs10m"
  gdaldem hillshade  -z 3.0 -az 315.0 -alt 55.0 $WORKING_PATH/dem/temp/dhr.vrt $WORKING_PATH/dem/temp/hs10m.tif

  echo "*************** creo slope1 ${dem}"
  gdaldem slope $WORKING_PATH/dem/temp/dhr.vrt $WORKING_PATH/dem/temp/ds_10m.tif

  echo "*************** apply coloramp ${dem}"
  gdaldem color-relief $WORKING_PATH/dem/temp/ds_10m.tif $WORKING_PATH/dem/procedures/slope-ramp.txt $WORKING_PATH/dem/temp/ds1_10m.tif

  echo "*************** crop slope ${dem}"
  rm $WORKING_PATH/slope/10m/${dem}.tif
  gdalwarp -crop_to_cutline -s_srs EPSG:3857 -t_srs EPSG:3857 -cutline $WORKING_PATH/dem/box/${dem}wm.geojson -of GTiff -tr 5 5 -r cubicspline -dstalpha $WORKING_PATH/dem/temp/ds1_10m.tif $WORKING_PATH/slope/10m/${dem}.tif

  gdaladdo -r cubic $WORKING_PATH/slope/10m/${dem}.tif 2 4 8 16 32


  echo "*************** crop hillshade ${dem}"
  rm $WORKING_PATH/hs/10m/${dem}.tif
  gdalwarp -crop_to_cutline -s_srs EPSG:3857 -t_srs EPSG:3857 -cutline $WORKING_PATH/dem/box/${dem}wm.geojson -of GTiff -tr 5 5 -r cubicspline -dstalpha $WORKING_PATH/dem/temp/hs10m.tif $WORKING_PATH/hs/10m/${dem}.tif

  gdaladdo -r cubic $WORKING_PATH/hs/10m/${dem}.tif 2 4 8 16 32

  # contour lines hr:
  echo "*************** contour lines hr ${dem}"
  gdal_contour -a quota $WORKING_PATH/dem/temp/dhrf.tif $WORKING_PATH/dem/temp/contour.shp -i 25.0
  echo "*************** contour lines crop ${dem}"
  # ogr2ogr -clipsrc clipping_polygon.shp output.shp input.shp
  ogr2ogr -clipsrc $WORKING_PATH/dem/box/${dem}wm.geojson $WORKING_PATH/dem/temp/${dem}cl.shp $WORKING_PATH/dem/temp/contour.shp

  #insert into postgis - # Attenzione: ho tolto l’opzione -S che prende solo le features non multi-
  shp2pgsql -i -a -W latin1 -s 3857:3857 $WORKING_PATH/dem/temp/${dem}cl.shp contourlines_hr > $WORKING_PATH/dem/temp/cl.sql
  psql -U webmapp -f $WORKING_PATH/dem/temp/cl.sql -d general -h localhost
  psql -U webmapp -d general -h localhost -c "update contourlines_hr set cella = '${dem}' where cella IS NULL;"
  psql -U webmapp -d general -h localhost -c "DELETE FROM contourlines_hr WHERE cella = '${dem}' AND quota = 0;"
  psql -U webmapp -d general -h localhost -c "update contourlines_hr set type = 'cs25' WHERE cella = '${dem}';"
  psql -U webmapp -d general -h localhost -c "update contourlines_hr set type = 'cs50' WHERE quota IN (50,150,250,350,450,550,650,750,850,950,1050,1150,1250,1350,1450,1550,1650,1750,1850,1950,2050,2150,2250,2350,2450,2550,2650,2750,2850,2950,3050,3150,3250,3350,3450,3550,3650,3750,3850,3950,4050,4150,4250,4350,4450,4550,4650,4750,4850,4950) AND cella = '${dem}';"
  psql -U webmapp -d general -h localhost -c "update contourlines_hr set type = 'cp25' where quota IN (100,300,500,700,900,1100,1300,1500,1700,1900,2100,2300,2500,2700,2900,3100,3300,3500,3700,3900,4100,4300,4500,4700,4900) AND cella = '${dem}';"
  psql -U webmapp -d general -h localhost -c "update contourlines_hr set type = 'cp50' where quota IN (200,400,600,800,1000,1200,1400,1600,1800,2000,2200,2400,2600,2800,3000,3200,3400,3600,3800,4000,4200,4400,4600,4800,5000) AND cella = '${dem}';"
  rm $WORKING_PATH/dem/temp/contour.shp

done < "/tmp/E${LON}N${LAT}.txt"

rm $WORKING_PATH/hs/10m/mosaic_hs.vrt
gdalbuildvrt -vrtnodata "0 0 0" $WORKING_PATH/hs/10m/mosaic_hs.vrt $WORKING_PATH/hs/10m/*.tif

rm $WORKING_PATH/slope/10m/mosaic_slope.vrt
gdalbuildvrt -vrtnodata "0 0 0" $WORKING_PATH/slope/10m/mosaic_slope.vrt $WORKING_PATH/slope/10m/*.tif

psql -U webmapp -d general -h localhost -c "DROP INDEX contourlines_hr_geom_idx;"
psql -U webmapp -d general -h localhost -c "CREATE INDEX contourlines_hr_geom_idx  ON contourlines_hr  USING GIST (geom);"
psql -U webmapp -d general -h localhost -c "VACUUM ANALYZE contourlines_hr;"

psql -U webmapp -d general -h localhost -c "DROP TABLE cl_hr_subd;"
psql -U webmapp -d general -h localhost -c "CREATE TABLE cl_hr_subd AS SELECT gid, st_subdivide(geom) as geom, quota, type from contourlines_hr;"
psql -U webmapp -d general -h localhost -c "CREATE INDEX cl_hr_subd_geom_idx  ON cl_hr_subd  USING GIST (geom);"
psql -U webmapp -d general -h localhost -c "VACUUM ANALYZE cl_hr_subd;"
