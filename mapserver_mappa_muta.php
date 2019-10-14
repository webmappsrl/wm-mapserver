<?php

require('mail.php');

// Read configuration file
$j=json_decode(file_get_contents('config.json'),TRUE);
$CL_WORKING_PATH = $j['CL_WORKING_PATH'];
$TILES_WORKING_PATH = $j['TILES_WORKING_PATH'];

echo "\n\nWEBMAPP SERVER\n\n";

echo "PARAMETERS:\n";

echo "CL_WORKING_PATH = $CL_WORKING_PATH \n";
echo "TILES_WORKING_PATH = $TILES_WORKING_PATH \n";

$email_footer = "CL_WORKING_PATH = $CL_WORKING_PATH<br />
                 TILES_WORKING_PATH = $TILES_WORKING_PATH<br />;

// READING QUEUE
$data = json_decode(file_get_contents($argv[1]),TRUE);

foreach ($data as $square) {

	// LOG INIZIO SQUARE
	$start=date('c');

	$LON = $square[0];
	$LAT = $square[1];

	echo "Processing square LON=$LON LAT=$LAT \n";


}
