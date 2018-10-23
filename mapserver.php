<?php

// TODO check parmaters
// TODO log file
// TODO email

// Read configuration file
$j=json_decode(file_get_contents('config.json'),TREE);
$CL_WORKING_PATH = $j['CL_WORKING_PATH'];
$TILES_WORKING_PATH = $j['TILES_WORKING_PATH'];
$TILES_REMOTE_PATH = $j['TILES_REMOTE_PATH'];

echo "\n\nWEBMAPP SERVER\n\n";

echo "PARAMETERS:\n";

echo "CL_WORKING_PATH = $CL_WORKING_PATH \n"; 
echo "TILES_WORKING_PATH = $TILES_WORKING_PATH \n"; 
echo "TILES_REMOTE_PATH = $TILES_REMOTE_PATH \n"; 

