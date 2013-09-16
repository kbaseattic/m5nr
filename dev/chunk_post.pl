#!/usr/bin/env perl
use strict;
use warnings;

my $solr_port = "8983";
my $count = 0;
my @text = ();
my $tmp = "tmp.json";

my $size = int($ARGV[0]);
my $collection = $ARGV[1];

if ((@ARGV) && $ARGV[2]) {
    $solr_port = $ARGV[2];
}

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
	    my @out = `cat $tmp | java -Ddata=stdin -Dtype=application/json -Durl=http://localhost:$solr_port/solr/$collection/update -jar post.jar`;
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
    my @out = `cat $tmp | java -Ddata=stdin -Dtype=application/json -jar post.jar`;
    print "\t".join("\t", @out);
    unlink $tmp;
}
