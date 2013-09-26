#!/usr/bin/env perl
use strict;
use warnings;

my $size = int($ARGV[0]);
my $collection = $ARGV[1];

my $solr_port = "8983";
if ((@ARGV > 0) && $ARGV[2]) {
    $solr_port = $ARGV[2];
}

my $count = 0;
my @text = ();
my $tmp = "tmp.json";
my $cmd = "java -Ddata=stdin -Dtype=application/json -Durl=http://localhost:$solr_port/solr/$collection/update -jar post.jar";

while (my $line = <STDIN>) {
    chomp $line;
    $count += 1;
    push @text, $line;
    if ($size == $count) {
	    print "posting $count records to solr ...\n";
	    if (open(OUT, ">$tmp")) {
	        print OUT "[".join(",", @text)."]\n";
	        close OPEN;
	    }
	    my @out = `cat $tmp | $cmd`;
	    print "\t".join("\t", @out);
	    $count = 0;
	    @text = ();
	    unlink $tmp;
    }
}
if (@text > 0) {
    print "posting $count records to solr ...\n";
    if (open(OUT, ">$tmp")) {
	    print OUT "[".join(",", @text)."]\n";
	    close OPEN;
    }
    my @out = `cat $tmp | $cmd`;
    print "\t".join("\t", @out);
    unlink $tmp;
}
