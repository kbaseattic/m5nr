#!/kb/runtime/bin/perl

use strict;
use warnings;
no warnings('once');

use Config::Simple;
use Data::Dumper;


my $CONFIG = '/kb/deployment/deployment.cfg';


if(-f $CONFIG){
	my $cfg      = new Config::Simple($CONFIG);
	my $m5nr_cfg = $cfg->param(-block=>'m5nr');
	my $url      = $m5nr_cfg->{'api_host'};
	
	print "URL:\t" . $m5nr_cfg->{'api_host'} , "\n";
	print join "\t" , @ARGV , "\n" ;
	
	my $command  = "m5nr-tools --api $url " . (join " " , @ARGV ) ;
	my $response = `$command` ;
	
	$response =~ s/m5nr-tools/m5nr/gc ;
	print $response ;

}
else{
	print STDERR "Can't read config ($CONFIG)\n";	
 	exit 1
}

