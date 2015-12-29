# Author: Rasan Rasch <rasan@nyu.edu>

package MARCGeoArea;

use File::Basename;
use XML::LibXML;
use XMLUtil qw(getval);

my $geo_code_file = dirname($INC{__PACKAGE__ . ".pm"}) . "/gacs.xml";

my $xpc = XML::LibXML::XPathContext->new();
$xpc->registerNs("c", "info:lc/xmlns/codelist-v1");

my $geo_code = XML::LibXML->load_xml(location => $geo_code_file);

sub get_area_name
{
	my $short_code = shift;
	getval($xpc, "/c:codelist/c:gacs/c:gac/c:code[text()='$short_code']/../c:name", $geo_code);
}

1;

