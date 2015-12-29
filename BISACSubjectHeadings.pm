# Load BISAC Subject Headings from tab delimited text file.
#
# Author: Rasan Rasch <rasan@nyu.edu>

package BISACSubjectHeadings;

use strict;
use warnings;
use File::Basename;

my $subject_file = dirname($INC{__PACKAGE__ . ".pm"}) . "/bisac.tsv";

my $heading = {};
open(my $in, $subject_file) or die("can't open $subject_file: $!");
while (my $line = <$in>)
{
	chomp($line);
	my ($code, $literal) = split(/\t/, $line);
	$heading->{$code} = $literal;
}
close($in);


sub heading
{
	my $code = shift;
	return $heading->{$code};
}


1;

