#!/usr/bin/perl -w

use utf8;
binmode (STDOUT, ":utf8");

require '/home/indrek/tarkvara/muutujad.ini';
our $in_dir;
our $out_dir;
our $g_haalenimi;

my $text_fn = '';

use Getopt::Long;
sub argument { $text_fn = shift; }
my $opt_uuesti = 0;
my $opt_haal = '';
my $opt_help = 0;
GetOptions (
    'uuesti:1' => \$opt_uuesti,
    'haal=s' => \$opt_haal,
    'abi' => \$opt_help,
    '<>' => \&argument
);
$opt_help = 1 unless scalar(@ARGV);

# hääle lisamine parameetriks sunnib eelnevat kustutama
$opt_uuesti = 1 if $opt_haal;

# vaikimisi nagu muutujad.ini pakub
$opt_haal = $g_haalenimi unless $opt_haal;
$opt_haal = lc($opt_haal);
$opt_haal =~ tr/a-zA-Z_//c;
$opt_haal = 'tonu_hts' if $opt_haal eq 'mees';
$opt_haal = 'eval_hts' if $opt_haal eq 'naine';
$opt_haal = 'eval_hts' if $opt_haal eq 'nais';
$opt_haal .= '_hts' unless $opt_haal =~ /_/;
print "Hääl on $opt_haal\n";

if ($opt_help) {
    print "Kasuta text2fest.pl [võtmed] sisendfail\n";
    print "Sisendfail on tekst\n";
    print "Lubatud võtmed on:\n";
    print "  -u[uesti]  kustuta varasem väljund\n";
    print "  -h[aal]    parameetrid on:\n";
    print "    mees, naine -- kasuta süntesaatori eelistatud mees- või naishäält\n";
    print "    tonu, eval, liisi, ... -- hääle nimi, süntees kasutab HTS-hääli\n";
    print "    tonu_hts, eval_clunits, liisi_cg, ... -- hääle nimi koos meetodiga\n";
    print "  -a[bi]     näita seda teadet\n";
    print "\n";
}

if (! $text_fn) {
    print "Lisa käsureale tekstifail, mida töödelda\n";
    exit;
}

if ($text_fn !~ /(.+)\.txt$/i) {
    print "$text_fn ei ole laiendiga .txt\n";
    exit;
}
my $fest_fn = $1 . '.fst';

# wave_fn on põhi, millele liidame haale, järjekorranumbri ja .wav
my $wave_fn = $1;

# Kui eelnev tuli kustutada, siis kustutame kõik wav-id
# muidu pole muudel skriptidel selge, kas viimati tehti blabla_tonu_hts_10000.wav
# või blabla_einar_hts_10000.wav, kui kataloogis on mõlemad.
# Kui väga vaja mitut varianti hoida, peab kutsuja andma parameetina
# kas alati täpse hääle nime või mingi töö ID.
if ($opt_uuesti) {
    `rm -f $wave_fn\*\.wav`;
}

# wave_fn on põhi, millele liidame haale, järjekorranumbri ja .wav
# alles pärast globaalsemat kustutamist saame hääle liita
$wave_fn .= '_' . $opt_haal;


# Loeme terve ette valmistatud teksti sisse
my @loigud = ();
$/ = '';
open (T, "<$text_fn") or die ("Ei saa avada $text_fn");
binmode (T, ":utf8");
while (<T>) {
    chomp;
    push @loigud, $_;
}
close (T);



open (FST, ">$fest_fn");
binmode (FST, ":encoding(ISO-8859-15)");

#print FST '(set! datadir "/home/indrek/speech/festival/lib")' . "\n";
#print FST '(set! libdir "/usr/share/festival")' . "\n";
#print FST '(load (path-append datadir "init.scm"))' . "\n";
print FST "(voice_eki_et_${opt_haal})\n";
print FST "\n\n";

my $loiguloendur = 10000;
my $vajateha = 0;
foreach my $l (@loigud) {
    my $loigunimi = $wave_fn . '_' . $loiguloendur++ . '.wav';
    next if -e $loigunimi;
    $l = fst_utf8 ($l);
    $l = fst_escape ($l);
    print FST '(set! utt1 (Utterance Text "' . $l . '"))' . "\n";
    print FST '(utt.synth utt1)' . "\n";
    print FST '(utt.save.wave utt1 "' . $loigunimi . '")' . "\n\n";
    $vajateha++;
}

# Teisendame mõned unicode'i sümbolid lihtsamasse kooditabelisse
sub fst_utf8 {
    my $s = shift;
    $s =~ s/…/.../g;
    $s =~ tr/—–„“”’•/\-\-"""'·/;
    return $s;
}

# festivali stringis olgu \ ja " varjestatud
sub fst_escape {
    my $s = shift;
    $s =~ s/\\/\\\\/g;
    $s =~ s/\"/\\\"/g;
    return $s;
}

close (FST);

print "Festivali sisendiks $vajateha lõiku (", $loiguloendur-10000-$vajateha, " juba oli valmis)\n";

