# Module to query rstar collection API.
#
# Rasan Rasch <rasan@nyu.edu>

package RStar;

use strict;
use warnings;
use Data::Dumper;
use JSON;
use WWW::Mechanize;


sub new
{
	my ($class, %args) = @_;
	my $self = {};
	for my $arg (keys %args)
	{
		$self->{$arg} = $args{$arg};
	}
	$self->{ua} = WWW::Mechanize->new(autocheck => 0);
	$self->{ua}->credentials($self->{user} => $self->{pass});
	bless($self, $class);
	for my $type (qw(partner collection))
	{
		open(my $in, $self->{"${type}_file"})
		  or die(qq{Can't open $self->{"${type}_file"}: $!});
		chomp($self->{"${type}_url"} = <$in>);
		close($in);
		$self->{"${type}_info"} = $self->get_info($type);
	}
	return $self;
}


sub get_info
{
	my ($self, $type) = @_;
	my $resp = $self->{ua}->get($self->{"${type}_url"});
	if (!$resp->is_success)
	{
		print STDERR qq{Error retrieving $self->{"${type}_url"}: },
		  $resp->as_string, "\n";
		return;
	}
	my $content = decode_json($self->{ua}->content());
# 	print STDERR Dumper($content), "\n";
	return $content;
}


sub get_partner_info
{
	my $self = shift;
	$self->{partner_info};
}


sub get_collection_info
{
	my $self = shift;
	$self->{collection_info};
}


1;

