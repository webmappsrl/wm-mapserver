<?php

// TODO check parmaters
// TODO log file
// TODO config email
// TODO aggiungere command path

require('mail.php');

// Read configuration file
$j=json_decode(file_get_contents('blankmap_config.json'),TRUE);
$CL_WORKING_PATH = $j['CL_WORKING_PATH'];
$TILES_WORKING_PATH = $j['TILES_WORKING_PATH'];
$TILES_REMOTE_PATH = $j['TILES_REMOTE_PATH'];

echo "\n\nWEBMAPP SERVER\n\n";

echo "PARAMETERS:\n";

echo "CL_WORKING_PATH = $CL_WORKING_PATH \n";
echo "TILES_WORKING_PATH = $TILES_WORKING_PATH \n";
echo "TILES_REMOTE_PATH = $TILES_REMOTE_PATH \n\n\n";

$email_footer = "CL_WORKING_PATH = $CL_WORKING_PATH<br />
                 TILES_WORKING_PATH = $TILES_WORKING_PATH<br />
                 TILES_REMOTE_PATH = $TILES_REMOTE_PATH<br />";

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

	// Contour Line (script singolo)
	$cmd="bash /root/wm-mapserver/generate_cl.sh $LON $LAT $CL_WORKING_PATH";
	echo "Executing command $cmd\n";
	system($cmd);

	// TL COPY + RSYNC (llop da zmin a zmx step 1)
	for ($z=$zmin; $z <= $zmax; $z++) {
		$cmd = "bash /root/wm-mapserver/generate_map_tiles.sh $LON $LAT $z $TILES_WORKING_PATH $TILES_REMOTE_PATH";
		echo "Executing command $cmd\n";
		system("$cmd");
	}

	// EMAIL
	$stop = date('c');
	$to='info@webmapp.it';
	$subj='WM-MAPSERVER';
	$cont="LON=$LON LAT=$LAT zmin=$zmin zmax=$zmax DONE!<br />";
	$cont.="START: $start <br/>";
	$cont.="STOP: $stop<br/>";
	$cont.="$email_footer";
	sendEmail($to,$subj,$cont);

	// LOG FINE SQUARE e EMAIL
	echo "\n";
}
