# Author: Rasan Rasch <rasan@nyu.edu>

package XMLUtil;

use parent Exporter;

use XML::LibXML;

@EXPORT_OK = qw(getval getval_noc);

sub getval
{
	my ($xpc, $xpath, $node, $want_raw, $default_val) = @_;
	my $found_node;
	if ($xpc) {
		($found_node) = $xpc->findnodes($xpath, $node);
	} else {
		($found_node) = $node->findnodes($xpath);
	}
	if (!$found_node)
	{
		return $default_val;
	}
	my $value = "";
	if ($want_raw) {
		for my $child ($found_node->nonBlankChildNodes())
		{
			$value .= $child->toString() . "\n";
		}
	} else {
		$value = $found_node->to_literal;
	}
	# XXX: Add this to get_leaf_vals
	my $doc = $node->getOwnerDocument;
	my $encoding = $doc->encoding();
	if (!$encoding || $encoding =~ /utf-?8/i)
	{
		utf8::encode($value);
	}
	return $value;
}


sub getval_noc
{
	return getval(undef, @_);
}


sub get_leaf_vals
{
	my ($xpc, $elem, $values, $exclude, $skip_empty) = @_;
	$exclude ||= "";
	my @children = $xpc->findnodes('*', $elem);
	if (@children)
	{
		for my $child (@children)
		{
			if ($child->localname ne $exclude)
			{
				get_leaf_vals($xpc, $child, $values, $exclude, $skip_empty);
			}
		}
	}
	else
	{
		my $val = $elem->to_literal;
		return if !$val && $skip_empty;
		utf8::encode($val);
		push(@$values, $val);
	}
}


1;
