#!/bin/sh
## creato da marco barbieri, 2018
## licenza GPL versione 3
## crea sfumo e curve di livello 1 grado per 1 grado

LON=$1
LAT=$2
LON2=$(expr $LON + 1)
LAT2=$(expr $LAT + 1)
echo E${LON}N${LAT}

rm $HOME/mapdata/hs/10m/*
rm $HOME/mapdata/slope/10m/*
psql -U webmapp -d general -h localhost -c "TRUNCATE contourlines_hr;"

psql -U webmapp -d general -h localhost -c "COPY (select id from grid where ST_Intersects(grid.geom,ST_SetSRID(ST_GeomFromText('POLYGON((${LON} ${LAT},${LON} ${LAT2},${LON2} ${LAT2},${LON2} ${LAT},${LON} ${LAT}))'),4326)) IS TRUE) TO '/tmp/E${LON}N${LAT}.txt';"

while read dem
do
  rm $HOME/mapdata/dem/temp/*
# creo i file geojson per clippare raster e curve di livello:
  echo "*************** create clip geojson ${dem}"
  rm  $HOME/mapdata/dem/box/${dem}.geojson $HOME/mapdata/dem/box/${dem}buf.geojson $HOME/mapdata/dem/box/${dem}wmbuf.geojson
  psql -U webmapp -d general -h localhost -c "UPDATE grid SET done = 'yes' WHERE id = '${dem}'"
  ogr2ogr -f GeoJSON $HOME/mapdata/dem/box/${dem}.geojson "PG:host=localhost dbname=general user=webmapp" -sql "select geom, id from grid where id = '${dem}'"
  ogr2ogr -f GeoJSON $HOME/mapdata/dem/box/${dem}wm.geojson "PG:host=localhost dbname=general user=webmapp" -sql "select st_transform(st_setsrid(geom,4326),3857) as geom, id from grid where id = '${dem}'"
  ogr2ogr -f GeoJSON $HOME/mapdata/dem/box/${dem}buf.geojson "PG:host=localhost dbname=general user=webmapp" -sql "select ST_Buffer(geom, 0.005, 'join=mitre mitre_limit=5.0') as geom, id from grid where id = '${dem}'"
  ogr2ogr -f GeoJSON $HOME/mapdata/dem/box/${dem}wmbuf.geojson "PG:host=localhost dbname=general user=webmapp" -sql "select ST_Buffer(st_transform(st_setsrid(geom,4326),3857), 100, 'join=mitre mitre_limit=5.0') as geom, id from grid where id = '${dem}'"
  echo "*************** crop original dem ${dem} -> deu + deu_hgt"
  gdalwarp -s_srs EPSG:3035 -t_srs EPSG:3857 -crop_to_cutline -cutline $HOME/mapdata/dem/box/${dem}buf.geojson -of GTiff -tr 25 25 -r cubicspline $HOME/mapdata/dem/eu_original/mosaic_eu.vrt $HOME/mapdata/dem/temp/deu.tif
  gdalwarp -s_srs EPSG:4326 -t_srs EPSG:3857 -crop_to_cutline -cutline $HOME/mapdata/dem/box/${dem}buf.geojson -of GTiff -tr 25 25 -r cubicspline $HOME/mapdata/dem/eu_hgt_original/mosaic_dem.vrt $HOME/mapdata/dem/temp/deu_hgt.tif
  echo "*************** calc_py ${dem} -> deu1"
  gdal_calc.py -A $HOME/mapdata/dem/temp/deu.tif --outfile=$HOME/mapdata/dem/temp/deu1.tif --calc="A*(A>-5)" --NoDataValue=-5
  echo "*************** despeckle ${dem} -> deu2"
  otbcli_Despeckle -in $HOME/mapdata/dem/temp/deu1.tif -out $HOME/mapdata/dem/temp/deu2.tif -filter lee -filter.lee.rad 1.5
  echo "*************** filter ${dem} -> deu3"
  gdal_translate  -ot Int16 $HOME/mapdata/dem/temp/deu2.tif  $HOME/mapdata/dem/temp/deu3.tif

  echo "*************** compongo dem hgt (deu_hgt) + dem aster europa (deu) -> dlr.vrt"
  gdalbuildvrt $HOME/mapdata/dem/temp/dlr.vrt $HOME/mapdata/dem/temp/deu3.tif $HOME/mapdata/dem/temp/deu_hgt.tif

  echo "*************** resample dlr.vrt -> dlr10m.tif"
  gdalwarp -s_srs EPSG:3857 -t_srs EPSG:3857 -of GTiff -tr 10 10 -r cubicspline $HOME/mapdata/dem/temp/dlr.vrt $HOME/mapdata/dem/temp/dlr10m.tif

  echo "*************** costruisco vrt dhr da dem hr vari"
  gdalbuildvrt -resolution user -tr 10 10 -overwrite $HOME/mapdata/dem/temp/dhr.vrt $HOME/mapdata/dem/temp/dlr10m.tif $HOME/mapdata/dem/it/veneto/${dem}.tif $HOME/mapdata/dem/it/liguria/${dem}.tif $HOME/mapdata/dem/it/piemonte/${dem}.tif $HOME/mapdata/dem/it/friuli/${dem}.tif $HOME/mapdata/dem/it/emilia/${dem}.tif $HOME/mapdata/dem/it/toscana/${dem}.tif $HOME/mapdata/dem/it/lombardia/${dem}.tif $HOME/mapdata/dem/it/trentino/${dem}.tif $HOME/mapdata/dem/it/altoadige/${dem}.tif $HOME/mapdata/dem/it/austria/${dem}.tif $HOME/mapdata/dem/it/sardegna/${dem}.tif

  echo "*************** filter vrt dhr -> dhrf"
  otbcli_Smoothing -in $HOME/mapdata/dem/temp/dhr.vrt -out $HOME/mapdata/dem/temp/dhrf.tif -type gaussian -type.gaussian.radius 1.5


  echo "*************** hillshade10m ${dem} -> hs10m"
  gdaldem hillshade  -z 3.0 -az 315.0 -alt 55.0 $HOME/mapdata/dem/temp/dhr.vrt $HOME/mapdata/dem/temp/hs10m.tif

  echo "*************** creo slope1 ${dem}"
  gdaldem slope $HOME/mapdata/dem/temp/dhr.vrt $HOME/mapdata/dem/temp/ds_10m.tif

  echo "*************** apply coloramp ${dem}"
  gdaldem color-relief $HOME/mapdata/dem/temp/ds_10m.tif $HOME/mapdata/dem/procedures/slope-ramp.txt $HOME/mapdata/dem/temp/ds1_10m.tif

  echo "*************** crop slope ${dem}"
  rm $HOME/mapdata/slope/10m/${dem}.tif
  gdalwarp -crop_to_cutline -s_srs EPSG:3857 -t_srs EPSG:3857 -cutline $HOME/mapdata/dem/box/${dem}wm.geojson -of GTiff -tr 10 10 -r cubicspline -dstalpha $HOME/mapdata/dem/temp/ds1_10m.tif $HOME/mapdata/slope/10m/${dem}.tif

  gdaladdo -r cubic $HOME/mapdata/slope/10m/${dem}.tif 2 4 8 16 32


  echo "*************** crop hillshade ${dem}"
  rm $HOME/mapdata/hs/10m/${dem}.tif
  gdalwarp -crop_to_cutline -s_srs EPSG:3857 -t_srs EPSG:3857 -cutline $HOME/mapdata/dem/box/${dem}wm.geojson -of GTiff -tr 10 10 -r cubicspline -dstalpha $HOME/mapdata/dem/temp/hs10m.tif $HOME/mapdata/hs/10m/${dem}.tif

  gdaladdo -r cubic $HOME/mapdata/hs/10m/${dem}.tif 2 4 8 16 32

  # contour lines hr:
  echo "*************** contour lines hr ${dem}"
  gdal_contour -a quota $HOME/mapdata/dem/temp/dhrf.tif $HOME/mapdata/dem/temp/contour.shp -i 25.0
  echo "*************** contour lines crop ${dem}"
  # ogr2ogr -clipsrc clipping_polygon.shp output.shp input.shp
  ogr2ogr -clipsrc $HOME/mapdata/dem/box/${dem}wm.geojson $HOME/mapdata/dem/temp/${dem}cl.shp $HOME/mapdata/dem/temp/contour.shp

  #insert into postgis - # Attenzione: ho tolto l’opzione -S che prende solo le features non multi-
  shp2pgsql -i -a -W latin1 -s 3857:3857 $HOME/mapdata/dem/temp/${dem}cl.shp contourlines_hr > $HOME/mapdata/dem/temp/cl.sql
  psql -U webmapp -f $HOME/mapdata/dem/temp/cl.sql -d general -h localhost
  psql -U webmapp -d general -h localhost -c "update contourlines_hr set cella = '${dem}' where cella IS NULL;"
  psql -U webmapp -d general -h localhost -c "DELETE FROM contourlines_hr WHERE cella = '${dem}' AND quota = 0;"
  psql -U webmapp -d general -h localhost -c "update contourlines_hr set type = 'cs25' WHERE cella = '${dem}';"
  psql -U webmapp -d general -h localhost -c "update contourlines_hr set type = 'cs50' WHERE quota IN (50,150,250,350,450,550,650,750,850,950,1050,1150,1250,1350,1450,1550,1650,1750,1850,1950,2050,2150,2250,2350,2450,2550,2650,2750,2850,2950,3050,3150,3250,3350,3450,3550,3650,3750,3850,3950,4050,4150,4250,4350,4450,4550,4650,4750,4850,4950) AND cella = '${dem}';"
  psql -U webmapp -d general -h localhost -c "update contourlines_hr set type = 'cp25' where quota IN (100,300,500,700,900,1100,1300,1500,1700,1900,2100,2300,2500,2700,2900,3100,3300,3500,3700,3900,4100,4300,4500,4700,4900) AND cella = '${dem}';"
  psql -U webmapp -d general -h localhost -c "update contourlines_hr set type = 'cp50' where quota IN (200,400,600,800,1000,1200,1400,1600,1800,2000,2200,2400,2600,2800,3000,3200,3400,3600,3800,4000,4200,4400,4600,4800,5000) AND cella = '${dem}';"
  rm $HOME/mapdata/dem/temp/contour.shp

done < "/tmp/E${LON}N${LAT}.txt"

rm $HOME/mapdata/hs/10m/mosaic_hs.vrt
gdalbuildvrt -vrtnodata "0 0 0" $HOME/mapdata/hs/10m/mosaic_hs.vrt $HOME/mapdata/hs/10m/*.tif

rm $HOME/mapdata/slope/10m/mosaic_slope.vrt
gdalbuildvrt -vrtnodata "0 0 0" $HOME/mapdata/slope/10m/mosaic_slope.vrt $HOME/mapdata/slope/10m/*.tif

psql -U webmapp -d general -h localhost -c "DROP INDEX contourlines_hr_geom_idx;"
psql -U webmapp -d general -h localhost -c "CREATE INDEX contourlines_hr_geom_idx  ON contourlines_hr  USING GIST (geom);"
psql -U webmapp -d general -h localhost -c "VACUUM ANALYZE contourlines_hr;"

psql -U webmapp -d general -h localhost -c "DROP TABLE cl_hr_subd;"
psql -U webmapp -d general -h localhost -c "CREATE TABLE cl_hr_subd AS SELECT gid, st_subdivide(geom) as geom, quota, type from contourlines_hr;"
psql -U webmapp -d general -h localhost -c "CREATE INDEX cl_hr_subd_geom_idx  ON cl_hr_subd  USING GIST (geom);"
psql -U webmapp -d general -h localhost -c "VACUUM ANALYZE cl_hr_subd;"

# creo mbitiles per livelli di zoom diversi:
#tl copy -z 14 -Z 14 -b "${LON} ${LAT} ${LON2} ${LAT2}" 'http://localhost:8080/{z}/{x}/{y}.png' mbtiles://./E${LON}N${LAT}_z14.mbtiles
#echo "*************** terminato tl copy z 14 E${LON}N${LAT}_z14.mbtiles"
#tl copy -z 15 -Z 15 -b "${LON} ${LAT} ${LON2} ${LAT2}" 'http://localhost:8080/{z}/{x}/{y}.png' mbtiles://./E${LON}N${LAT}_z15.mbtiles
#echo "*************** terminato tl copy z 15 E${LON}N${LAT}_z15.mbtiles"
#tl copy -z 16 -Z 16 -b "${LON} ${LAT} ${LON2} ${LAT2}" 'http://localhost:8080/{z}/{x}/{y}.png' mbtiles://./E${LON}N${LAT}_z16.mbtiles
#echo "*************** terminato tl copy z 16 E${LON}N${LAT}_z16.mbtiles"
