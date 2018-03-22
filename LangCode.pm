# Author: Rasan Rasch <rasan@nyu.edu>

package LangCode;

use strict;
use warnings;
use File::Basename;

# To read the files, please note that one line of text contains one
# entry. An alpha-3 (bibliographic) code, an alpha-3 (terminologic)
# code (when given), an alpha-2 code (when given), an English name,
# and a French name of a language are all separated by pipe (|)
# characters. If one of these elements is not applicable to the
# entry, the field is left empty, i.e., a pipe (|) character
# immediately follows the preceding entry. The Line terminator is
# the LF character.

my $lang_code_file =
  dirname($INC{__PACKAGE__ . ".pm"}) . "/ISO-639-2_utf-8.txt";

my $long_name = {};
my $terminologic_code = {};
open(my $in, $lang_code_file) or die("can't open $lang_code_file: $!");
while (my $line = <$in>)
{
	chomp($line);
	my ($biblio_code, $term_code, $other_code, $eng_name, $fr_name) =
	  split(/\|/, $line);
	$long_name->{$biblio_code} = $eng_name;
	$terminologic_code->{$biblio_code} = $term_code;
}
close($in);

sub long_name
{
	my $biblio_code = shift;
	return $long_name->{$biblio_code};
}

sub term_code
{
	my $biblio_code = shift;
	return $terminologic_code->{$biblio_code};
}

1;

