#!/usr/bin/perl -w
use strict;
use warnings;
use lib "test/script-tests/";

use Data::Dumper;
use Test::More 'no_plan';
use JSON;

# assumption scripts are always in path
my $topDir = $ENV{KB_TOP_DIR} || "/";
my $service_repo = "m5nr" ;
my $prefix       = "nr" ; # script prefix
my $script_path = $topDir . "" ;
my $num_tests   = 0;
my $json        = new JSON;
my $success     = 1;

#my $test_path = "/Users/Andi/Development/kbase/communities_api/scripts" ;

my $scripts = {
    'nr-get-accession' => 1 ,
    'nr-get-function'  => 1 ,
    'nr-get-md5'       => 1 ,
    'nr-get-ontology'  => 1 ,
    'nr-get-organism'  => 1 ,
    'nr-get-sources'   => 1 ,
    'nr-get-taxonomy'  => 1 , 
    'nr-m5tools'       => 1 ,
};


# test help options
foreach my $script (keys %$scripts){
    
    # ignore scripts with status 0
    next unless ($scripts->{$script});

    my $message = undef ;
  eval{
    $message = `$script --help` ; 
  };

  if ( ok (`which $script` , "$script is deployed") ){
      
      subtest "$script does execute with --help" => sub {

	  my $exit_status = system("$script --help 1>output.log 2>error.log");
	  print "Warning: exit status greater 255:\t$exit_status\n" if ($exit_status > 255) ;
	  ok( ( $exit_status == 0 || $exit_status > 255 ) , "$script exists and executes: $script --help");
	  ok( -f "output.log" , '--help creates output');
	  isnt($message , undef ,"--help returns message");
	  ok(!( -s "error.log") , "$script --help returns no error:\t" . `cat error.log`);
      };
      if ( -z "error.log" ){
	  
	  subtest "Help message structure for $script"    => sub { &check_help($message)    } ;
	  subtest "Example for $script works" => sub { &check_example($script,$message) } ;
	  
	  #ok( &check_help($message) , "Help message structure");
	  #ok( &check_example($message) , "Example for $script executes without errors" );
      }
  }
 
}

#$num_tests += test_metagenome_query();
#$num_tests += test_metagenome_instance();


sub check_help{
  my ($message) = @_ ;
  my $success   = 1;

  my $keywords = [ 'NAME' , 'VERSION' , 'SYNOPSIS' , 'DESCRIPTION' , 'DESCRIPTION' , 'EXAMPLES' , 'SEE ALSO' , 'AUTHORS' ] ;

#
# Help should have follwoing structure
#

# NAME
#     mg-display-statistics
#
# VERSION
#     1
#
# SYNOPSIS
#     mg-display-statistics [ --help, --user <user>, --pass <password>, --token <oAuth token>, --id <metagenome id>, --stat <cv: 'sequence', taxa_level> ]
#
# DESCRIPTION
#     Retrieve statistical overview data for a metagenome from the communities API.
#
# Options:
#   -h, --help       show this help message and exit
#   --id=ID          KBase Metagenome ID
#   --url=URL        communities API url
#   --user=USER      username
#   --passwd=PASSWD  password
#   --token=TOKEN    OAuth token
#   --stat=STAT      type of stat to display, use keyword 'sequence' or taxa
#                    level name
#
# Output
#     -
#
# EXAMPLES
#     mg-display-statistics --id mgm4440026.3
#
# SEE ALSO
#     -
#
# AUTHORS
#     Jared Bischof, Travis Harrison, Tobias Paczian, Andreas Wilke
#

  foreach my $key (@$keywords){
    $success = 0 unless ( like($message, qr/$key/, "Help contains $key section") );
  }

  #return $success
}

sub check_example{
  my ($script, $message) = @_ ;
  my $success   = 1;

  my @lines = split "\n" , $message ;

  my $line = shift @lines ;
  while(@lines and not $line =~ /EXAMPLES/){
    #print $line , "\n";
    $line = shift @lines ;
  }

  # get example after EXAMPLES tag
  $line = shift @lines ;
  $line =~s/^\s*//; 
  #$line =~s/\|/\\\|/g;
  
  while( (! $line =~/$script/ ) and @lines ){
    $line = shift @lines ;
    $line =~s/^\s*//;  
  }
 
  my $return = undef ;

  
  $line        =~s/^\s*//;  
  my ($script) = $line =~/^($prefix-[\w\-]+)/;
  
  if ( ok( $script , "Example exists: $line") ){
  
      ok( exists $scripts->{$script} , "Script $script is in testing list.") ;
      ok(system("$line 1>output.log 2>error.log") == 0 , "Example exists and executes: $line") if ($line);
      my $return = system("$line 1>output.log 2>error.log") ;
      print "$script returned with $return\n";
      ok( -f "output.log" , 'Example returns output');
  }
}


sub test_metagenome_query {
    my $num_tests = 0;
    my $test_name = "get_metagenome_query";

	my $cmd;

	#######################################################################
	# happy path tests
	# ----------------
	# 1. verbosity = minimal, order = id, limit = 10, offset = 0
	$cmd = "$test_name -verbosity='minimal' -order='id' -limit=10 -offset=0 ";
	$num_tests += &test_response($cmd);	

	# 2. Let order = "name"
	$cmd = "$test_name -verbosity='minimal' -order='name' -limit=10 -offset=0 ";
	$num_tests += &test_response($cmd);	

	# 3. Let verbosity = default
	$cmd = "$test_name  -order='id' -limit=10 -offset=0 ";
	$num_tests += &test_response($cmd);	

	# 4. Let order = default
	$cmd = "$test_name  -verbosity='minimal' -limit=10 -offset=0 ";
	$num_tests += &test_response($cmd);	

	# 5. Let limit be default
	$cmd = "$test_name  -verbosity='minimal' -order='id' -offset=0 ";
	$num_tests += &test_response($cmd);	

	# 6. Let offset be default
	$cmd = "$test_name  -verbosity='minimal' -order='id' -limit=10 ";
	$num_tests += &test_response($cmd);	

	# 7. Let offset be nonzero
	$cmd = "$test_name  -verbosity='minimal' -order='id' -limit=10 -offset=10 ";
	$num_tests += &test_response($cmd);	

	# 8.  with empty parameters returns a method description object 
	$cmd = "$test_name   ";
	$num_tests += &test_response($cmd);	

	# 9. Verbosity=full
	$cmd = "$test_name  -verbosity='full' -limit=10 -offset=0 ";
	$num_tests += &test_response($cmd);	

	# 11. Verbosity=verbose
	$cmd = "$test_name  -verbosity='verbose' -limit=10 -offset=0 ";
	$num_tests += &test_response($cmd);	

	#######################################################################
	# invalid parameter tests - should fail nicely
	# --------------------------------------------
	# 1. verbosity = blah
	$cmd = "$test_name  -verbosity='blah' -order='id' -limit=10 -offset=10 ";
	$num_tests += &bad_response($cmd);	

	# 2. order = blah
	$cmd = "$test_name  -verbosity='minimal' -order='blah' -limit=10 -offset=10 ";
	$num_tests += &bad_response($cmd);	

	# 3. limit = blah
	$cmd = "$test_name  -verbosity='minimal' -limit='blah' -offset=10 ";
	$num_tests += &bad_response($cmd);	

	# 4. offset = blah
	$cmd = "$test_name  -verbosity='minimal' -limit=10 -offset='blah' ";
	$num_tests += &bad_response($cmd);	

   return $num_tests;
}

sub test_metagenome_instance {
    my $num_tests = 0;
    my $test_name = "get_metagenome_instance";
	my $test_id = "mgl52642";
	my @verbosities = ( 'minimal', 'verbose', 'full' );

	my $cmd;

	###########################################################################
	# Happy path tests
	# ----------------

	# with no parameters returns a method description object
	$cmd = "$test_name ";
	$num_tests += &test_response($cmd);	

	###########################################################################
	# Happy path tests
	# ----------------
	# loop through every verbosity with a single id and make sure they're good.
	foreach my $verbosity (@verbosities) {
		$cmd = "$test_name -verbosity=$verbosity -id=$test_id";
		$num_tests += &test_response($cmd);
	}

	###########################################################################
	# Invalid param tests
	# -------------------
	# 1. No id
	$cmd = "$test_name -verbosity='minimal'";
	$num_tests += &bad_response($cmd);	

	# 2. Invalid verbosity
	$cmd = "$test_name -id=$test_id -verbosity='blah'";
	$num_tests += &bad_response($cmd);	

    return $num_tests;
}

#--------------------------------------------------------------------------
#  Check that the command line returns without error
#  Did the response parse into JSON?

sub test_response
{
	my ($cmd) = @_;

	my $return = '';
	my $decode = '';
	eval { $return = `$cmd`; };
	is($@, '', "Calling \"$cmd\" ");

	eval { $decode = $json->decode($return); };
	is($@, '', "JSON return \"$cmd\" ");
#	is(ref($decode),'HASH',"Was the return in JSON?");

	return (2);
}


#--------------------------------------------------------------------------
#  Check that the command line returns with an error
#  1. The return code empty
#  2. The return is in JSON
#  3. The return contains the word error 

sub bad_response
{
	my ($cmd) = @_;

	my $return = '';
	my $error  = '';
	my $decode = '';

	eval { $return = `$cmd`; };
	is($@, '', "Bad Parameters \"$cmd\" ");

	eval { $decode = $json->decode($return); };
	is($@, '', "JSON return \"$cmd\" ");

	$error = $return if ($return =~ /error/i);
	isnt($error, '', "Return had the word error ");
#	print "DEBUG: RETURN=$return\n" if (length($return) < 5000);

	return (3);
}
