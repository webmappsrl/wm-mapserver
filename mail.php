<?php
date_default_timezone_set('Etc/UTC');
require 'PHPMailer-master/PHPMailerAutoload.php';

function sendEmail($to,$subj,$cont) {
	$mail = new PHPMailer;
	$mail->isSMTP();
	$mail->Host = 'smtp.gmail.com';
	$mail->Port = 587;
	$mail->SMTPSecure = 'tls';
	$mail->SMTPAuth = true;
	$mail->Username = "noreply@webmapp.it";
	$mail->Password = "T1tup4awpA";
	$mail->setFrom('noreply@webmapp.it','WEBMAPP');
	$mail->addAddress($to);
	$mail->Subject = $subj;
	$mail->msgHTML($cont);
	return $mail->send();
}