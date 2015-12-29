# Parse METS Rights
#
# Author: Rasan Rasch <rasan@nyu.edu>

package METSRights;

use strict;
use warnings;
use XML::LibXML;
use XMLUtil qw(getval);

our $VERSION = "0.01";

my $xpc = XML::LibXML::XPathContext->new();
$xpc->registerNs("m", "http://cosimo.stanford.edu/sdr/metsrights/");


sub new
{
	my ($class, $rights_file) = @_;
	my $self = {};
	$self->{doc} = XML::LibXML->load_xml(location => $rights_file);
	$self->{file} = $rights_file;
	bless ($self, $class);
	return $self;
}


sub declaration
{
	my $self = shift;
	getval($xpc, "//m:RightsDeclaration", $self->{doc});
}


1;

