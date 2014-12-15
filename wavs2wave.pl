#!/usr/bin/perl -w

use utf8;
binmode (STDOUT, ":utf8");

# muutujad.ini samas kataloogis, kus skript
my $muutini = $0;
$muutini = $& if $muutini =~ /^.*\//;
$muutini = $ENV{PWD} . '/' . $muutini if $muutini =~ /^\./;
$muutini .= 'muutujad.ini';
require $muutini;

our $out_dir;

# Initsialiseerime pärast parameetreid allpool
our $g_bitte;
our $g_sagedus;
our $g_kanaleid;
our $g_loigupaus;
our $g_pikempaus;
our $g_lausepaus;

my $text_fn = '';

use Getopt::Long;
sub argument { $text_fn = shift; }
my $opt_uuesti = 0;
my $opt_help = 0;
my $opt_keepwavs = 0;
GetOptions (
    'uuesti:1' => \$opt_uuesti,
    'wav:1' => \$opt_keepwavs,
    'abi' => \$opt_help,
    '<>' => \&argument
);
$opt_help = 1 unless scalar(@ARGV);

$g_bitte ||= 16;	# bits per sample
$g_sagedus ||= 48000;	# sampling rate
$g_kanaleid ||= 1;	# 1 mono
$g_loigupaus ||= 1.0;	# 1000 ms lõikude vahel
$g_pikempaus ||= 0.8;	# 600 ms mõttepunktid, kõnelejavahetus
$g_lausepaus ||= 0.4;	# 400 ms lausete vahel ( . ? ! )

$baitesekundis = $g_bitte/8 * $g_sagedus;

if ($opt_help) {
    print "Kasuta wavs2wave.pl [võtmed] sisendfail\n";
    print "Sisendfail on misiganes, samanimeline kataloog olgu out/ all\n";
    print "Lubatud võtmed on:\n";
    print "  -u[uesti]  kustuta varasem väljund\n";
    print "  -w[av]     säilita lõikude wav-id\n";
    print "  -a[bi]     näita seda teadet\n";
    print "\n";
}

if (! $text_fn) {
    print "Lisa käsureale fail, mida töödelda\n";
    exit;
}

# eemaldame laiendi kui selline peaks olema
$text_fn = $1 if $text_fn =~ /(.+)\.([a-z]*)$/i;
# eemaldame raja, töö peab leiduma out/ kataloogis
$text_fn = $' if $text_fn =~ /.*\//;
# ja saame kataloogi nime, kust otsida wav-e
$wdir = $out_dir . '/' . $text_fn;

my $raw = "$wdir/$text_fn.raw";
my $wav = "$wdir/$text_fn.wav";
my $mp3 = "$wdir/$text_fn.mp3";

unlink ($raw) if -e $raw;
unlink ($wav) if -e $wav;
unlink ($mp3) if -e $mp3;




# hääle-spetsiifilised:
$lisaparams = '';
# $lisaparams .= '  trim 0.075';	# see loikab Tonu algusest kropsu
# $lisaparams = ' ???';	# valjemaks-tasemaks jm mida sox oskab



# initsialiseerime kymnendiksekundise vaikusega
liidavaikus (0.1);

my $mask = $wdir . '/*.wav';
my @wavid = glob ($mask);
# kui juppe pole, me tööd ei tee
return unless scalar(@wavid);

foreach my $w (sort @wavid) {
    liidavaikus ($g_loigupaus);

    # lõik raw formaati
    system ("sox $w -r $g_sagedus -b $g_bitte -c $g_kanaleid -e signed-integer /tmp/ajutine.raw $lisaparams");

    # ja liidame tulemusele
    `cat /tmp/ajutine.raw >>$raw`;
    `rm /tmp/ajutine.raw`;

    # Kui seda lõiku enam ei vajata, võib nüüd kustutada
    unlink ($w) unless $opt_keepwavs;
}
# iluks sekund vaikust viimase otsa
liidavaikus (1);

# saadud .raw tagasi .wav-iks
system ("sox -r $g_sagedus -b $g_bitte -c $g_kanaleid -e signed-integer $raw $wav");
print "Tegin $wav valmis\n";
printf ("Lugemise pikkus %d minutit, %d sekundit\n", pikkus($raw) / 60, pikkus($raw) % 60);

unlink ($raw);

# saadud .wav MP3-ks
system ("lame --quiet $wav $mp3");
print "Tegin $mp3 valmis\n";

unlink ($wav);



# ----------------------------------------------------------

# tagastab hetkel valmis tehtud raw pikkuse sekundites
sub pikkus {
    my $fn = shift;
    return 0 unless -e $fn;
    my $pikkus = -s $fn;
    $pikkus = $pikkus/$baitesekundis;
    return $pikkus;
}

# lisab n sekundit vaikust augu taiteks
sub liidavaikus {
    my $sec = shift;
    if (-e $raw) { open (RAW, ">>$raw"); } else { open (RAW, ">$raw"); }
    binmode (RAW);
    # et nullide arv oleks ymar, meil 16 bitti = kahekaupa
    my $mitunulli = int (($baitesekundis*$sec) / ($g_bitte/8)) * ($g_bitte/8);
    for (1..$mitunulli) { printf RAW ("%c", 0); }
    close (RAW);
}

