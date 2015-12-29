# Parse ONIX xml documents.
#
# Author: Rasan Rasch <rasan@nyu.edu>

package ONIX;

use strict;
use warnings;
use BISACSubjectHeadings;
use Data::Dumper;
use HTML::Entities;
use XML::LibXML;
use XMLUtil qw(getval_noc);

our $VERSION = "0.01";


sub new
{
	my ($class, $onix_file) = @_;
	my $self = {};
	$self->{doc} = XML::LibXML->load_xml(
		location => $onix_file,
		load_ext_dtd => 0,
	);
	($self->{product}) = $self->{doc}->findnodes('/ONIXMessage/Product');
	bless($self, $class);
	return $self;
}


sub num_products
{
	my $self = shift;
	my $products = $self->{doc}->findnodes('/ONIXMessage/Product');
	return $products->size;
}


sub isbn
{
	my $self = shift;
	my ($id_type) =
	  $self->{product}
	  ->findnodes('./ProductIdentifier/ProductIDType[string()="15"]');
	my $node = $id_type;
	my $isbn;
	while ($node = $node->nextSibling)
	{
		if ($node->nodeType() == XML_ELEMENT_NODE)
		{
			$isbn = $node->to_literal;
			last;
		}
	}
	return $isbn;
}


sub title
{
	my $self = shift;
	getval_noc('./Title/TitleText', $self->{product});
}


sub subtitle
{
	my $self = shift;
	getval_noc('./Title/Subtitle', $self->{product});
}


sub author
{
	my $self = shift;
	my @authors = ();
	my (@contributors) = $self->{product}->findnodes('./Contributor');
	for my $contrib (@contributors)
	{
		my $role = getval_noc('./ContributorRole', $contrib);
		my $name = getval_noc('./PersonName|./PersonNameInverted', $contrib);
		if ($role =~ /^[AB]\d{2}$/)
		{
			push(@authors, $name);
		}
	}
	return wantarray ? @authors : join(", ", @authors);
}


sub description
{
	my $self = shift;
	getval_noc('./OtherText/Text', $self->{product});
}


sub subject
{
	my $self = shift;
	my @subjects;
	for my $subject ($self->{product}->findnodes('./Subject'))
	{
		my $scheme_id = getval_noc('./SubjectSchemeIdentifier', $subject);
		my $code      = getval_noc('./SubjectCode',             $subject);
		my $text      = getval_noc('./SubjectText',             $subject)
		  || BISACSubjectHeadings::heading($code);
		push(
			@subjects,
			{
				scheme_id => $scheme_id,
				code      => $code,
				text      => $text,
			}
		);
	}
	return @subjects;
}


sub publisher
{
	my $self = shift;
	getval_noc('./Publisher/PublisherName', $self->{product});
}


sub pub_date
{
	my $self = shift;
	getval_noc('./PublicationDate', $self->{product});
}


sub lang_code
{
	my $self = shift;
	getval_noc('./Language/LanguageCode', $self->{product});
}


sub num_pages
{
	my $self = shift;
	getval_noc('./NumberOfPages', $self->{product});
}


1;
