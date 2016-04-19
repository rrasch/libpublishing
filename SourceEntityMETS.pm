# Parse DLTS Source Entity METS documents for books.
#
# Author: Rasan Rasch <rasan@nyu.edu>

package SourceEntityMETS;

use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename;
use XML::LibXML;
use XMLUtil qw(getval);

our $VERSION = "0.01";

my $xpc = XML::LibXML::XPathContext->new();
$xpc->registerNs("m", "http://www.loc.gov/METS/");


sub new
{
	my ($class, $mets_file, $logger) = @_;
	my $self = {};
	$self->{doc} = XML::LibXML->load_xml(location => $mets_file);
	$self->{file} = $mets_file;
	$self->{id} = getval($xpc, '/m:mets/@OBJID', $self->{doc});
	$self->{logger} = $logger;

	bless ($self, $class);
	return $self;
}


sub by_order
{
	getval($xpc, './@ORDER', $a) <=> getval($xpc, './@ORDER', $b);
}


sub get_id
{
	my $self = shift;
	$self->{id};
}


sub get_file_ids
{
	my $self = shift;
	my $logger = $self->{logger};
	my @file_ids = ();
	my $xpath = '/m:mets/m:structMap/m:div/m:div/m:div[@ORDER]';
	for my $div (sort by_order $xpc->findnodes($xpath, $self->{doc}))
	{
		my $div_id = getval($xpc, './@ID', $div);
		my $dmaker_file_id = "";
		for my $fid_attr ($xpc->findnodes('./m:fptr/@FILEID', $div))
		{
			my $file_id = getval($xpc, '.', $fid_attr);
			if ($file_id =~ /_d$/) {
				$file_id =~ s/^f-//;
				$file_id =~ s/_d$//;
				$dmaker_file_id = $file_id;
				last;
			}
		}
		if (!$dmaker_file_id)
		{
			$logger->error("Missing dmaker for div $div_id.") if $logger;
			return undef;
		}
		push(@file_ids, $dmaker_file_id);
	}
	wantarray ? @file_ids : \@file_ids;
}


sub get_mods_file
{
	my $self = shift;
	my $cwd = dirname($self->{file});
	my $mods_file =
	  getval($xpc, q|//m:mdRef[@MDTYPE='MODS']/@xlink:href|, $self->{doc});
	$mods_file = abs_path("$cwd/$mods_file");
}


sub get_rights_file
{
	my $self = shift;
	my $cwd  = dirname($self->{file});
	my $rights_file =
	  getval($xpc, q|//m:mdRef[@MDTYPE='METSRIGHTS']/@xlink:href|,
		$self->{doc});
	$rights_file = abs_path("$cwd/$rights_file");
}


# get binding orientation, scan order, read order info
sub scan_data
{
	my $self = shift;
	my %scan_data;
	my $scan_data_str = getval($xpc, '//m:structMap/@TYPE', $self->{doc});
	for my $pair (split/\s+/, $scan_data_str)
	{
		my ($k, $v) = split(':', $pair);
		$scan_data{lc($k)} = lc($v);
	}
	return %scan_data;
}


1;
