<table width="100%" class="mainWindow">
<tr><td class="mainWindowHead">
<p>Mine profiler</p>
</td></tr>

<tr><td>
<?php
include("loginordie.php");
loginOrDie();
?>

<p>Her kan du endre og opprette nye profiler.
<p><a href="#nyprofil">Legg til ny profil</a>

<?php

include("databaseHandler.php");
$dbh = new DBH($dbcon);

if (get_get('subaction') == 'settaktiv') {
	$dbh->aktivProfil(session_get('bruker'), get_get('pid') );
	print "<p><font size=\"+3\">Aktivisert</font>. Du har nå byttet aktiv profil.";
}

if (get_get('subaction') == 'endret') {

	if ($pid > 0) { 
	
		$dbh->endreProfil($pid, $navn);
		$navn='';
		
		print "<p><font size=\"+3\">OK</font>, profilnavnet er endret.";


	} else {
		print "<p><font size=\"+3\">Feil</font> oppstod, profilen er <b>ikke</b> endret.";
	}
}

if (get_get('subaction') == 'slett') {

	
	if ($pid > 0) { 
	
		$foo = $dbh->slettProfil($pid);
		$navn = '';
		
		print "<p><font size=\"+3\">OK</font>, profilen er slettet fra databasen.";

	} else {
		print "<p><font size=\"+3\">Feil</font>, profilen er <b>ikke</b> slettet.";
	}

}


if (get_get('subaction') == "nyprofil") {
  print "<h3>Registrerer ny profil...</h3>";
  
  $error = NULL;
	
	$navn = "";
  if (post_get('navn') == "") $navn = "Uten navn"; else $navn = post_get('navn');

  if (session_get('uid') > 0) { 
    
    $profilid = $dbh->nyProfil($navn, session_get('uid') );
    $tidsid = $dbh->nyTidsperiode(1, '08:00', $profilid);
    
    print "<p><font size=\"+3\">OK</font>, En ny profil er opprettet for brukeren $brukernavn, denne har id $profilid. Profilen har bare en tidsperiode, fra 08:00 til 08:00 alle dager.";
    
  } else {
    print "<p><font size=\"+3\">Feil</font>, ny profil er <b>ikke</b> lagt til i databasen.";
  }


}

$l = new Lister( 106,
	array('Aktiv', 'Navn', '#perioder', 'Valg..'),
	array(10, 50, 15, 25),
	array('left', 'left', 'right', 'right'),
	array(true, true, true, false),
	1);

print "<h3>Dine profiler</h3>";

if ( get_exist('sortid') )
	$l->setSort(get_get('sort'), get_get('sortid') );

$profiler = $dbh->listProfiler(session_get('uid'), $l->getSort() );

for ($i = 0; $i < sizeof($profiler); $i++) {

  if ($profiler[$i][3] == 't') {
    $aktiv = "<img alt=\"Aktiv\" src=\"icons/ok.gif\">";
  } else {
    $aktiv = "<a href=\"index.php?action=profil&subaction=settaktiv&pid=". $profiler[$i][0] .
      "\"><img alt=\"Aktiv\" src=\"icons/stop.gif\" border=0></a>";
  }
  if ($profiler[$i][4] == 't') { 
    $sms = '<img alt="Ja" src="icons/ok.gif">';
  } else {
    $sms = '<img alt="Nei" src="icons/cancel.gif">';
  }
  $valg = '<a href="index.php?action=periode&pid=' . $profiler[$i][0] . 
    '"><img alt="Open" src="icons/open2.gif" border=0></A>&nbsp;' .
    '<a href="index.php?action=profil&subaction=endre&pid=' . 
    $profiler[$i][0] . '&navn=' . $profiler[$i][1] . '#nyprofil">' . 
    '<img alt="Edit" src="icons/edit.gif" border=0></a>&nbsp;' .
    '<a href="index.php?action=profil&subaction=slett&pid=' . 
    $profiler[$i][0] . '">' . 
    '<img alt="Delete" src="icons/delete.gif" border=0></a>';

        $l->addElement( array($aktiv,
                        $profiler[$i][1],  // brukernavn
                        $profiler[$i][2],  // navn
                        $valg
                )
        );

}

print $l->getHTML();

print "<p>[ <a href=\"index.php\">Refresh <img src=\"icons/refresh.gif\" alt=\"Refresh\" border=0> ]</a> ";
print "Antall profiler: " . sizeof($profiler);

print '<a name="nyprofil"></a><p>';

if ($subaction == 'endre') {
	print '<h2>Endre navn på profil</h2>';
} else {
	print '<h2>Legg til ny profil</h2>';
}

?>

<form name="form1" method="post" action="index.php?action=profil&subaction=<?php
if ($subaction == 'endre') echo "endret"; else echo "nyprofil";
?>">
<?php
if ($subaction == 'endre') {
	print '<input type="hidden" name="pid" value="' . $pid . '">';
}
?>
  <table width="100%" border="0" cellspacing="0" cellpadding="3">


    <tr>
      <td><p>Navn</p></td>
      <td><input name="navn" type="text" size="40" 
value="<?php echo $navn; ?>"></td>
      <td align="right"><input type="submit" name="Submit" value="<?php
if ($subaction == 'endre') echo "Lagre endringer"; else echo "Legg til ny profil";
?>"></td>
    </tr>

  </table>

</form>


</td></tr>
</table>
