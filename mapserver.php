<?php

// TODO check parmaters
// TODO log file
// TODO email

// Read configuration file
$j=json_decode(file_get_contents('config.json'),TRUE);
$CL_WORKING_PATH = $j['CL_WORKING_PATH'];
$TILES_WORKING_PATH = $j['TILES_WORKING_PATH'];
$TILES_REMOTE_PATH = $j['TILES_REMOTE_PATH'];

echo "\n\nWEBMAPP SERVER\n\n";

echo "PARAMETERS:\n";

echo "CL_WORKING_PATH = $CL_WORKING_PATH \n"; 
echo "TILES_WORKING_PATH = $TILES_WORKING_PATH \n"; 
echo "TILES_REMOTE_PATH = $TILES_REMOTE_PATH \n"; 


// READING QUEUE
/**
[
  [LON,LAT,z,Z],
  [LON,LAT,z,Z]
]
**//
$data = json_decode(file_get_contents($argv[1]),TRUE);

foreach ($data as $square) {

	// LOG INIZIO SQUARE

	$LON = $square[0];
	$LAT = $square[1];
	$zmin = $square[2];
	$zmax = $square[3];

	echo "Processing square LON=$LON LAT=$LAT zmin=$zmin zmax=$zmax \n";

	// Contour Line (script singolo)

	// TL COPY + RSYNC (llop da zmin a zmx step 1)

	// LOG FINE SQUARE e EMAIL

}