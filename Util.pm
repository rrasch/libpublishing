# Various utility subroutines for content import.
#
# Author: Rasan Rasch <rasan@nyu.edu>

package Util;

use strict;
use warnings;
our $VERSION = '0.01';

use base 'Exporter';
our @EXPORT = qw(sys);
our @EXPORT_OK = qw(getval getval2);

use Capture::Tiny qw(capture_merged);
use Cwd qw(abs_path);
use Data::Dumper;
use File::Find;
use HTML::Entities;
use HTTP::Request::Common;
use Log::Log4perl qw(get_logger);
use MIME::Base64 qw(encode_base64);
use Text::Unidecode;
use Time::Duration;
use XML::LibXML;
use XML::Simple;
use WWW::Mechanize;
use MyConfig;
use MyLogger;


my $log = MyLogger->get_logger();

my %http_opts = (
	SendTE    => 0,
	KeepAlive => 1,
);

# create www agent to in to RestfulHS
my $agent = WWW::Mechanize->new();
$agent->credentials(config('handle_user'), config('handle_pass'));
$agent->add_header("Accept-Encoding" => undef);
if ($log->is_trace())
{
	$agent->add_handler("request_send",  sub { shift->dump; return });
	$agent->add_handler("response_done", sub { shift->dump; return });
}


my $samples = load_samples();


sub get_sample
{
	my $ext = shift;
	return $samples->{$ext};
}


sub load_samples
{
	my $samples    = {};
	my $sample_dir = config('sample_dir');
	if (!$sample_dir || !-d $sample_dir)
	{
		return;
	}
	my @files      = get_dir_contents($sample_dir);
	for my $file (@files)
	{
		if ($file =~ /\.([^.]+)$/)
		{
			my $ext       = lc($1);
			my $full_path = "$sample_dir/$file";
			$samples->{$ext} = {
				base64 => encode_file($full_path),
				size   => (stat($full_path))[7],
			};
		}
	}
	return $samples;
}


sub get_mediainfo
{
	my $input_file = shift;
	my $mediainfo = config('mediainfo');
	return XML::LibXML->load_xml(string => sys("$mediainfo $input_file"));
}


sub info
{
	my ($doc, $track_type, $elem) = @_;
	$doc->findvalue("/Mediainfo/File/track[\@type='$track_type']/$elem");
}


sub sys
{
	my @cmd = @_;
	my $cmd_str = join(" ", @cmd);
	$log->debug("running command $cmd_str");
	my $start_time = time;
	my ($retval, $errno);
	my $output = capture_merged {
		$retval = system(@cmd);
		$errno = $!;
	};
	my $end_time = time;
	$output =~ s/\r/\n/g;  # replace carriage returns with newlines
	$log->debug("output: $output");
	$log->debug("run time: ", duration_exact($end_time - $start_time));
	if ($retval)
	{
		if ($? == -1)
		{
			$log->logdie("failed to execute $cmd_str: $errno");
		}
		elsif ($? & 127)
		{
			$log->logdie(
				sprintf(
					"$cmd_str died with signal %d, %s coredump",
					($? & 127),
					($? & 128) ? 'with' : 'without'
				)
			);
		}
		else
		{
			$log->logdie(sprintf("$cmd_str exited with value %d", $? >> 8));
		}
	}
	return $output;
}


sub update_handle
{
	my ($handle, $path, $description) = @_;

	if ($path =~ /^\d+$/) {
		$path = "/node/$path";
	}
	
	my $target_url = $path =~ /^http/ ? $path : config('baseurl') . $path;

	my $update_url = config('handle_service_url') . "/$handle";
	$log->trace("Update URL: $update_url");

	$description ||= "";
	$description = unidecode($description);
	$description = substr($description, 0, 50);
	$description = encode_entities($description);

	my $xml = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<hs:info xmlns:hs="info:nyu/dl/v1.0/identifiers/handle">
    <hs:binding>$target_url</hs:binding>
    <hs:description>$description</hs:description>
</hs:info>
EOF

	local @LWP::Protocol::http::EXTRA_SOCK_OPTS = %http_opts;

	my $response = $agent->request(
		PUT(
			$update_url,
			Content_Type => 'text/xml',
			Content      => $xml
		)
	);

	if (!$response->is_success)
	{
		$log->logdie("Error updating handle at $update_url: ",
			$response->as_string);
	}

	$xml = XMLin($response->content, NormalizeSpace => 2);
	$log->debug(Dumper($xml));

	my $handle_url = "http://hdl.handle.net/$handle";
	if ($xml->{"hs:location"} ne $handle_url)
	{
		$log->logdie("Handle update failed. Expected '$handle_url' but got ",
			$xml->{"hs:location"});
	}
}


sub round
{
	my $num = shift;
	my $roundto = shift || 1;
	my $rounded = int($num / $roundto + 0.5) * $roundto;
	$log->debug("Rounded $num to $rounded");
	return $rounded;
}


sub encode_file
{
	my $file = shift;
	my $encoded = "";
	my $buf;
	open(my $in, $file) or $log->logdie("can't open $file: $!");
	while (read($in, $buf, 60 * 57))
	{
		$encoded .= encode_base64($buf);
	}
	close($in);
	return $encoded;
}


sub get_handle
{
	my $handle_file = shift;
	open(my $in, $handle_file)
		or $log->logdie("can't open $handle_file: $!");
	my $handle = <$in>;
	close($in);
	$handle =~ s/^\s+//;
	$handle =~ s/\s+$//;
	return $handle;
}


sub get_dir_contents
{
	my $dir_path = shift;
	opendir(my $dirh, $dir_path)
		or $log->logdie("can't opendir $dir_path: $!");
	my @files = sort(grep { !/^\./ } readdir($dirh));
	closedir($dirh);
	return @files;
}


sub zeropad
{
    my $num = shift;
    sprintf("%04d", $num);
}


sub getval2
{
	return getval(undef, @_);
}


sub getval
{
	my ($xpc, $xpath, $doc, $want_raw, $default_val) = @_;
	$log->trace("xpath: $xpath");
	my $node;
	if ($xpc) {
		($node) = $xpc->findnodes($xpath, $doc);
	} else {
		($node) = $doc->findnodes($xpath);
	}
	if (!$node)
	{
		$log->warn("Undefined value for expr $xpath");
		return $default_val;
	}
	my $value = "";
	if ($want_raw) {
		for my $child ($node->nonBlankChildNodes())
		{
			$value .= $child->toString() . "\n";
		}
	} else {
		$value = $node->to_literal;
	}
	utf8::encode($value);
	return $value;
}


sub file_as_string
{
	my $file = shift;
	my $buf  = "";
	open(my $in, $file) or $log->logdie("can't open $file: $!");
	while (my $line = <$in>)
	{
		$buf .= $line;
	}
	close($in);
	return $buf;
}


sub trunc
{
	my ($str, $max_length) = @_;
	return $str if !$str;
	$max_length ||= 255;
	return substr($str, 0, $max_length);
}


sub format_date
{
	my ($orig_date, $want_day) = @_;
	my $date = "";
	if ($orig_date =~ /^(\d{4})-?(\d{2})-?(\d{2})/) {
		my $year = $1;
		my $month = $2;
		my $day = $3;
		if ($want_day) {
			$date = "$month/$day/$year";
		} else {
			$date = "$month/$year";
		}
	}
	return $date;
}


sub get_noids
{
	my $num_ids = shift;
	my $noid_url = config('noid_url');
	my $content = get_url("$noid_url?mint+$num_ids");
	$log->trace($content);
	my @noids = $content =~ /id: ([\w-]+)/g;
	for (@noids)
	{
		$log->trace($_);
	}
	return wantarray ? @noids : $noids[0];
}


sub get_url
{
	my $url = shift;
	my $ua = LWP::UserAgent->new;
	$log->trace("Requesting $url");
	my $response = $ua->get($url);
	if (!$response->is_success)
	{
		$log->logdie("Problem requesting $url: ", $response->status_line);
	}
	return $response->content;
}


sub is_dir_empty
{
	my ($dir_name) = @_;
	opendir(my $dirh, $dir_name) or die("Can't opendir $dir_name: $!");
	while (my $entry = readdir($dirh))
	{
		unless ($entry =~ /^\.\.?$/)
		{
			close($dirh);
			return 0;
		}
	}
	close($dirh);
	return 1;
}


sub remove_empty_dirs
{
	my $dir_name = shift;
	finddepth(
		{
			wanted => sub {
				if (-d && is_dir_empty($_))
				{
					my $full_path = abs_path($_);
					$log->trace("removing $full_path");
					rmdir($full_path)
					  or $log->logdie("Can't rmdir $full_path: $!");
				}
			},
			no_chdir => 1
		},
		$dir_name
	);
}


1;


