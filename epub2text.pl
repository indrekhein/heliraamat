#!/usr/bin/perl -w
use utf8;

require '/home/indrek/tarkvara/muutujad.ini';
our $in_dir;
our $out_dir;
our $bin_dir;

# teose pealkiri, failinimi ilma laiendita
# sellest teeme kataloogid in ja out sisse
my $toonimi = '';

if (scalar(@ARGV) != 1) {
    print "Lisa käsureale epubi faili nimi sissetulevate tööde kataloogis\n";
    exit;
}

my $epub_fn = $ARGV[0];

# sisendist eemaldame raja. Sisend PEAB olema in-kataloogis
$epub_fn = $' if $epub_fn =~ /.*\//;

if ($epub_fn !~ /^([^\/]+)\.epub$/i) {
    print "$epub_fn ei ole laiendiga .epub\n";
    exit;
}
$toonimi = $1;

# teeme ajutise lahtipakkimise in-kataloogi
# mõlemad nimed absoluutse rajaga
my $tmp_dir = $in_dir . '/' . $toonimi;
$epub_fn = $in_dir . '/' . $epub_fn;

if (! -e $epub_fn) {
    print "Faili $epub_fn ei ole selles kataloogis\n";
    exit;
}

#Kustutame kui eelmine sama nimega juba ees on
`rm -rf $tmp_dir` if -d $tmp_dir;
`unzip $epub_fn -d $tmp_dir`;
print "Pakkisin lahti\n";

my $containerxml = $tmp_dir . '/META-INF/container.xml';
if (! -e $containerxml) {
    print "Puudub kohustuslik $containerxml?\n";
    exit;
}
print "Avasin konteineri\n";

my $rootfile = '';
open (H, "<$containerxml");
binmode (H, ":utf8");
while (<H>) {
    chomp;
    $rootfile .= $_;
}
close (H);

my $contentfile = '';
while ($rootfile =~ /<rootfile.*?>/) {
    my $rf = $&;
    $rootfile = $';
    next unless $rf =~ / media\-type\s*=\s*\"application\/oebps\-package\+xml\"/;
    next unless $rf =~ / full\-path\s*=\s*\"(.+?)\"/;
    $contentfile = $1;
    last;
}

if ($contentfile eq '') {
    print "Puudub kohustuslik <rootfile> või tundmatu media-type vms?\n";
    exit;
}

$contentfile = $tmp_dir . '/' . $contentfile;
print "Sisukorrafail peaks olema $contentfile\n";

if (! -e $contentfile) {
    print "Sisukorrafail $contentfile ise puudub?\n";
    exit;
}

my $manifest = '';
open (H, "<$contentfile");
binmode (H, ":utf8");
while (<H>) {
    chomp;
    $manifest .= $_;
}
close (H);

if ($manifest =~ /<manifest>.+?<\/manifest>/) {
    $manifest = $&;
} else {
    print "Sisukorrafailis puudub kohustuslik <manifest>?\n";
    exit;
}

# failid on suhtelise teega contentfile suhtes
exit unless $contentfile =~ /\/[^\/]+$/;
my $oebps_dir = $`;

%failid = ();
my $faili_jrk = 1;

while ($manifest =~ /<item .*?>/) {
    my $item = $&;
    $manifest = $';
    next unless $item =~ / media\-type\s*=\s*\"application\/xhtml\+xml\"/;
    next unless $item =~ / href\s*=\s*\"(.+?)\"/;
    $failid{$1} = $faili_jrk++;
    print "\tsisu: $1\n";
}
if (scalar(keys %failid) == 0) {
    print "Leidsin mis vaja... aga mitte sobivaid (HTML) faile\n";
    exit;
}

my $res_dir = $out_dir . '/' . $toonimi;

# Kustutame kui eelmine sama nimega juba ees on
# sellega tegeleb kõrgem tase, siin eeldame, et ei tohi ise kustutada
#`rm -rf $res_dir` if -d $res_dir;
mkdir $res_dir unless -d $res_dir;

# Teeme ühe suure tekstifaili
my $fn_out = $res_dir . '/' . $toonimi . '.txt';
open (T, ">$fn_out");
binmode (T, ":utf8");

foreach my $fn (sort {$failid{$a} <=> $failid{$b}} keys %failid) {
    my $fn_in = $oebps_dir . '/' . $fn;
    print "\t$fn_in >> $fn_out\n";
    html2txt ($fn_in);
}

close (T);

`rm -rf $tmp_dir` if -d $tmp_dir;

sub html2txt {
    my ($i) = @_;
    my $html = '';
    open (H, "<$i") or die ("Ei saa avada $i");
    binmode (H, ":utf8");
    while (<H>) {
	chomp;
	$html .= $_;
    }
    close (H);
    while ($html =~ /<(p|h\d)( [^<>\/]+)?>(.*?)<\/\1>/i) {
	$html = $';
	my $s = $3;
	# siin ainult html-spetsiifilised asendused
	# märgid jäägu unicode'i, morf saab aru ja text2fest lihtsustab
#	$s =~ s/>[^><]*<//g;
	$s =~ s/<[^><]*>//g;
	$s =~ s/\&nbsp;/ /g;
	print T "$s\n\n";
    }
}
