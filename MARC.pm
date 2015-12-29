#!/usr/bin/env perl
#
# Parse MARC XML records.
#
# Author: Rasan Rasch <rasan@nyu.edu>

package MARC;

use strict;
use warnings;
use XML::LibXML;

our $VERSION = "0.01";


sub new
{
	my ($class, $marc_file) = @_;
	my $self = {};
	$self->{doc} = XML::LibXML->load_xml(location => $marc_file);
	bless ($self, $class);
	return $self;
}

sub author
{
	shift->getval(100, "a");
}

sub title
{
	shift->getval(245, "a");
}

sub publiser
{
	shift->getval(260, "b");
}

sub pub_loc
{
	shift->getval(260, "a");
}

sub pub_date
{
	shift->getval(260, "c");
}

sub extent
{
	shift->getval(300, "a");
}

sub phys_details
{
	shift->getval(300, "b");
}

sub dimensions
{
	shift->getval(300, "c");
}

sub subject
{
	shift->getval(600);
}

sub getval
{
	my ($self, $tag, $code) = @_;
	my @values;
	my $xpath = "//marc:datafield[\@tag='$tag']";
	for my $data_field ($self->{doc}->findnodes($xpath))
	{
		$xpath = "./marc:subfield";
		$xpath .= "[\@code='$code']" if defined($code);
		{
			my @subvals = ();
			for my $subfield ($data_field->findnodes($xpath))
			{
				my $str = $subfield->to_literal;
				utf8::encode($str);
				push(@subvals, $str);
			}
			push(@values, join(" ", @subvals));
		}
	}
	return @values;
}

