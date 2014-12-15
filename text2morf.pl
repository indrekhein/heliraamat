#!/usr/bin/perl -w

# Alustame alati kogu tekstist sonaloendi tegemisega, see on piisavalt kiire
# ja tagab ka teksti muutmise puhul tulemuse.
# Samasse kataloogi tehakse kaks loendit: .err vigadega ja .ok tulemuslikega.
# Igal käivitamisel loeme need sisse ja teeme siis uued.
# .err laiendiga fail ongi lõpuks vajalik. Failides read kujul sõne<tab>sagedus.

use utf8;
use Storable;
use Time::HiRes qw/ time /;
$| = 1;
binmode (STDOUT, ":utf8");

###############

my $stat_algusaeg = time;
my $sekundeid = 60;
my $dbg = 0;	# väljasta móttekäik
my $err = 1;
my $esi = 1;

# kõik käsureal olevad asjad käiatakse läbi ja otsitakse boolean parameetreid
foreach my $a (0..$#ARGV) {
    $dbg = $dbg || ($ARGV[$a] eq '-d');
    $sekundeid = $1 if ($ARGV[$a] =~ /^\-t(\d+)$/);
}

# Initsialiseerimine

my $morfdatadir = $0;
$morfdatadir = $& . 'morf_data/' if $morfdatadir =~ /.*\//;

my $fail_formtab = 	$morfdatadir . 		'formtab.pmf';
my $fail_formtablisa =  $morfdatadir . 		'dertab.pmf';
my $fail_tyvebaas =  	$morfdatadir . 		'tyvebaas.pmf';
my $fail_liitsonajupid = $morfdatadir . 	'liitsonajupid.pmf';
my $fail_erandid =  	$morfdatadir . 		'vormierandid1.pmf';
my $fail_vormierandid = $morfdatadir . 		'vormierandid2.pmf';
my $fail_lisad =  	$morfdatadir . 		'lisad.pmf';

my @formtab = ();
my %ftb = ();
my %tyvebaas = ();
my %lsjupid = ();
my %erandid = ();
my %muutumatud = ();	# selle taidame TB lugemise kaigus
my %lisad = ();

my ($fn, $dfn);

# true, kui andmefaili dump on kasutuskolblik
sub varske {
    my $fn = shift;
    my $dfn = shift;
    $dfn = $fn . '.dmp' unless $dfn;
    return ( (-e $fn) and (-e $dfn) and ((stat($fn))[9] < (stat($dfn))[9]) );
}

$fn = $fail_liitsonajupid;
$dfn = $fn . '.dmp';
if ( varske ($fn) ) {
    %lsjupid = %{ retrieve ($dfn) };
}
else {
    loesisse_liitsonajupid($fn);
    store \%lsjupid, $dfn;
    print "salvestasin liitsonajupid uuesti\n" if $dbg;
}

$fn = $fail_formtab;
$dfn = $fn . '.dmp';
if ( varske($fail_formtab) and varske($fail_formtablisa, $dfn) ) {
    @formtab = @{ retrieve ($dfn) };
}
else {
    loesisse_formtab($fail_formtab);
    loesisse_formtab($fail_formtablisa);
    store \@formtab, $dfn;
}
foreach (@formtab) {
    my ($formatiiv, $vormikood, $tingimus, $tyvekood) = split (/,/, $_, 4);
    $ftb{$formatiiv}{$tyvekood}{$tingimus} .= $vormikood;
}

$fn = $fail_erandid;
$dfn = $fn . '.dmp';
if ( varske($fail_erandid) and varske($fail_vormierandid, $dfn) ) {
    %erandid = %{ retrieve ($dfn) };
}
else {
    loesisse_erandid($fn);
    loesisse_vormierandid($fail_vormierandid);
    store \%erandid, $dfn;
    print "salvestasin erandid uuesti\n" if $dbg;
}

$fn = $fail_tyvebaas;
$dfn = $fn . '.dmp';
if ( varske($fn) ) {
    %tyvebaas = %{ retrieve ($dfn) };
    %muutumatud = %{ retrieve ($morfdatadir . 'muutumatud.pfm.dmp') };
}
else {
    loesisse_tyvebaas($fn);
    store \%tyvebaas, $dfn;
    store \%muutumatud, $morfdatadir . 'muutumatud.pfm.dmp';
    print "salvestasin tyvebaasi ja muutumatud uuesti\n" if $dbg;
}

$fn = $fail_lisad;
open (F, "<$fn");
binmode (F, ":utf8");
while (<F>) { chomp; $lisad{ $_ } = 1; }


my %leitud = ();	# peame meeles lahenduvaid analyyse
my %leidmata = ();	# peame meeles mittelahenduvaid analyyse
my %varemleitud = ();	# eelmise ringi lahenduvad analyysid
my %varemleidmata = ();	# eelmise ringi mittelahenduvad analyysid

foreach my $a (0..$#ARGV) { 
    analyysi_fail ($ARGV[$a]) unless $ARGV[$a] =~ /^\-/;
}




###############

sub asendataheklassid {
    my $tingimus = shift;
    if ($tingimus =~ /%[A-Z]/) {
	return asendataheklassid($`) . $& . asendataheklassid($');
    }

    $tingimus =~ s/W/[aeiouõäöüy]/go;
    $tingimus =~ s/E/[aeu]/go;
    $tingimus =~ s/I/[aei]/go;
    $tingimus =~ s/U/[iuü]/go;
    $tingimus =~ s/Y/[aiõ]/go;
    $tingimus =~ s/X/[eouäöü]/go;
    $tingimus =~ s/A/[aeiou]/go;
    $tingimus =~ s/O/[õäöü]/go;
    $tingimus =~ s/C/[bcdfghjklmnpqrsšzžtvwx]/go;
    $tingimus =~ s/Q/[kptfš]/go;
    $tingimus =~ s/G/[gbd]/go;
    $tingimus =~ s/K/[kpt]/go;
    $tingimus =~ s/Z/[gbdlmnrvshjzž]/go;
    $tingimus =~ s/H/[lmnrvshjzž]/go;
    $tingimus =~ s/V/[lmnrvwž]/go;
    $tingimus =~ s/M/[lmnrv]/go;
    $tingimus =~ s/L/[lmnr]/go;
    $tingimus =~ s/N/[lnr]/go;
    $tingimus =~ s/R/[nr]/go;
    $tingimus =~ s/J/[lrvj]/go;
    $tingimus =~ s/T/[gbdkptlmnrvshj]/go;
    $tingimus =~ s/B/[gbdjfšzž]/go;
    $tingimus =~ s/D/[ntd]/go;
    $tingimus =~ s/F/[fš]/go;
    $tingimus =~ s/S/[sh]/go;
    $tingimus =~ s/Ü/[ie]/go;
    $tingimus =~ s/Ä/[ns]/go;
    $tingimus =~ s/Õ/[mjntv]/go;
    $tingimus =~ s/Ö/[dtslkng]/go;
    $tingimus =~ s/P/[gbdkptfh]/go;

    return $tingimus;
}

sub slurpin {
    my ($fn, $href) = @_;
    my $dfn = $fn . '.dmp';
    if ( (-e $fn) and (-e $dfn) and ((stat($fn))[9] < (stat($dfn))[9]) ) {
	$href = retrieve ($dfn);
    }
}

sub spitout {
    my ($fn, $href) = @_;
    my $dfn = $fn . '.dmp';
    store $href, $dfn;
}

sub loesisse_liitsonajupid {
    my $misnimeline = shift;
    open (F, "<$misnimeline") or die "puudub $misnimeline!";
    binmode (F, ":utf8");
    while (<F>) {
	chomp;
	$lsjupid{ $_ } = 1;
    }
}

sub loesisse_erandid {
    my $misnimeline = shift;
    open (F, "<$misnimeline") or die "puudub $misnimeline!";
    binmode (F, ":utf8");
    while (<F>) {
	chomp;
	next unless /^([^ ]+) .*?\(([^ ]+) .*?>(.+)/;
	$erandid{ $1 } = ":$2 $3:";
    }
}

sub loesisse_vormierandid {
    my $misnimeline = shift;
    open (F, "<$misnimeline") or die "puudub $misnimeline!";
    binmode (F, ":utf8");
    while (<F>) {
	chomp;
	my ($tk, $lemma, $vorm, $vormikood, $muu) = split (/,/, $_);
	next unless $vorm;
	# vormid, mida me EI tohiks moodustada jätame hetkel tähelepanuta.
	# vóiks muidugi kontrollida, et enese nimetavat käänet pole olemas vói
	# hea mitmuse osastav peab olema häid, mitte aga heasid, aga keelama ei hakka.
	next if $vorm eq '#';
	$vorm =~ s/[\'\[\]]//g;
	$erandid{ $vorm } .= ":$vormikood $lemma:";
    }
}

# LOE SISSE FORM.TAB
# jagame tyved eraldi kirjeteks ja kontrollime sealjuures korduste vältimiseks, kas selline juba oli

sub loesisse_formtab {
    my $misnimeline = shift;
    open (F, "<$misnimeline") or die "puudub $misnimeline!";
    binmode (F, ":utf8");
    my %vakantsid = ();
    my %jubaoli = ();
    my @fttemp = ();

    while (<F>) {
	chomp;
	next unless $_;		# tyhi rida
	next if /^[;#]/;	# kommentaar, alguses # voi ;
	next if /^\/\//;	# kommentaar, alguses //
	push @fttemp, $_;
	my ($formatiiv, $vormikood, $tingimus, $tyved) = split (/,/, $_, 4);
	# unless on vajalik ,-----0G mitmetähenduslikkuse tóttu
	$vakantsid{ $formatiiv . ',' . $vormikood } = $tyved unless $vakantsid{ $formatiiv . ',' . $vormikood };
    }

    foreach (@fttemp) {
	my ($formatiiv, $vormikood, $tingimus, $tyved) = split (/,/, $_, 4);
	$tingimus = asendataheklassid ($tingimus);
	if ($tyved =~ /^=/) { $tyved = $vakantsid{ $' }; }
#	if ($formatiiv eq 'd') { print "$vormikood $tyved\n"; sleep (5); }
	foreach my $t (split (/,/, $tyved)) {
	    my $yksiktyvi = "$formatiiv,$vormikood,$tingimus,$t";
	    next if $jubaoli{$yksiktyvi};	# tuletusega osas on palju topelt -- 9~11 paralleelid, -(a|e|u) jms
	    $jubaoli{$yksiktyvi} = 1;
	    push @formtab, $yksiktyvi;
	    print "$yksiktyvi\n" if $dbg;
	}
    }
}

# LOE SISSE _TB.TXT

sub lisatuletustyved {
    my ($tyvi, $tyyp, $tyvekood, $lemma, $sliik) = @_;

    if ($tyyp eq '27') {
	if ($tyvekood eq 'a0') {
	    if ($tyvi =~ /tse$/) { $tyvekood = ':27d0tsus'; $tyvi = $`; goto UUSTT; }
	    if ($tyvi =~ /le$/) { $tyvekood = ':27d0lus'; $tyvi = $`; goto UUSTT; }
	    if ($tyvi =~ /ta$/) { $tyvekood = ':27d0tus'; $tyvi = $`; goto UUSTT; }
	    if ($tyvi =~ /da$/) { $tyvekood = ':27d0dus'; $tyvi = $`; goto UUSTT; }
	}
    }
    if ($tyyp eq '12') {
	if ($tyvekood eq 'b0') {
	    if ($tyvi =~ /lase$/) { $tyvekood = ':27d0lus'; $tyvi = $`; goto UUSTT; }
	}
    }
    if ($tyyp eq '10') {
	if ($tyvekood eq 'b0') {
	    if ($sliik eq 'A') {
		if ($tyvi =~ /stikuse$/) { $tyvekood = ':10d0stikkus'; $tyvi = $`; goto UUSTT; }
	    }
	}
    }
    if ($tyyp eq '02') {
	if ($tyvekood eq 'b0') {
	    if ($sliik eq 'A') {
		if ($tyvi =~ /bli$/) { $tyvekood = ':02d0blus'; $tyvi = $`; goto UUSTT; }
		if ($tyvi =~ /(a|e|u)$/) { $tyvekood = ':02d0us'; $tyvi = $`; goto UUSTT; }
	    }
	}
    }
    if ($tyyp eq '25') {
	if ($tyvekood eq 'bt') {
	    if ($sliik eq 'A') {
		if ($tyvi =~ /u$/) { $tyvekood = ':25d0us'; $tyvi = $`; goto UUSTT; }
	    }
	}
    }
    if ($tyyp eq '07') {
	if ($tyvekood eq 'bt') {
	    if ($sliik eq 'A') {
		if ($tyvi =~ /u$/) { $tyvekood = ':07d0us'; $tyvi = $`; goto UUSTT; }
	    }
	}
    }
    if ($tyyp eq '03') {
	if ($tyvekood eq 'bt') {
	    if ($sliik eq 'A') {
		if ($tyvi =~ /u$/) { $tyvekood = ':03d0us'; $tyvi = $`; goto UUSTT; }
	    }
	}
    }
    if ($tyyp eq '01') {
	if ($tyvekood eq 'a0') {
	    if ($sliik eq 'A') {
		if ($tyvi =~ /e$/) { $tyvekood = ':01d0us'; $tyvi = $`; goto UUSTT; }
	    }
	}
    }

    return;

UUSTT:
    $tyvekood .= "#$lemma:";
    $tyvebaas{$tyvi} .= $tyvekood;
    print "Lisan tuletustyve $tyvi == $tyvekood\n" if $dbg;
}

sub loesisse_tyvebaas {
    my $misnimeline = shift;
    open (F, "<$misnimeline") or die "puudub $misnimeline!";
    binmode (F, ":utf8");
    %tyvebaas = ();
    while (<F>) {
	chomp;
	next unless $_;		# tyhi rida
	next if /^[;#]/;	# kommentaar, alguses # voi ;
	next if /^\/\//;	# kommentaar, alguses //

	# tyvebaasi rida
	my $tyved = '';		# (muutumatud on ilma eraldajata ja tyvedeta)
	next unless /^(.)([^ ]+) ([0-9][0-9])_([A-Y]+)/;
	my $lemma = $2;
	my $tyyp = $3;
	my $sliik = $4;
	$tyved = $';
	$tyved = $' if $tyved =~ /^\s+\|?\s+/;

	# välted ja rõhud
	$lemma =~ s/[\'\`]//g; # `

	if ($tyved eq '') {
	    $muutumatud{$lemma} .= ":${tyyp}_${sliik}:";
	}

	foreach (split (/,/, $tyved)) {
	    next unless /([a-y0]+): /;
	    my $tyvi = $';
	    my $tyvekood = $1;
	    $tyvi =~ s/[\'\`]//g; # `

	    $tyvebaas{$tyvi} .= ":$tyyp$tyvekood#$lemma#$sliik:";
	    #prots lisab %tyvebaasile kavatsema taha d0tsus: kava
	    lisatuletustyved ($tyvi, $tyyp, $tyvekood, $lemma, $sliik);
	}
    }
}

# ANALYYSI

sub testitingimust {
    my ($algus, $tingimus) = @_;
    my $sonaliik = '';
    my $kustuta = 0;
    if ($tingimus =~ /%([A-Z])/) { $tingimus = $`; $sonaliik = $1; }
    if ($tingimus =~ /^\-/) { $tingimus = $'; $kustuta = 1; }
    if ($algus =~ /$tingimus$/) {
#	print "algus: $algus, tingimus: $tingimus\n";
	$algus = $` if $kustuta;
	return $algus;
    } else {
	return '';
    }
}

sub jaga_liitsonajuppideks {
    my $suurjupp = shift;
    return $suurjupp if $lsjupid{$suurjupp};
    return '' unless $suurjupp;

    my $i = 2;
    while ( $i <= length($suurjupp)-2 ) {
	my $sonaalgus = substr $suurjupp, 0, $i;
	my $sonalopp = substr $suurjupp, $i;
	$i++;
	next unless $lsjupid{$sonaalgus};
	$sonalopp = jaga_liitsonajuppideks ($sonalopp);
	next if $sonalopp eq '?';
	return "$sonaalgus+$sonalopp";
    }
    return '?';
}

sub puhastasona {
    my $mustsona = shift;
    $mustsona =~ s/[\.,!\?\":;\x{2016}-\x{2025}]//g;
    $mustsona = $' if $mustsona =~ /^[\/\(]+/;
    $mustsona = $` if $mustsona =~ /[\/\)\-]+$/;
    return $mustsona;
}

sub analyysi_fail {
    my $fn = shift;
    if (! -e $fn) {
	print "Morf: ei leia faili $fn\n";
	return;
    }
    print "Morf: alustan failiga $fn\n" if $dbg;
    my $failiaeg = time;
    my $tmpaeg = time;

    my $stat_sonesid = 0;
    my $stat_leidmata = 0;
    my $ok_num = 0;
    my $no_num = 0;

    # kulub ära kui sisendis on mitu faili
    %leitud = ();	# peame meeles lahenduvaid analyyse
    %leidmata = ();	# peame meeles mittelahenduvaid analyyse

    # teeme kogu failist sõnaloendi: sone->sagedus
    open (F, "<$fn") or print "Ei saanud avada $fn\n";
    binmode (F, ":utf8");
    my $sonukokku = 0;
    my %sonaloend = ();
    while (<F>) {
	foreach my $sone (split(/\s+/, $_)) {
	    $sone = puhastasona($sone);
	    next unless $sone;
	    $sonaloend{$sone}++;
	    $sonukokku++;
	}
    }
    close (F);

    # Vaatame, kas varemleituid on
    if (-e "$fn.ok") {
	open (F, "<$fn.ok");
	binmode (F, ":utf8");
	while (<F>) {
	    chomp;
	    my ($s, $n) = split (/\t/, $_);
	    if ( $sonaloend{$s} ) {
		$leitud{$s} = $n;
		$ok_num++;
		$sonaloend{$s} = 0;
	    }
	}
	close (F);
    }

    # Vaatame, kas varemleidmata on
    if (-e "$fn.err") {
	open (F, "<$fn.err");
	binmode (F, ":utf8");
	while (<F>) {
	    chomp;
	    my ($s, $n) = split (/\t/, $_);
	    if ( $sonaloend{$s} ) {
		$leidmata{$s} = $n;
		$no_num++;
		$sonaloend{$s} = 0;
	    }
	}
	close (F);
    }

    my $pooleli = 0;

    my $ok_aeg = 0;
    my $no_aeg = 0;
    $liitajad = 0;
    $lihtajad = 0;

    foreach my $sone (keys %sonaloend) {
	my $sagedus = $sonaloend{$sone};
	print "$sone\t$sagedus\n" if $dbg;
	next unless $sagedus;

	$tmpaeg = time;
	if ( analyysi ($sone) ) {
	    $leitud{$sone} = $sagedus;
	    $ok_aeg += time-$tmpaeg;
	    $ok_num++;
	} else {
	    $leidmata{$sone} = $sagedus;
	    $no_aeg += time-$tmpaeg;
	    $no_num++;
	}
    }

    open (F, ">$fn.err");
    binmode (F, ":utf8");
    foreach (sort keys %leidmata) {
	print F "$_\t$leidmata{$_}\n";
    }
    close F;

    open (F, ">$fn.ok");
    binmode (F, ":utf8");
    foreach (sort keys %leitud) {
	print F "$_\t$leitud{$_}\n";
    }
    close F;

    printf ("Sõnavorme kokku %d, neist unikaalseid %d\n", $sonukokku, scalar(keys %sonaloend));
    printf ("Neist omakorda %d jäid tundmatuks\n", $no_num);
    # väldime nulliga jagamist kui ok või no on nullid
    my $kesk = 0;
    printf ("Lihtanalüüsid kokku %.5f sek\n", $lihtajad);
    printf ("Liitanalüüsid kokku %.5f sek\n", $liitajad-$lihtajad);
    $kesk = ($ok_num ? $ok_aeg/$ok_num : 0);
    printf ("Leituid kokku %d, keskmiselt %.5f sek\n", $ok_num, $kesk);
    $kesk = ($no_num ? $no_aeg/$no_num : 0);
    printf ("Leidmata kokku %d, keskmiselt %.5f sek\n", $no_num, $kesk);
    printf ("Üldse kokku %d, keskmiselt %d sõnet sek\n", $no_num+$ok_num, ($no_num+$ok_num)/(time-$failiaeg));
}

sub analyysi {
    my $miski = shift;
    return unless $miski;
    foreach my $algne_s (split(/\s+/, $miski)) {
	next unless $algne_s;
	$algne_s = puhastasona ($algne_s);
	$s = lc($algne_s);
	next unless $s;
	return 1 if $lisad{$s};

	$tulemusi = 0;
	$liitajad -= time;

	analyysi_liitsona ($s);
	# lubame ka suurtähti
	analyysi_liitsona ($algne_s) if ($tulemusi == 0) and ($s ne $algne_s);
	# ki/gi kontroll
	if (
	    ($s =~ /.*[bcdfghjkpsšzžtx](?=ki$)/) or
	    ($s =~ /.*[aeijlmnoruvwõäöü](?=gi$)/)
	) {
	    $s = $&;
	    analyysi_liitsona ($s);
	}

	$liitajad += time;
	return $tulemusi;
    }
}

# suvateksti näitel:
# liitsõnaks jagamine eest taha 58 sek
# tagant ette 47 sek
# poole pealt taha-ette-taha 48 sek

sub analyysi_liitsona {
    my $sona = shift;

    $lihtajad -= time;
    analyysi_lihtsona ($sona, '');
    $lihtajad += time;
    return 1 if ($tulemusi and $esi);

    # töötleme liitsõnu: jaamaülemat
    # proovime tagant ette, kas esimene pool võib olla liitsõna algus
    # jaamaülem ja jaamaüle vastaku jaama+üle[m], jaamaül ja jaamaü peaks tagastama ?, jaama aga iseennast

    my $i = length($sona)-2;
    while ( $i > 1 ) {
	my $sonaalgus = substr $sona, 0, $i;
	my $sonalopp = substr $sona, $i;
	$i--;
	print "oletatav liitsonaalus: $sonaalgus -> " if $dbg;
	$sonaalgus = jaga_liitsonajuppideks ($sonaalgus);
	print "$sonaalgus\n" if $dbg;
	next if $sonaalgus eq '?';

	# siis vaatame, kas ka tagumine ots on mõistlik
	# at ja mat ei ole, ülemat aga on
	$lihtajad -= time;
	analyysi_lihtsona ($sonalopp, $sonaalgus);
	$lihtajad += time;
	return 1 if ($tulemusi and $esi);
    }

    return $tulemusi;
}

sub analyysi_lihtsona {
    my $sona = shift;
    my $liitsonaalgus = shift;
    $liitsonaalgus .= '+' if $liitsonaalgus;
    print "analyysi_lihtsona sisend: $liitsonaalgus $sona\n" if $dbg;

    my $tyvebaasityvekoodid = '';

    if ( $muutumatud{$sona} ) {
	$tyvebaasityvekoodid = $muutumatud{$sona};
	while ($tyvebaasityvekoodid =~ /:([^:]+):/) {
	    $tyvebaasityvekoodid = $` . ':' . $';
	    my $tbinf = $1;
	    print "$liitsonaalgus$sona $tbinf\n" unless $err;
	    print "\tmuutumatu: $liitsonaalgus$sona $tbinf\n" if $dbg;
	    $tulemusi++;
	    return if $esi;
	}
    }

    if ( $erandid{$sona} ) {
	$tyvebaasityvekoodid = $erandid{$sona};
	while ($tyvebaasityvekoodid =~ /:([^:]+):/) {
	    $tyvebaasityvekoodid = $` . ':' . $';
	    my $tbinf = $1;
	    print "$tbinf\n" unless $err;
	    print "\terand: $liitsonaalgus$sona $tbinf\n" if $dbg;
	    $tulemusi++;
	    return if $esi;
	}
    }

    # parem lühemalt lõpult pikema poole alustades null-lõpuga
    # pikem lõpp saaks täpsem, aga lühem on tõenäolisem ja spellerina kiirem
    # my $i = 2; while ( $i <= length($sona) ) {

    my $tyvepikkus = length($sona);
    while ( $tyvepikkus >= 2 ) {
	my $sonaalgus = substr $sona, 0, $tyvepikkus;
	my $sonalopp = substr $sona, $tyvepikkus;
	$tyvepikkus--;

	print "\türitan lihtsona jagada $sonaalgus + $sonalopp\n" if $dbg;
	my $tyvebaasityvekoodid = $tyvebaas{$sonaalgus};
	if (! $tyvebaasityvekoodid) {
	    print "\t... $sonaalgus ei ole tüvebaasis\n" if $dbg;
	    next;
	}
	# jah, vahemalt yks selline tyvi on tyvebaasis olemas
	print "\t... $sonaalgus on tüvebaasis kujul $tyvebaasityvekoodid\n" if $dbg;

	#jagame mugavamalt massiiviks
        my @tbkoodid = ();
        while ($tyvebaasityvekoodid =~ /:([^:]+):/) {
	    $tyvebaasityvekoodid = $` . ':' . $';
	    push @tbkoodid, $1;
	}

	# initsialiseerisime kujul $ftb{$formatiiv}{$tyvekood}{$tingimus} = $vormikood(;$vormikood)*
	if (! scalar(keys %{ $ftb{$sonalopp} })) {
	    print "\t... aga sonalopp $sonalopp ei ole lubatud formatiiv\n" if $dbg;
	    next;
	}

	foreach my $tbinf (@tbkoodid) {
	    print "\tvaatlen tyveinfot $tbinf\n" if $dbg;
	    my ($tbtk, $lemma, $sliik) = split (/#/, $tbinf);

	    if (! scalar(keys %{ $ftb{$sonalopp}{$tbtk} })) {
		print "\t... kombinatsioon $sonalopp + $tbtk puudub formtabis\n" if $dbg;
		next;
	    }

	    # tk on yhine nii tyvel kui lopul
	    # aga kas tingimus klapib?
	    foreach my $ting (keys %{ $ftb{$sonalopp}{$tbtk} }) {
		print "\tkas $sonaalgus vastab tingimusele $ting?\n" if $dbg;
		my $uuslemma = testitingimust ($sonaalgus, $ting);
		if ($uuslemma) {
		    $vormikood = $ftb{$sonalopp}{$tbtk}{$ting};
		    print "$vormikood $liitsonaalgus$uuslemma + $sonalopp\n" unless $err;
		    $tulemusi++;
		    return if $esi;
		}
		else { print "\t...kahjuks ei\n" if $dbg; }
	    }
	}
    }
}
