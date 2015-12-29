# Parse METS Intellectual Entity documents.
#
# Author: Rasan Rasch <rasan@nyu.edu>

package IntellectualEntityMETS;

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
	my ($class, $mets_file) = @_;
	my $self = {};
	$self->{doc} = XML::LibXML->load_xml(location => $mets_file);
	$self->{file} = $mets_file;
	$self->{id} = getval($xpc, '/m:mets/@OBJID', $self->{doc});
	bless ($self, $class);
	return $self;
}


sub get_id
{
	my $self = shift;
	$self->{id};
}


sub is_multi_vol
{
	my $self = shift;
	$xpc->findnodes("/m:mets/m:structMap[\@TYPE='INTELLECTUAL_ENTITY']",
		$self->{doc});
}


sub by_order
{
	getval($xpc, './@ORDER', $a) <=> getval($xpc, './@ORDER', $b);
}


sub get_source_entities
{
	my $self = shift;
	my @source_entities = ();
	my $ie_dir = dirname($self->{file});
	my $xpath  = "/m:mets/m:structMap[\@TYPE='INTELLECTUAL_ENTITY']"
	  . "/m:div/m:div[\@TYPE='INTELLECTUAL_ENTITY']";
	for my $div (sort by_order $xpc->findnodes($xpath, $self->{doc}))
	{
		my $order_num   = getval($xpc, './@ORDER',             $div);
		my $order_label = getval($xpc, './@ORDERLABEL',        $div);
		my $mets_file   = getval($xpc, './m:mptr/@xlink:href', $div);
		$mets_file =~ s/#.*//;
		$mets_file = "$ie_dir/$mets_file";
		$mets_file = abs_path($mets_file);
		push(
			@source_entities,
			{
				order_num   => $order_num,
				order_label => $order_label,
				mets_file   => $mets_file
			}
		);
	}
	wantarray ? @source_entities : \@source_entities;
}


sub get_source_entity_files
{
	my $self = shift;
	my @se_mets_files = ();
	my $ie_dir = dirname($self->{file});
	for my $href ($xpc->findnodes('//m:mptr/@xlink:href', $self->{doc}))
	{
		my $path = $href->to_literal;
		$path =~ s/#.*//;
		$path = "$ie_dir/$path";
		$path = abs_path($path);
		push(@se_mets_files, $path);
	}
	my $se_mets_file = $se_mets_files[0];
	wantarray ? @se_mets_files : \@se_mets_files;
}


sub volume_number
{
	my ($self, $order_num) = @_;
	my $xpath = "//m:mptr/parent::m:div[\@ORDER='$order_num']/\@ORDERLABEL";
	my $vol_str = getval($xpc, $xpath, $self->{doc}) || "";
	my ($vol_num) = $vol_str =~ /^v\.(\d+)$/;
	return $vol_num;
}


1;

