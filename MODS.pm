# Parse MODS records.
#
# Author: Rasan Rasch <rasan@nyu.edu>

package MODS;

use strict;
use warnings;
use Date::Manip;
use LangCode;
use MARCCountry;
use URI::Escape;
use WWW::Mechanize;
use XML::LibXML;
use XMLUtil qw(getval getval_noc getvals);

our $VERSION = "0.01";

my $xpc = XML::LibXML::XPathContext->new();
$xpc->registerNs("m", "http://www.loc.gov/mods/v3");

my $map_api_url = "http://maps.googleapis.com/maps/api/geocode/xml?address=";

sub new
{
	my ($class, $mods_file, $lang) = @_;
	$lang ||= "";
	my $self = {};
	$self->{doc} = XML::LibXML->load_xml(location => $mods_file);
	$self->{file} = $mods_file;
	$self->{lang} = $lang;
	$self->{lang_attr_xpath} = $lang ? "[\@script='$lang']" : "";
	bless ($self, $class);
	return $self;
}


sub get_languages
{
	my $self = shift;
	my %lang;
	for my $script ($xpc->findnodes('//@script', $self->{doc}))
	{
		my $code = getval($xpc, ".", $script);
		$lang{$code} = 1;
	}
	return wantarray ? sort keys %lang : \%lang;
}


sub set_language
{
	my ($self, $lang) = @_;
	$self->{lang} = $lang;
	$self->{lang_attr_xpath} = $lang ? "[\@script='$lang']" : "";
}


sub author
{
	my $self    = shift;
	my @authors = ();
	my $xpath = "//m:mods/m:name[\@type='personal'";
	$xpath .= " and \@script='$self->{lang}'" if $self->{lang};
	$xpath .= "]";
	my @names = $xpc->findnodes($xpath, $self->{doc});
	for my $name (@names)
	{
		my @name_parts = $xpc->findnodes("./m:namePart", $name);
		my @role_terms =
		  $xpc->findnodes("./m:role/m:roleTerm[\@type='text']", $name);
		my $author =
		  join(", ", map(getval($xpc, ".", $_), @name_parts, @role_terms));
		push(@authors, $author);
	}
	return wantarray ? @authors : \@authors;
}


sub title
{
	my $self = shift;
	my $xpath = "/m:mods/m:titleInfo[not(\@type='uniform')";
	$xpath .= " and \@script='$self->{lang}'" if $self->{lang};
	$xpath .= "]";
	my $title = getval($xpc, "$xpath/m:nonSort", $self->{doc}) || "";
	$title .= " " if $title && $title !~ /\s+$/;
	$title .= getval($xpc, "$xpath/m:title", $self->{doc});
	return $title;
}


sub subtitle
{
	my $self = shift;
	my $xpath = "//m:titleInfo$self->{lang_attr_xpath}/m:subTitle";
	getval($xpc, $xpath, $self->{doc});
}


sub publisher
{
	my $self = shift;
	my $xpath = "//m:originInfo$self->{lang_attr_xpath}/m:publisher";
	getval($xpc, $xpath, $self->{doc});
}


sub pub_loc
{
	my $self = shift;
	my $xpath = "//m:originInfo$self->{lang_attr_xpath}";
	$xpath .= "/m:place/m:placeTerm[\@type='text']";
	getval($xpc, $xpath, $self->{doc});
}


sub pub_country
{
	my $self = shift;
	my $xpath = "//m:originInfo$self->{lang_attr_xpath}";
	$xpath .= "/m:place/m:placeTerm[\@type='code' ";
	$xpath .= "and \@authority='marccountry']",
	my $country_code = getval($xpc, $xpath, $self->{doc});
	MARCCountry::get_longname($country_code);
}


sub pub_date_all
{
	my $self = shift;
	my $xpath = "//m:originInfo$self->{lang_attr_xpath}/m:dateIssued";
	my $xpath_marc = $xpath . "[\@encoding='marc']";
	my @dates = $xpc->findnodes($xpath_marc, $self->{doc});
	@dates = $xpc->findnodes($xpath, $self->{doc}) if !@dates;
	my $date_str = join("-", map(getval($xpc, ".", $_), @dates));
	return $date_str;
}


sub pub_date_sort
{
	my $self = shift;
	my $date =
	     $self->get_valid_date('start')
	  || $self->get_valid_date()
	  || $self->pub_date_all();
	$date =~ s/u+$/0/;
	$date = "01/$date" if $date =~ /^\d{4}$/;
	return $date =~ /^\d{2}\/\d{4}$/ ? $date : "";
}


sub pub_date_formatted
{
	my $self  = shift;
	my $start = $self->get_valid_date('start');
	my $end   = $self->get_valid_date('end');
	return "$start-$end" if $start && $end;
	return
	     $start
	  || $end
	  || $self->get_valid_date()
	  || $self->pub_date_all();
}


sub get_valid_date
{
	my $self = shift;
	my $date_pt = shift;

	my $xpath = "//m:originInfo$self->{lang_attr_xpath}/m:dateIssued";

	my $xpath_marc = $xpath . "[\@encoding='marc'";
	$xpath_marc .= " and \@point='$date_pt'" if $date_pt;
	$xpath_marc .= "]";
	my $date_str = getval($xpc, $xpath_marc, $self->{doc});
	my $is_marc = 1;

	if (!$date_str)
	{
		$xpath .= "[\@point='$date_pt']" if $date_pt;
		$date_str = getval($xpc, $xpath, $self->{doc});
		$is_marc = 0;
	}

	return "" if !$date_str;

	# try to sanitize date string by removing any
	# leading and trailing non-alphanumeric 
	$date_str =~ s/^[[:^alnum:]]+//;
	$date_str =~ s/[[:^alnum:]]+$//;

	my $date = Date::Manip::Date->new();
	my $err = $date->parse($date_str);
	if (!$err)
	{
		my $curr_year = (localtime)[5] + 1900;
		my $mods_year = $date->printf('%Y');
		if ($mods_year > $curr_year) {
			return "";
		} elsif ($date_str =~ /^\d{4}$/) {
			return $mods_year;
		} else {
			return $date->printf('%m/%Y');
		}
	}
	else
	{
		return "";
	}
}


sub lang_code
{
	my $self  = shift;
	my $xpath = "//m:language/m:languageTerm[\@authority='iso639-2b'"
	  . " and \@type='code']";
	my @lang_codes = getvals($xpc, $xpath, $self->{doc});
	if (wantarray) {
		return @lang_codes;
	} else {
		return @lang_codes ? $lang_codes[0] : undef;
	}
}


sub language
{
	my $self = shift;
	LangCode::long_name($self->lang_code());
}


sub description
{
	my $self = shift;
	getval($xpc, "//m:abstract", $self->{doc});
}


sub num_pages
{
	my $self = shift;
	my $num_pages;
	my $phys_desc =
	  getval($xpc, "//m:physicalDescription/m:extent", $self->{doc});
	if ($phys_desc =~ /^(\d+)\s+p/)
	{
		$num_pages = $1;
	}
	return $num_pages;
}


sub subject
{
	my $self = shift;
	my @subjects = ();

	my $xpath = "//m:subject$self->{lang_attr_xpath}";
	my @subj_elems = $xpc->findnodes($xpath, $self->{doc});

	if ($self->{lang} eq "Latn")
	{
		$xpath = '//m:subject[not(@script)]';
		push(@subj_elems, $xpc->findnodes($xpath, $self->{doc}));
	}

	for my $subj_elem (@subj_elems)
	{
		my $subj_vals = [];
		XMLUtil::get_leaf_vals($xpc, $subj_elem, $subj_vals,
			'geographicCode', 1);
# 		for my $child_elem ($xpc->findnodes("./*", $subj_elem))
# 		{
# 			if ($child_elem->localname ne "geographicCode")
# 			{
# 				my $subj_val = getval($xpc, ".", $child_elem);
# 				$subj_val =~ s/^\s+//;
# 				$subj_val =~ s/\s+$//;
# 				$subj_val =~ s/\s*\n+\s*/, /g;
# 				$subj_val =~ s/\s+/ /g;
# 				push(@$subj_vals, $subj_val) if $subj_val;
# 			}
# 		}
		if (@$subj_vals)
		{
			my $subj_str = join(' -- ', @$subj_vals);
			push(@subjects, $subj_str);
		}
	}
	return wantarray ? @subjects : \@subjects;
}


sub geo_subject
{
	my $self = shift;
	my $xpath = "//m:subject[\@authority='lcsh']/m:geographic";
	my @geo_elems = $xpc->findnodes($xpath, $self->{doc});
	my %uniq_loc_list = ();
	for my $geo_elem (@geo_elems)
	{
		my $location = getval($xpc, ".", $geo_elem);
		$uniq_loc_list{$location} = 1;
	}
	my @loc = sort keys %uniq_loc_list;
	return wantarray ? @loc : join(", ", @loc);
}


sub geo_coordinates
{
	my $self = shift;
	my $xpath = "//m:subject[\@authority='lcsh']/m:geographic";
	my @geo_elems = $xpc->findnodes($xpath, $self->{doc});
	my %coord = ();
	for my $geo_elem (@geo_elems)
	{
		my $location = getval($xpc, ".", $geo_elem);
		if (!$coord{$location})
		{
			my ($lat, $lng) = lookup_coordinates($location);
			if (defined($lat) && defined($lng))
			{
				$coord{$location} = {
					location  => $location,
					latitude  => $lat,
					longitude => $lng,
				};
			}
		}
	}
	return if !%coord;
	my @results = sort { $a->{location} cmp $b->{location} } values %coord;
	return wantarray ? @results : \@results;
}


# Requires Googe MapsV3 API Key
sub lookup_coordinates
{
	my $location = shift;
	my $mech = WWW::Mechanize->new;
	$mech->get($map_api_url . uri_escape($location));
	my $content = $mech->content();
	my $resp = XML::LibXML->load_xml(string => $content);
	my $status = getval_noc("/GeocodeResponse/status", $resp);
	return if $status ne "OK";
	my ($result) = $resp->findnodes("/GeocodeResponse/result");
	my $lat = getval_noc("./geometry/location/lat", $result);
	my $lng = getval_noc("./geometry/location/lng", $result);
	return $lat, $lng;
}


sub series
{
	my $self = shift;
	my @series;
	my @titles = $xpc->findnodes(
		"//m:relatedItem[\@type='series']/m:titleInfo/m:title",
		$self->{doc});
	for my $title (@titles)
	{
		my ($name, $vol_str) = split(/\s*;\s*/, getval($xpc, ".", $title));
		my $vol_num;
		if ($vol_str && $vol_str =~ /(\d+)/)
		{
			$vol_num = $1;
		}
		push(
			@series,
			{
				name       => $name,
				volume_num => $vol_num,
				volume_str => $vol_str
			}
		);
	}
	return @series;
}


sub call_number
{
	my $self = shift;
	getval($xpc, "//m:classification[\@authority='lcc']", $self->{doc}); 
}


1;

