# Subclass Log4::Log4perl
#
# Author: Rasan Rasch <rasan@nyu.edu>

package MyLogger;

# use Log::Log4perl qw(:easy :no_extra_logdie_message);

use parent 'Log::Log4perl';

use MyConfig;

MyLogger->wrapper_register(__PACKAGE__);

MyLogger->easy_init(
	{
		level  => config('log_level'),
		file   => "STDERR",
		layout => "[%d %p] %F{1}:%L %M (%c) %m%n"
	}
);

$Log::Log4perl::LOGDIE_MESSAGE_ON_STDERR = 0;

1;

