# Author: Rasan Rasch <rasan@nyu.edu>

package MARCCountry;

use File::Basename;
use XML::LibXML;
use XMLUtil qw(getval);

my $countries_file = dirname($INC{__PACKAGE__ . ".pm"}) . "/countries.xml";

my $xpc = XML::LibXML::XPathContext->new();
$xpc->registerNs("c", "info:lc/xmlns/codelist-v1");

my $countries = XML::LibXML->load_xml(location => $countries_file);

sub get_longname
{
	my $short_code = shift;
	getval($xpc, "/c:codelist/c:countries/c:country/c:code[text()='$short_code']/../c:name", $countries);
}

1;

