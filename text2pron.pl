#!/usr/bin/perl -w

use Sentence;
use Lyhvrk;
use Numbers;

# muutujad.ini samas kataloogis, kus skript
my $muutini = $0;
$muutini = $& if $muutini =~ /^.*\//;
$muutini = $ENV{PWD} . '/' . $muutini if $muutini =~ /^\./;
$muutini .= 'muutujad.ini';
require $muutini;

our $in_dir;
our $out_dir;

if (scalar(@ARGV) != 1) {
    print "Lisa käsureale tekstifail, mida töödelda\n";
    exit;
}

my $text_fn = $ARGV[0];

if ($text_fn !~ /(.+)\.txt$/i) {
    print "$text_fn ei ole laiendiga .txt\n";
    exit;
}

# kasutame, kui on, .err laiendiga leidmata sõnade loendit
my $err_fn = $text_fn . '.err';
# ja algne tekst kõrvale .alg laiendiga, teeme uue
my $orig_fn = $1 . '.alg';


# Loeme sisse hääldused, enne kui $/ muutub
%haaldused = ();
open (H, "<haaldussonastik/sonastik.csv") or die ("Ei saa avada hääldusi");
binmode (H, ":utf8");
while (<H>) {
    # csv sees on mõnikord tühje ridu, mis muidu annaksid vea
    chomp;
    next unless $_;

    #esimest ja viimast pole vaja
    my ($id, $voor, $lang, $hld, $jura) = split /,/;
    next unless $hld =~ /^\"(.+)\"/;	# praagime välja NULL ja tühja
    $hld = $1;
    next if $hld eq '+';		# hääldus nagu sõna ise
    next unless $voor =~ /^\"(.+)\"/;
    $voor = $1;

    # hääldused, mille üks keel on eesti, jäävad alati peale
    next if ($haaldused{$voor}) and ($lang ne '"et"');
    $haaldused{$voor} = $hld;
}
close (H);

# Loeme sisse tundmatud sõnad, enne kui $/ muutub
# .err on juba sorditud (ja lühem, nivetavaline tüvi eespool)
%tekstihaaldused = ();
open (H, "<$err_fn") or die ("Ei saa avada $err_fn");
binmode (H, ":utf8");
while (<H>) {
    chomp;
    next unless $_;
    my ($sone, $sagedus) = split /\t/;
    # mõni täht peab ikka olema, numbreid, vene keelt jms me ei taha
    next unless $sone =~ /[a-zA-Z]/;

    # kui haaldus on põhisõnastikus olemas
    if (my $haaldus = $haaldused{$sone}) {
	$tekstihaaldused{$sone} = $haaldus;
	next;
    }

    my $len = length($sone);
    my $tyvileiti = 0;
    # eelistame pikemat TYVE
    for (my $i=1; $i<7; $i++) {
	next if $len-$i < 2;
	my $tyvi = substr($sone, 0, $len-$i);
	my $lopp = substr($sone, -$i);
	next unless Lyhvrk::on_kaandelopp ($lopp);
	if (my $haaldus = $haaldused{$tyvi}) {
	    # sellist sõna hääldame kui tyve hääldus + käändelõpp
	    $tekstihaaldused{$sone} = $haaldus . $lopp;
	    $tyvileiti = 1;
	    last;
	}
    }
    next if $tyvileiti;
    # siin peaks uue tundmatu sõna hääldussõnastikku lisama
}
close (H);


my @loigud = ();
$/ = '';
open (T, "<$text_fn") or die ("Ei saa avada $text_fn");
binmode (T, ":utf8");
@loigud = (<T>);
close (T);

# rename kirjutab küsimata üle
rename $text_fn, $orig_fn;

open (T, ">$text_fn") or die ("Ei saa avada $text_fn");
binmode (T, ":utf8");


sub haaldus {
    my $sone = shift;
    if (my $haal = $tekstihaaldused{$sone}) {
	print "Hääldan $sone kui $haal\n";
	return $haal;
    }
    return $sone;
}


# teisendame lõigukaupa "loetavaks", asendades lühendid, numbrid, sodi
# loetavate sõnadega
foreach my $loik (@loigud) {
    # tühikud viisakaks
    $loik =~ s/[\s\n\r]+$//;
    $loik =~ s/^\s+//;
    $loik =~ s/\s+/ /g;

    my $laused = Sentence::get_sentences ($loik);
    foreach my $lause (@$laused) {

	$lause =~ s/([\pL]+)/&haaldus($1)/eg;

	# hetkel puuk järjendiga liha.võib
	$lause =~ s/(\pL{3,})\.(\pL{3,})/$1 $2/g;
	# hetkel puuk järjendiga E.G.W,
	$lause =~ s/(\pL)\.(\pL)\./$1 $2 /g;
	# hetkel puuk järjendiga ii,e
	$lause =~ s/(\pL),(\pL)/$1 $2/g;
	print T "$lause\n";
    }
    print T "\n";
}

close (T);
