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
	$zmin = $square[2];
	$zmax = $square[3];

	echo "Processing square LON=$LON LAT=$LAT zmin=$zmin zmax=$zmax \n";


	// TL COPY + RSYNC (zoom 13 e 14)
	for ($z=13; $z <= 14; $z++) {
		$cmd = "bash /root/wm-mapserver/generate_mappa_muta_tiles.sh $LON $LAT $z $TILES_WORKING_PATH $TILES_REMOTE_PATH";
		echo "Executing command $cmd\n";
		system("$cmd");
	}

	// EMAIL
	$stop = date('c');
	$to='marcobarbieri@webmapp.it';
	$subj='WM-MAPSERVER';
	$cont="LON=$LON LAT=$LAT DONE!<br />";
	$cont.="START: $start <br/>";
	$cont.="STOP: $stop<br/>";
	$cont.="$email_footer";
	sendEmail($to,$subj,$cont);

	// LOG FINE SQUARE e EMAIL
	echo "\n";
}
