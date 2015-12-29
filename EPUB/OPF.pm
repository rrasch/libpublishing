# Parse EPUB OPF records.
#
# Author: Rasan Rasch <rasan@nyu.edu>

package EPUB::OPF;

use strict;
use warnings;
use Cwd qw(abs_path);
use Data::Dumper;
use File::Basename;
use XML::LibXML;
use XMLUtil qw(getval);

our $VERSION = "0.01";

my $xpc = XML::LibXML::XPathContext->new();
$xpc->registerNs("o", "http://www.idpf.org/2007/opf");
$xpc->registerNs("dc", "http://purl.org/dc/elements/1.1/");


sub new
{
	my ($class, $opf_file) = @_;
	my $self = {};
	$self->{doc} = XML::LibXML->load_xml(location => $opf_file);
	$self->{file} = $opf_file;
	$self->{dir} = dirname($opf_file);
	bless ($self, $class);
	return $self;
}


sub filename
{
	my $self = shift;
	$self->{file};
}


sub title
{
	my $self = shift;
	$self->metadata("title");
}


sub metadata
{
	my $self = shift;
	my $field = shift;
	if ($field)
	{
		return getval($xpc, "/o:package/o:metadata/dc:$field", $self->{doc});
	}
	my $meta;
	for my $dc ($xpc->findnodes("/o:package/o:metadata/dc:*", $self->{doc}))
	{
		my $val = getval($xpc, ".", $dc);
		if ($meta->{$dc->localname}) {
			$meta->{$dc->localname} .= ", $val";
		} else {
			$meta->{$dc->localname} = $val;
		}
	}
	return $meta;
}


sub manifest
{
	my $self = shift;
	my $pattern = shift || '.';
	my $regexp = qr/$pattern/;
	my @files;
	my $xpath = '/o:package/o:manifest/o:item';
	for my $item ($xpc->findnodes($xpath, $self->{doc}))
	{
		my $href = getval($xpc, './@href', $item);
		my $mime = getval($xpc, './@media-type', $item);
		if ($mime =~ $regexp)
		{
			push(@files, abs_path("$self->{dir}/$href"));
		}
	}
	return wantarray ? @files : \@files;
}


sub toc_file
{
	my $self = shift;
	my $xpath = "/o:package/o:manifest/o:item[\@media-type='application/x-dtbncx+xml']/\@href";
	my $toc_file = getval($xpc, $xpath, $self->{doc});
	$toc_file = abs_path($self->{dir} . "/$toc_file");
	return $toc_file;
}


1;

