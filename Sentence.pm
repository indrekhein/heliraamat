# package Lingua::ET::Sentence;
package Sentence;

require 5.6.0;
use strict;
use warnings;
use locale;
use utf8;
require Exporter;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
	get_sentences
	get_acronyms set_acronyms add_acronyms
	get_file_extensions set_file_extensions add_file_extensions
);

our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

our @EXPORT = qw(get_sentences);

our $VERSION = '0.01';

# will be filled with known abbrevations
my %ABBREVIATIONS;

# will be filled with known file extensions
my %FILE_EXTENSIONS;

# contains "real" consonant sounds
# sch, ch, st, ss, ... are spoken as one sound, that's way ?> and the alternation
# bb, dd, ... are not so often, but often used in acronyms
my $CONSONANT = qr/[bcdfghklmnpqrsšzžtvwx]/;

# common vocals in german
my $VOCAL = qr/[aeiouõäöüy]/;

# the characters that can be between sentences  (chr(150) is a dash, chr(160) is a nonbreaking whitespace)
my $LEADING_SENTENCE_CHAR = '[\s'.chr(150).chr(160).'?!>\#\.\-\*]';

# regexp for new lines (even DOS, or MAC - Mode)
my $NL = qr/(?>\r\n|\n|\r)/;

# Characters which could be quotation marks (171 and 187 are << and >> as one character)
my $QUOTE = q{\"\'<>} . chr(171) . chr(187);

# Punctation marks
my $PUNCT = q{\.!?};

# Preloaded methods go here.

sub get_sentences {
    my ($text) = @_;
    my @pos = ();
    my @sentences;
    my ($leading_chars,$sent,$rest);
    my $last_pos = 0;
    while ($text =~ m/ (?!\p{IsAlnum})		# End of sentence cannot be immediately before letters
						# This leaves m.a.j and e.Kr intact
	(?:
	    # normal end of sentence like .?!
	    [$PUNCT]				# End of sentence could be a punctation
	    (?![^\p{IsAlnum}\r\n]*[$PUNCT,])	# and not as the first of some punctations (incl. comma)
	    [$QUOTE()]*				# possibly followed by a quotation mark or bracket
	|
	    # or an empty line
	    (?=\s\s)				# so there must be at least two whitespaces 
	    (?=\s*?$NL \s*?$NL)			# exact, two line endings (possibly with spaces)
	|
	    \Z)/gsxo)				# or end of file 
    {
	($leading_chars,$sent) 
	    = substr($text,$last_pos,-$last_pos+pos($text)) 
		=~ /^($LEADING_SENTENCE_CHAR*)(.*)$/s;
	$rest = substr($text,pos($text),100);
	
	# fix empty sentences
	# every sentence has to include anything
	$sent !~ m/\p{IsAlnum}/ && next;
	
        # check only special cases, if not at end of text or paragraph
	if ($rest =~ m/^(?!\s*?$NL\s*?$NL)\s*\S/so) {
	    
            # fix bla bla" sagte er.
	    # in general it's a word followed by " or ' and followed by a lowercase word	    
	    $sent =~ /[$QUOTE]$/o && $rest =~ m/^[$QUOTE()\s]*([[:lower:]])/o && next;
	    
	    # fix enumerations
	    $sent =~ /\P{IsAlnum}\.\.[$QUOTE\)]?$/o && $rest !~ /^(?:\s*$NL){2}/o && next;
	          
	    # Abbrevations
	    # these are lowercase words of length 1, i.e letters
	    # or in ABBREVIATIONS list (ignores lower/upper case)
	    # or consist of only consonants/vowels
	    # or end too strangely with 4 consonants at the end
	    if ($sent =~ /([^\P{IsAlpha}\d]+)\.[$QUOTE\)]*?$/o) {
		length($1) == 1 and next;
		$_ = lc($1);
		$ABBREVIATIONS{$_} and next;
		/^$CONSONANT+$/o and next;
		/^$VOCAL+$/o and next;
		/$CONSONANT{4,}$/o and next; 
	    }

	    # Ordinal numbers like 1., 2., ...
	    # I treat all numbers till 39 as ordinal
	    # plus the numbers ending in ..00
	    $sent =~ /\d\.$/ && $sent =~ /(?<![\p{IsAlnum}\.\,])(\d+)\.$/ &&
		(($1 < 40) || (($1 > 1800) and ($1 < 2500)) || (($_ = $1) =~ /00$/ and $_ != 1900 and $_ != 2000 and $_ != 2100)) && next;

	    # A separate rule for number a|a.|aasta* sequence
	    $sent =~ /\P{IsAlpha}(\d+)\.$/ && $rest =~ /^\s*(a\.?|aasta)/ && next;

	    # Rational numbers, IP numbers, phone numbers like 127.32.2345
	    $sent =~ /\.$/ && $rest =~ /^\d/ && next;

	    # Something like domain adresses, URLs and so on
	    $sent =~ m{ (?=[hfnmg]) 
			(?:http|file|ftp|news|mailto|gopher) 
			:// 
                        [\p{IsAlnum}\.\%\_\/\:\-]+ 
                        (?<!\.) \.$ 
                      }xm 
		&& next;
	    $rest =~ /^([\p{IsLl}][[\p{IsLl}\d]*[\.\?:\/]?)+/o  
		&& $sent =~ /([[\p{IsLl}\d]+[\.\?:\/])+$/o && next;

	    # fix punctuation in brackets like: He hurried sic (!) Janet.
	    $sent =~ / \(  [$QUOTE\.!?\)]+  $/xo && next;

	    # fix filenames like "document1.doc"
	    # look in extension list or extension consists of consonants
	    if ($sent =~ /\.$/ && $rest =~ /^(\w{1,4})\b/) {
		$FILE_EXTENSIONS{$_ = lc($1)} && next;
		/^$CONSONANT+$/o && next;
	    }
	}
	$last_pos = pos($text);
	push @sentences, $sent;
	push @pos, [pos($text) - length($sent) => pos($text)] if wantarray;
    }
    return wantarray ? (\@sentences, \@pos) : \@sentences;
}

sub get_acronyms {
    return keys %ABBREVIATIONS;
}

sub set_acronyms {
    %ABBREVIATIONS = map {$_ => 1} @_;
}

sub add_acronyms {
    $ABBREVIATIONS{$_} = 1 foreach (@_);
}

sub get_file_extensions {
    return keys %FILE_EXTENSIONS;
}

sub set_file_extensions {
    %FILE_EXTENSIONS = map {$_ => 1} @_;
}

sub add_file_extensions {
    $FILE_EXTENSIONS{$_} = 1 foreach (@_);
}

sub BEGIN {
    $ABBREVIATIONS{$_} = 1 foreach qw(
	jaan veebr apr jun jul aug sept okt nov dets
	inc
	kt
	lp
	mlle
	mlles
	mme
	mmes
	prof
	reg
    );

    $FILE_EXTENSIONS{$_} = 1 foreach qw(
	doc html txt ps gz zip tar pdf gif jpeg mp3 bmp tmp exe com bat
	pl java c cc vbs pod pm phtml shtml dhtml php
    );
}

__END__

=head1 NAME

Lingua::ET::Sentence - Perl extension for tokenizing Estonian texts into sentences.

=head1 SYNOPSIS

    use Lingua::ET::Sentence;
    my $sentences = get_sentences($text);
    foreach (@$sentences) {
	print $nr++, "\t$_";
    }

    or

    use Lingua::ET::Sentence;
    my ($sentences, $positions) = get_sentences($text);
    for (my $i=0; $i < scalar(@$sentences); $i++) {
	print "\n", $nr++, "\t", 
	      $positions->[$i]->[0], "-", $positions->[$i]->[1], 
	      "\t", $sentences->[$i];
    }

=head1 DESCRIPTION

The C<Lingua::ET::Sentence> module contains the function get_sentences,
which splits text into its constituent sentences.
The result can be either a list of sentences in the text or
a list of sentences plus a list of their absolute positions in the text
It's based on a regular expression to find possible endings of sentences and
many little rules to avoid exceptions like acronyms or numbers.

There is a list of known abbrevations and a list of known file extensions,
which are used to distinguish acronyms and filenames from endings of sentences.
They can be extented or exchanged if needed.

=head2 EXPORT

C<get_sentences> by default.

You can further export the following methods:
C<get_sentences>, C<get_acronyms>, C<set_acronyms>, C<add_acronyms>, 
C<get_file_extensions>, C<set_file_extensions>, C<add_file_extensions>.

=head1 ALGORITHM

Basically, I use a "big" regular expression to find possible sentence endings.
This regular expression matches sequences of punctation chars (.?!),
possibly followed by quotation marks or brackets like "'), but never by comma.
An empty line is interpreted as sentence end, too, so is the end of text also.

Then, found possibilities of sentence endings are checked for exceptions.
To do this, I examine 2 substrings, the first from the last known sentence
end to the current position, the second starts at the current position and
has a length of 100 chars. So I can test the environment without any slow
substitutions and without using $`, ... . Before the check, I discard leading
spaces, or any other stuff from the beginning of the sentence.
I use some heuristics:

=over 8

=item Empty sentences

Sentences without any word letters don't make any sense.

=item Enumerations

Something like 7 .. 24 or 1, 2, ....

=item Abbreviations

One letter plus dot is always an abbreviation.
I, X, V and a, e are acronyms (I, X, V are Roman numerals, a. aasta, e. ehk).
Other uppercase letters, are treated according to the context. Only if they
are found in a short sentence (less than 25 chars), they are acronyms.
Well, that sounds strange, but it's a cool and a functional algorithm.

Last I look wether the word before the dot ends with a lot of consonants
or if the word at the possible end of sentence has only consonants or vowels
as letters. So I'm able to interprete "Lgp." in the right way.

=item Ordinal-Numbers

0., 1., 2., ..., 39. are ordinals just the same as 1st, 2nd, 3rd, ..., 39th.
In more than 50% these are just ordinals so a rule prohibits a sentence to
end on these numbers. However "Ma syndisin aastal 1955." is O.K..
To cover for the massive use of 'xxxx. aastal', all numbers followed
by a, a. or aasta* are also considered to be ordinal year numbers.
Thus, the sentence can end with any number over 40 followed by a period
unless 'year' follows.
Numbers ending in 00 like 100, 1000, ... are often used as 100th,
1000th, ... . They also do not end the sentence.

=item Rational Numbers, IP-Numbers, Phone-Numbers

Something like 127.32.2345.0 or 123.5 is fixed.

=item URLs

URLs often contain dots and question marks.
What looks like a URL will be right interpreted.
For me, a URL is something starting with http, file, ftp, ... .
Or it's a sequence of lowercase words divided by some punctations.
Lowercase is important, because many guys don't write a whitespace after the dot.
But even they start their sentences with an uppercase word.

=item Punctation in brackets.

An opening bracket before punctation signalizes an in-sentence sequence.

=item Filenames

In many documents, there are strings like "readme.html", "document1.doc"
and so on. I have a short list of usual file extensions.
If the word after the dot has only consonants (like html, ...),
it's a file extension (or anything else, strange) for me too.
I hope that it solves the problem.

=back

Allthough these are many rules, they are implemented to run fast.
There are no substitutions, no $`, ... .

=head1 FUNCTIONS

=over 7

=item get_sentences( $text )

The get sentences function takes a scalar containing ascii text as an argument.
In scalar context it returns a reference to an array of sentences that the text has been split into.
In list context it returns a list of a reference to an array of sentences and 
of a reference to an array of the absolute positions of the sentences.
Every positions is an array of two elements, 
the first is the start and the second is the ending of the sentence.
Calling the function in list context needs a little bit (ca. 5%) more time,
because of the extra amount for the position list.
Returned sentences are trimmed of white spaces and sensless beginnings.

=item get_acronyms(    )

This function will return the defined list for acronyms.

=item set_acronyms( @my_acronyms )

This function replaces the predefined acronym list with the given list.
Feel free to suggest me missing acronyms.

=item add_acronyms( @acronyms )

This function is used for adding acronyms not supported by this code.

=item get_file_extensions(    )

This function will return the defined list for file extensions.

=item set_file_extensions( @my_file_extensions )

This function replaces the predfined file extension list with the given list.
Feel free to suggest me missing file extensions.

=item add_file_extensions( @extensions )

This function is used for adding file extensions not supported by this code.

=back

=head1 BUGS

Sentences like 'Punktist A punkti B.' are misinterpreted, as B. is always an
acronym. The same happens with sentences ending with small numbers:
'Vaata peatykk 4 osa 6.'

Many abbreviations and file extensions may be missing, feel free to contact me.

If a sentence starts with the incorrect quotes >>quote<<,
the '>>' characters are removed.
It's not really a bug, it's a feature.
The module assumes that these are quotings from email like

  Andrea wrote:
  > ...
  > ...
  >
  >

You should use the right form of quoting: <<quote>>.

This module assumes that the input text is in utf-8. Locale isn't in
common use for Estonian. Posix character classes, notably \w do not cover
all necessary characters, so I replaced them with \p{IsAlnum}, \p{IsLl} etc.

=head1 AUTHOR

This code borrows heavily from the original Lingua::DE::Sentences by
Andrea Holstein E<lt>andrea_holsten@yahoo.deE<gt>

Indrek Hein E<lt>indrek.hein@eki.eeE<gt>


=head1 SEE ALSO

    Lingua::DE::Sentence
    Lingua::EN::Sentence
    Text::Sentence

=head1 COPYRIGHT

    Copyright (c) 2011 Indrek Hein. All rights reserved.

    This library is free software.
    You can redistribute it and/or modify it under the same terms as Perl itself.

=cut
