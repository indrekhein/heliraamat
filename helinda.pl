#!/usr/bin/perl -w

use Encode qw (encode decode);
use Unicode::Normalize;

require '/home/indrek/tarkvara/muutujad.ini';
our $in_dir;
our $out_dir;
our $bin_dir;

my $epub_fn = '';

use Getopt::Long;
sub argument { $epub_fn = shift; }
my $opt_uuesti = 0;
my $opt_haal = 'naine';
my $opt_keepwavs = 0;
my $opt_help = 0;
GetOptions (
    'uuesti:1' => \$opt_uuesti,
    'wav:1' => \$opt_keepwavs,
    'haal=s' => \$opt_haal,
    'abi' => \$opt_help,
    '<>' => \&argument
);
$opt_help = 1 unless $ARGV[1];

$opt_haal =~ tr/a-zA-Z_//c;
if ($opt_help) {
    print "Kasuta helinda.pl [võtmed] sisendfail\n";
    print "Sisendfail peab olema in/ kataloogis, sobib tekst, html või epub\n";
    print "Lubatud võtmed on:\n";
    print "  -u[uesti]  kustuta varasem väljund\n";
    print "  -w[av]     säilita vahepealsed wav-id\n";
    print "  -h[aal]    parameetrid on:\n";
    print "    mees, naine -- kasuta süntesaatori eelistatud mees- või naishäält\n";
    print "    tonu, eval, liisi, ... -- hääle nimi, süntees kasutab HTS-hääli\n";
    print "    tonu_hts, eval_clunits, liisi_cg, ... -- hääle nimi koos meetodiga\n";
    print "  -a[bi]     näita seda teadet\n";
    print "\n";
}
my $algusaeg = time();

# toonimi on teose pealkiri, failinimi ilma laiendita
# sellest teeme samanimelised kataloogid in ja out sisse
my $toonimi = '';

if (! $epub_fn) {
    print "Lisa käsureale faili nimi sissetulevate tööde kataloogis\n";
    exit;
}

# ilma rajata, sisendit võtame vastu ainult in-kataloogist
$epub_fn = $' if $epub_fn =~ /.*\//;

if ($epub_fn !~ /^([^\/]+)\.(epub|txt|html?)$/i) {
    print "$epub_fn ei ole laiendiga .epub, .html või .txt\n";
    exit;
}
$laiend = lc($2);			# võrdluseks väiketähelisel kujul

# festival ei taha utf8 failinimesid
$toonimi = decode ('utf-8', $1);
$toonimi = NFD($toonimi);
$toonimi =~ s/\pM//g;
$toonimi =~ s/[^\x{0}-\x{ff}]//g;

print "Töönimi on $toonimi\n";

# mõlemad nimed absoluutse rajaga
my $tmp_dir = $in_dir . '/' . $toonimi;
$epub_fn = decode('utf-8', $in_dir . '/' . $epub_fn);

if (! -e $epub_fn) {
    print "Faili $epub_fn ei ole kataloogis $in_dir\n";
    exit;
}

# -- LASEME KONVEIERI KÄIMA --

my $res_dir = $out_dir . '/' . $toonimi;
my $text_fn = "$out_dir/$toonimi/$toonimi.txt";

# Kui võti -u[uesti], siis kustutame vana out-kataloogi
if ($opt_uuesti) {
    print "Kustutan varemtehtud väljundi $res_dir\n";
    `rm -rf $res_dir` if -d $res_dir;
}
# teeme uue out-kataloogi, kui see puudus
mkdir $res_dir unless -d $res_dir;


# TXT ei vaja töötlust
if ($laiend eq 'txt') {
    `cp $epub_fn $text_fn`;
}

# HTML ei vaja töötlust, kui jõuga teha
# kasutame tekstipõhist brauserit w3m mitteinteraktiivselt
if (substr($laiend,0,3) eq 'htm') {
    `w3m -dump -o display_charset=UTF-8 $epub_fn > $text_fn`;
}

# EPUBi pakime lahti, konverteerime htmli ja liidame terviktekstiks
# See teeb /out alla töökataloogi ja sinna sisse ühe suure töönimi.txt
elsif ($laiend eq 'epub') {
    print "$bin_dir/epub2text.pl $epub_fn\n";
    @args = ("$bin_dir/epub2text.pl", $epub_fn);
    system (@args) == 0 or die "Kukkusin: $?";
}
print "\nSisend --> tekst ", (time()-$algusaeg), " sek.\n";

@args = ("$bin_dir/text2morf.pl", $text_fn);
system (@args) == 0 or die "Kukkusin: $?";
print "\nTekst --> morf ", (time()-$algusaeg), " sek.\n";

@args = ("$bin_dir/text2pron.pl", $text_fn);
system (@args) == 0 or die "Kukkusin: $?";
print "\nTekst --> hääldus ", (time()-$algusaeg), " sek.\n";

@args = ("$bin_dir/text2fest.pl", $text_fn);
push @args, "-u" if $opt_uuesti;
push @args, "-h", $opt_haal if $opt_haal;
system (@args) == 0 or die "Kukkusin: $?";
print "\nTekst --> festivali skript ", (time()-$algusaeg), " sek.\n";

my $fest_fn = "$out_dir/$toonimi/$toonimi.fst";
@args = (
    "/usr/bin/festival",
    "--datadir", "/home/indrek/speech/festival/lib/",
    "--libdir", "/usr/share/festival/",
    "-b", $fest_fn
);
system (@args) == 0 or die "Kukkusin: $?";

@args = ("$bin_dir/wavs2wave.pl", $text_fn);
push @args, "-w" if $opt_keepwavs;
system (@args) == 0 or die "Kukkusin: $?";
print "\nTekst --> mp3 ", (time()-$algusaeg), " sek.\n";


$algusaeg = time() - $algusaeg;
print "Valmis, kokku ", int($algusaeg/60), " min, ", $algusaeg%60, " sek.\n";
