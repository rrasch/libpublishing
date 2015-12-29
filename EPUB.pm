# EPUB parser.
#
# Author: Rasan Rasch <rasan@nyu.edu>

package EPUB;

use strict;
use warnings;
use XML::LibXML;
use XMLUtil qw(getval);

our $VERSION = "0.01";

my $xpc = XML::LibXML::XPathContext->new();
$xpc->registerNs("c", "urn:oasis:names:tc:opendocument:xmlns:container");

my $epub_check = "epubcheck";

my $unzip = "unzip";

sub new
{
	my ($class, $epub_file, $output_dir) = @_;
	my $self = {};
	bless ($self, $class);
	$self->{epub_file} = $epub_file;
	$self->{epub_dir} = $output_dir;
	$self->extract($output_dir) unless -d $output_dir;
	$self->parse();
	return $self;
}


sub validate
{
	my $self = shift;
	system($epub_check, $self->{epub_file});
}


sub extract
{
	my $self = shift;
	my $output_dir = shift;
	system("unzip", "-d", $output_dir, $self->{epub_file});
}


sub parse
{
	my $self = shift;
	my $cont_file = "$self->{epub_dir}/META-INF/container.xml";
	$self->{container} = XML::LibXML->load_xml(location => $cont_file);
	$self->{cont_file} = $cont_file;
}


sub opf
{
	my $self = shift;
	my $xpath =
	  "//c:rootfile[\@media-type='application/oebps-package+xml']/\@full-path";
	my $opf_file =
	  "$self->{epub_dir}/" . getval($xpc, $xpath, $self->{container});
	$self->{opf} = EPUB::OPF->new($opf_file);
}


1;

