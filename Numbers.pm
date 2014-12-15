# package Lingua::ET::Numbers;
package Numbers;
require 5.6.0;
use strict;
use warnings;
#use locale;
use utf8;
require Exporter;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
	number_to_word
	rom_to_int
);

our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

our @EXPORT = qw(number_to_word);

our $VERSION = '0.01';

my @yhesed =      qw ( null  üks  kaks  kolm  neli  viis kuus seitse  kaheksa  üheksa  kümme );
my @yhesed_gen =  qw ( nulli ühe  kahe  kolme nelja viie kuue seitsme kaheksa  üheksa  kümne );
my @yhesed_part = qw ( nulli ühte kahte kolme nelja viit kuut seitset kaheksat üheksat kümmet );
# the rest of the cases can be formed by adding $case ending to genitive stem

my @astmed = qw ( null tuhat miljon miljard triljon kvadriljon kvintiljon sekstiljon septiljon oktiljon noniljon detsiljon );

my @yhesed_ord =      qw ( nullis    esimene teine kolmas    neljas    viies    kuues    seitsmes    kaheksas    üheksas    kümnes );
my @yhesed_ord_gen =  qw ( nullinda  esimese teise kolmanda  neljanda  viienda  kuuenda  seitsmenda  kaheksanda  üheksanda  kümnenda );
my @yhesed_ord_part = qw ( nullindat esimest teist kolmandat neljandat viiendat kuuendat seitsmendat kaheksandat üheksandat kümnendat );

my @astmed_ord = qw ( null tuhat miljones miljardes triljones kvadriljones kvintiljones sekstiljones septiljones oktiljones noniljones detsiljones );

my $case = 'nom';	# set to desired case, default is nominative
my $kohakaane = 0;	# true for cases 4-10
my $ordi = 0;		# set to 1 for ordinals

sub number_to_word {
    my $num = shift;
    $case = 'nom';
    $ordi = 0;

    foreach (@_) {
	my $par = lc ($_);

	$ordi = 0 if ($par eq 'põhiarv') or ($par eq 'card') or ($par eq 'cardinal');
	$ordi = 1 if ($par eq 'järgarv') or ($par eq 'ord')  or ($par eq 'ordinal');

	$case = 'nom'  if ($par eq 'nimetav')    or ($par eq 'nim') or ($par eq 'nom');
	$case = 'gen'  if ($par eq 'omastav')    or ($par eq 'om')  or ($par eq 'gen');
	$case = 'part' if ($par eq 'osastav')    or ($par eq 'os')  or ($par eq 'part');

	$case = 'sse'  if ($par eq 'sisseütlev') or ($par eq 'sse') or ($par eq 'illatiiv');
	$case = 's'    if ($par eq 'seesütlev')  or ($par eq 's')   or ($par eq 'inessiiv');
	$case = 'st'   if ($par eq 'seestütlev') or ($par eq 'st')  or ($par eq 'elatiiv');
	$case = 'le'   if ($par eq 'alaleütlev') or ($par eq 'le')  or ($par eq 'allatiiv');
	$case = 'l'    if ($par eq 'alalütlev')  or ($par eq 'l')   or ($par eq 'adessiiv');
	$case = 'lt'   if ($par eq 'alaltütlev') or ($par eq 'lt')  or ($par eq 'ablatiiv');
	$case = 'ks'   if ($par eq 'saav')       or ($par eq 'ks')  or ($par eq 'translatiiv');

	$case = 'ni'   if ($par eq 'rajav')      or ($par eq 'ni')  or ($par eq 'terminatiiv');
	$case = 'na'   if ($par eq 'olev')       or ($par eq 'na')  or ($par eq 'essiiv');
	$case = 'ta'   if ($par eq 'ilmaütlev')  or ($par eq 'ta')  or ($par eq 'abessiiv');
	$case = 'ga'   if ($par eq 'kaasaütlev') or ($par eq 'ga')  or ($par eq 'komitatiiv');
    }
    $kohakaane = ($case =~ /^[slk]/);

    $num = rom_to_int ($num) if _isroman ($num);
    my $sign = '';
    $sign = 'miinus ' if $num =~ s/^\-//s;
    $sign = 'pluss ' if $num =~ s/^\+//s;

    # 0
    if ( $num eq '0' ) {
	if ( $case eq 'nom' ) {
	    return $yhesed_ord[$num] if $ordi;
	    return $yhesed[$num];
	}
	elsif ( $case eq 'gen' ) {
	    return $yhesed_ord_gen[$num] if $ordi;
	    return $yhesed_gen[$num];
	}
	elsif ( $case eq 'part' ) {
	    return $yhesed_ord_part[$num] if $ordi;
	    return $yhesed_part[$num];
	}
	else {
	    return $yhesed_ord_gen[$num] . $case if $ordi;
	    return $yhesed_gen[$num] . $case;
	}
    }

    return $sign . number_to_word($1) . ' koma ' . _frac_to_word($2) if $num =~ /^(\d+)[,.](\d+)$/;
    return $sign . _spell ($num) if $num =~ /^0\d+$/;
    return $sign . _rec_n2w ($num) if $num =~ /^\d+$/;;

    return $sign . $num;
}

1;


sub _rec_n2w_gen {
    my $n = shift;
    return undef unless defined $n and $n =~ /^\d{1,3}$/;
    my $sayone = shift;
    return '' if $n =~ /^0+$/;
    return $yhesed_gen[$n] if ( $n <= 10 );
    return $yhesed_gen[$n-10] . 'teistkümne' if ( $n < 20 );
    return $yhesed_gen[$1] . 'kümne' if ( $n =~ /^0?(.)0$/ );
    return $yhesed_gen[$1] . 'kümne ' . $yhesed_gen[$2] if ( $n =~ /^0?(.)(.)$/ );
    return ($sayone ? 'ühe' : '') . 'saja' if ( $n == 100 );
    return $yhesed_gen[$1] . 'saja' if ( $n =~ /^(.)00$/ );
    return ($sayone ? 'ühe' : '') . 'saja ' . _rec_n2w_gen ($1) if ( $n =~ /^1(..)$/ );
    return $yhesed_gen[$1] . 'saja ' . _rec_n2w_gen ($2) if ( $n =~ /^(.)(..)$/ );
}

sub _rec_n2w_part {
    my $n = shift;
    return undef unless defined $n and $n =~ /^\d{1,3}$/;
    my $sayone = shift;
    return '' if $n =~ /^0+$/;
    return $yhesed_part[$n] if ( $n <= 10 );
    return $yhesed_part[$n-10] . 'teistkümmet' if ( $n < 20 );
    return $yhesed_part[$1] . 'kümmet' if ( $n =~ /^0?(.)0$/ );
    return $yhesed_gen[$1] . 'kümne ' . $yhesed_gen[$2] if ( $n =~ /^0?(.)(.)$/ );
    return ($sayone ? 'ühte' : '') . 'sadat' if ( $n == 100 );
    return $yhesed_part[$1] . 'sadat' if ( $n =~ /^(.)00$/ );
    return ($sayone ? 'ühe' : '') . 'saja ' . _rec_n2w_gen ($1) if ( $n =~ /^1(..)$/ );
    return $yhesed_gen[$1] . 'saja ' . _rec_n2w_gen ($2) if ( $n =~ /^(.)(..)$/ );
}

sub _rec_n2w {
    my $n = shift;
    return undef unless defined $n and $n =~ /^\d+$/;

    # 101 -> hundred but 9100 -> nine thousand ONE hundred
    my $sayone = shift;

    return '' if $n =~ /^0+$/;

    # 1 .. 10
    if ( $n <= 10 ) {
	if ( $case eq 'nom' ) {
	    return $yhesed_ord[$n] if $ordi;
	    return $yhesed[$n];
	}
	elsif ( $case eq 'gen' ) {
	    return $yhesed_ord_gen[$n] if $ordi;
	    return $yhesed_gen[$n];
	}
	elsif ( $case eq 'part' ) {
	    return $yhesed_ord_part[$n] if $ordi;
	    return $yhesed_part[$n];
	}
	else {
	    return $yhesed_ord_gen[$n] . $case if $ordi;
	    return $yhesed_gen[$n] . $case;
	}
    }

    # 11 .. 19
    if ( $n < 20 ) {
	if ( $case eq 'nom' ) {
	    return $yhesed_gen[$n-10] . 'teistkümnes' if $ordi;
	    return $yhesed[$n-10] . 'teist';
	}
	elsif ( $case eq 'gen' ) {
	    return $yhesed_gen[$n-10] . 'teistkümnenda' if $ordi;
	    return $yhesed_gen[$n-10] . 'teistkümne';
	}
	elsif ( $case eq 'part' ) {
	    return $yhesed_gen[$n-10] . 'teistkümnendat' if $ordi;
	    return $yhesed_part[$n-10] . 'teistkümmet';
	}
	else {
	    return $yhesed_gen[$n-10] . 'teistkümnenda' . $case if $ordi;
	    return $yhesed_gen[$n-10] . 'teistkümne' . $case;
	}
    }

    # 20, 30 .. 90
    if ( $n =~ /^0?(.)0$/ ) {
	if ( $case eq 'nom' ) {
	    return $yhesed_gen[$1] . 'kümnes' if $ordi;
	    return $yhesed[$1] . 'kümmend';
	}
	elsif ( $case eq 'gen' ) {
	    return $yhesed_gen[$1] . 'kümnenda' if $ordi;
	    return $yhesed_gen[$1] . 'kümne';
	}
	elsif ( $case eq 'part' ) {
	    return $yhesed_gen[$1] . 'kümnendat' if $ordi;
	    return $yhesed_part[$1] . 'kümmet';
	}
	else {
	    return $yhesed_gen[$1] . 'kümnenda' . $case if $ordi;
	    return $yhesed_gen[$1] . 'kümne' . $case;
	}
    }


    # 21 .. 99
    if ( $n =~ /^0?(.)(.)$/ ) {
	if ( $case eq 'nom' ) {
	    return $yhesed_gen[$1] . 'kümne ' . $yhesed_ord[$2] if $ordi;
	    return $yhesed[$1] . 'kümmend ' . $yhesed[$2];
	}
	elsif ( $case eq 'gen' ) {
	    return $yhesed_gen[$1] . 'kümne ' . $yhesed_ord_gen[$2] if $ordi;
	    return $yhesed_gen[$1] . 'kümne ' . $yhesed_gen[$2];
	}
	elsif ( $case eq 'part' ) {
	    return $yhesed_part[$1] . 'kümne ' . $yhesed_ord_part[$2] if $ordi;
	    return $yhesed_part[$1] . 'kümmend ' . $yhesed_part[$2];
	}
	else {
	    return $yhesed_gen[$1] . 'kümne ' . $yhesed_ord_gen[$2] . $case if $ordi;
	    return $yhesed_gen[$1] . 'kümne ' . $yhesed_gen[$2] . $case;
	}
    }


    # 100 .. 999
    if ( $n == 100 ) {
	if ( $case eq 'nom' ) {
	    return ($sayone ? 'ühe' : '') . 'sajas' if $ordi;
	    return ($sayone ? 'üks' : '') . 'sada';
	}
	elsif ( $case eq 'gen' ) {
	    return ($sayone ? 'ühe' : '') . 'sajanda' if $ordi;
	    return ($sayone ? 'ühe' : '') . 'saja';
	}
	elsif ( $case eq 'part' ) {
	    return ($sayone ? 'ühe' : '') . 'sajandat' if $ordi;
	    return ($sayone ? 'üht' : '') . 'sadat';
	}
	else {
	    return ($sayone ? 'ühe' : '') . 'sajanda' . $case if $ordi;
	    return ($sayone ? 'ühe' : '') . 'saja' . $case;
	}
    }

    if ( $n =~ /^(.)00$/ ) {
	if ( $case eq 'nom' ) {
	    return $yhesed_gen[$1] . 'sajas' if $ordi;
	    return $yhesed[$1] . 'sada';
	}
	elsif ( $case eq 'gen' ) {
	    return $yhesed_gen[$1] . 'sajanda' if $ordi;
	    return $yhesed_gen[$1] . 'saja';
	}
	elsif ( $case eq 'part' ) {
	    return $yhesed_gen[$1] . 'sajandat' if $ordi;
	    return $yhesed_part[$1] . 'sadat';
	}
	else {
	    return $yhesed_gen[$1] . 'sajanda' . $case if $ordi;
	    return $yhesed_gen[$1] . 'saja' . $case;
	}
    }

    if ( $n =~ /^1(..)$/ ) {
	if ( $case eq 'nom' ) {
	    return ($sayone ? 'ühe' : '') . 'saja ' . _rec_n2w ($1) if $ordi;
	    return ($sayone ? 'üks' : '') . 'sada ' . _rec_n2w ($1);
	}
	elsif ( $case eq 'gen' ) {
	    return ($sayone ? 'ühe' : '') . 'saja ' . _rec_n2w ($1);
	}
	elsif ( $case eq 'part' ) {
	    return ($sayone ? 'ühe' : '') . 'saja ' . _rec_n2w ($1) if $ordi;
	    return ($sayone ? 'üht' : '') . 'sada ' . _rec_n2w ($1);
	}
	else {
	    return ($sayone ? 'ühe' : '') . 'saja ' . _rec_n2w ($1);
	}
    }

    if ( $n =~ /^(.)(..)$/ ) {
	if ( $case eq 'nom' ) {
	    return $yhesed_gen[$1] . 'saja ' . _rec_n2w ($2) if $ordi;
	    return $yhesed[$1]  . 'sada ' . _rec_n2w ($2);
	}
	elsif ( $case eq 'gen' ) {
	    return $yhesed_gen[$1] . 'saja ' . _rec_n2w ($2);
	}
	elsif ( $case eq 'part' ) {
	    return $yhesed[$1] . 'saja ' . _rec_n2w ($2) if $ordi;
	    return $yhesed_part[$1] . 'sada ' . _rec_n2w ($2);
	}
	else {
	    return $yhesed_gen[$1] . 'saja ' . _rec_n2w ($2);
	}
    }

    # 1000 .. 999999
    if ( $n == 1000 ) {
	if ( $case eq 'nom' ) {
	    return ($sayone ? 'ühe ' : '') . 'tuhandes' if $ordi;
	    return ($sayone ? 'üks ' : '') . 'tuhat';
	}
	elsif ( $case eq 'gen' ) {
	    return ($sayone ? 'ühe ' : '') . 'tuhandenda' if $ordi;
	    return ($sayone ? 'ühe ' : '') . 'tuhande';
	}
	elsif ( $case eq 'part' ) {
	    return ($sayone ? 'ühe ' : '') . 'tuhandendat' if $ordi;
	    return ($sayone ? 'ühte ' : '') . 'tuhandet';
	}
	else {
	    return ($sayone ? 'ühe ' : '') . 'tuhandenda' . $case if $ordi;
	    return ($sayone ? 'ühe ' : '') . 'tuhande' . $case;
	}
    }

    if ( $n =~ /^1(...)$/ ) {
	if ( $case eq 'nom' ) {
	    return ($sayone ? 'ühe ' : '') . 'tuhande ' . _rec_n2w ($1, 1) if $ordi;
	    return ($sayone ? 'üks ' : '') . 'tuhat ' . _rec_n2w ($1, 1);
	}
	elsif ( $case eq 'gen' ) {
	    return ($sayone ? 'ühe ' : '') . 'tuhande ' . _rec_n2w ($1, 1);
	}
	elsif ( $case eq 'part' ) {
	    return ($sayone ? 'ühe ' : '') . 'tuhande ' . _rec_n2w ($1, 1) if $ordi;
	    return ($sayone ? 'ühte ' : '') . 'tuhandet ' . _rec_n2w ($1, 1);
	}
	else {
	    return ($sayone ? 'ühe ' : '') . 'tuhande ' . _rec_n2w ($1, 1);
	}
    }

    if ( $n =~ /^(.{1,3})0{3,3}$/ ) {
	if ( $case eq 'nom' ) {
	    return _rec_n2w_gen ($1) . ' tuhandes' if $ordi;
	    return _rec_n2w ($1) . ' tuhat';
	}
	elsif ( $case eq 'gen' ) {
	    return _rec_n2w_gen ($1) . ' tuhandenda' if $ordi;
	    return _rec_n2w_gen ($1) . ' tuhande';
	}
	elsif ( $case eq 'part' ) {
	    return _rec_n2w_gen ($1) . ' tuhandendat' if $ordi;
	    return _rec_n2w_part ($1) . ' tuhandet';
	}
	elsif ( $kohakaane ) {
	    return _rec_n2w_gen ($1) . ' tuhandenda' . $case if $ordi;
	    return _rec_n2w_gen ($1) . $case . ' tuhande' . $case;
	}
	else {
	    return _rec_n2w_gen ($1) . ' tuhandenda' . $case if $ordi;
	    return _rec_n2w_gen ($1) . ' tuhande' . $case;
	}
    }

    if ( $n =~ /^(.{1,3})(.{3,3})$/ ) {
	if ( $case eq 'nom' ) {
	    return _rec_n2w_gen ($1) . ' tuhande ' . _rec_n2w ($2, 1) if $ordi;
	    return _rec_n2w ($1) . ' tuhat ' . _rec_n2w ($2, 1);
	}
	elsif ( $case eq 'gen' ) {
	    return _rec_n2w_gen ($1) . ' tuhande ' . _rec_n2w ($2, 1);
	}
	elsif ( $case eq 'part' ) {
	    return _rec_n2w_gen ($1) . ' tuhande ' . _rec_n2w ($2, 1) if $ordi;
	    return _rec_n2w_part ($1) . ' tuhandet ' . _rec_n2w ($2, 1);
	}
	else {
	    return _rec_n2w_gen ($1) . ' tuhande ' . _rec_n2w ($2, 1);
	}
    }


    # 10^6 .. 
    if (length($n) >= 7) {
	$ordi = 0;	# forget the ordinals. nobody uses them with that big numbers

	# check if it still fits in our scale
	$n =~ /^(.{1,3})((...)+)$/;
	my $aste = $astmed[length($2)/3];
	return _spell ($n) unless $aste;

	if ($n =~ /^1(000)+$/) {
	    return ($sayone ? 'üks ' : '') . $aste if $case eq 'nom';
	    return ($sayone ? 'ühe ' : '') . $aste . 'i' if $case eq 'gen';
	    return ($sayone ? 'ühte ' : '') . $aste . 'it' if $case eq 'part';
	    return ($sayone ? 'ühe ' : '') . $aste . 'i' . $case;
	}
	if ($n =~ /^1((...)+)$/) {
	    return 'üks ' . $aste . ' ' . _rec_n2w ($1, 1) if $case eq 'nom';
	    return 'ühe ' . $aste . 'i ' . _rec_n2w ($1, 1) if $case eq 'gen';
	    return 'ühte ' . $aste . 'it ' . _rec_n2w ($1, 1) if $case eq 'part';
	    return 'ühe ' . $aste . 'i ' . _rec_n2w ($1, 1);
        }
	if ($n =~ /^(.{1,3})((000)+)$/) {
	    return _rec_n2w ($1) . ' ' . $aste . 'it' if $case eq 'nom';
	    return _rec_n2w_gen ($1) . ' ' . $aste . 'i' if $case eq 'gen';
	    return _rec_n2w_part ($1) . ' ' . $aste . 'it' if $case eq 'part';
	    return _rec_n2w ($1) . ' ' . $aste . 'i' . $case if $kohakaane;
	    return _rec_n2w_gen ($1) . ' ' . $aste . 'i' . $case;
	}
	if ($n =~ /^(.{1,3})((...)+)$/) {
	    return _rec_n2w ($2, 1) if $1 == 0;
	    return _rec_n2w ($1) . ' ' . $aste . 'it ' . _rec_n2w ($2, 1) if $case eq 'nom';
	    return _rec_n2w_gen ($1) . ' ' . $aste . 'i ' . _rec_n2w ($2, 1) if $case eq 'gen';
	    return _rec_n2w_part ($1) . ' ' . $aste . 'it ' . _rec_n2w ($2, 1) if $case eq 'part';
	    return _rec_n2w_gen ($1) . ' ' . $aste . 'i ' . _rec_n2w ($2, 1);
	}
    }

    return _spell ($n);
}

sub _spell {
    my $n = shift;
    return join (' ', map { $yhesed[$_] } split(//, $n));
}

sub _frac_to_word {
    my $n = shift;
    return _spell ($1) . ' ' . _rec_n2w ($2) if $n =~ /^(0+)([1-9]{1,2})$/;
    return _spell ($n) if $n =~ /^0/;
    return number_to_word ($n) if $n < 1000;
    return _spell ($n);
}

our %roman2arabic = qw (I 1 V 5 X 10 L 50 C 100 D 500 M 1000);

sub _isroman($) {
    my $s = shift;
    $s ne '' and
    $s =~ /^(?: M{0,3})
        (?: D?C{0,3} | C[DM])
        (?: L?X{0,3} | X[LC])
        (?: V?I{0,3} | I[VX])$/ix;
}

sub rom_to_int($) {
    my $s = shift;
    _isroman $s or return undef;
    my $last_digit = 0;
    my $res;
    foreach ( reverse split(//, uc $s) ) {
	my ($digit) = $roman2arabic{$_};
	$res -= 2*$digit if $last_digit > $digit;
	$res += ($last_digit = $digit);
    }
    $res;
}


__END__

=head1 NAME

Lingua::ET::Numbers - Perl extension to convert arabic or roman numerals to text in Estonian.

=head1 SYNOPSIS

    use Lingua::ET::Numbers;
    print number_to_word ('12,002');
    print number_to_word (1001, 'gen', 'ord');
    print number_to_word ('iv', 'ord');

=head1 DESCRIPTION

The C<Lingua::ET::Numbers> module exports just one function which can
be tuned to output numerals, either cardinal or ordinal in all cases.
The output string is tuned to mimic the way a human would read the
number out loud.

=head2 EXPORT

C<number_to_word> by default.

You can further export C<rom_to_int> to convert a correctly* formed Roman
numeral to integer.

* Despite popular opinion, 1999 cannot be written as IM.

=head1 PARAMETERS

First parameter is a numeral. It is the callers responsibility to
format it to (+|-)?(\d+)([.,]\d+)?
'1,000,000', '1 000 000', '- 3' etc are returned unchanged.

Without any additional parameters, the returned string corresponds to
a cardinal in nominative case.

=item ordinals

ord | ordinal | järgarv
card | cardinal | põhiarv (unnecessary, this is the default)

=item cases

nimetav    | nim | nom (again, the default)
omastav    | om  | gen
osastav    | os  | part
sisseütlev | sse | illatiiv
seesütlev  | s   | inessiiv
seestütlev | st  | elatiiv
alaleütlev | le  | allatiiv
alalütlev  | l   | adessiiv
alaltütlev | lt  | ablatiiv
saav       | ks  | translatiiv
rajav      | ni  | terminatiiv
olev       | na  | essiiv
ilmaütlev  | ta  | abessiiv
kaasaütlev | ga  | komitatiiv

=head1 ALGORITHM

Ugly.

Numbers in Estonian are sometimes compound words (200 == kakssada),
sometimes not (2000 == kaks tuhat). All the constituents decline,
even in compound words (200 in genitive is kahesaja).

There can be more than one ortographically legal way to decline:
200 in partitive is one of four variants of kaht(e?)sada(t?).
I have chosen the longest spellings, since this module is most
likely to be used in preparing texts for voice synthesis and longer
forms sound more unambiguous.

This module works with numbers up to 10^36 or so which will be
more than enough. Anything longer than that is just spelt digit by
digit.

=head1 VAGUE SPOTS

Plural is not implemented. Perhaps it will, if I see any need for it.

Ordinals are turned off for millions and higher numbers.

The use of ÜKS follows a general rule "output it only in the beginning
of the numeral". Thus "ÜKS miljon tuhat kolm" and not "ÜKS miljon
ÜKS tuhat kolm".

Practical use differs from the general rule "Only the last component
in illative to ablative, all the rest in genitive". When the numeral
is short, the first part usually assumes the same case. Cf
"kahe tuhande kolmesaja+le" and "kahe+le tuhande+le kolmesaja+le"
and even more widespread "kahe tuhande+le" vs commonly met
"kahe+le tuhande+le". In the absence of clear rules, this is implemented
for thousands and higher but only when this ends the sequence.
Thus 'nelja+ks tuhande+ks', but 'nelja tuhande üheks'

=head1 BUGS

=head1 AUTHOR

rom_to_int function is taken from the Roman module by Ozawa Sakuro and
Alexandr Ciornii.

Indrek Hein <lt>indrek.hein eki.ee<gt>


=head1 SEE ALSO

    Lingua::EN::Numbers
    Lingua::TR::Numbers
    Roman

=head1 COPYRIGHT

    Copyright (c) 2012 Indrek Hein. All rights reserved.

    This library is free software.
    You can redistribute it and/or modify it under the same terms as Perl itself.

=cut
