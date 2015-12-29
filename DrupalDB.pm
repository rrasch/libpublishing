# Author: Rasan Rasch <rasan@nyu.edu>

package DrupalDB;

use MyConfig;

my $dsn =
  "DBI:mysql:database=" . config('dbname') . ';host=' . config('dbhost');
my $dbh = DBI->connect($dsn, config('dbuser'), config('dbpass'))
  or $log->logdie($DBI::errstr);
my ($varname, $max_allowed_packet) =
  $dbh->selectrow_array("SHOW VARIABLES LIKE 'max_allowed_packet'");
if ($max_allowed_packet < 16777216)
{
	$log->logdie("max_allowed_packet ($max_allowed_packet) is too small.");
}
$dbh->disconnect;

1;

