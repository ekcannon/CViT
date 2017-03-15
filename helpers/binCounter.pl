#!/usr/bin/perl

# file: binCounter.pl
#
# purpose: Count number of records in a "bin".
#          Input file is GFF
#
# command:
#    perl binCounter.pl bin-size input-file

use strict;
use Data::Dumper;


if (scalar @ARGV < 2) {
  die <<EOS
  
  Count number of records in a bin.
  
  Usage: perl binCounter.pl bin-size input-gff-file
  
EOS

}

my ($bin_size, $gff_file) = @ARGV;

my $cur_chr   = '';
my $bin_count = 0;
my $bin_start = 0;
my $bin_end   = $bin_size;
my $counter = 0;

my ($src, $type);

open GFF, "<$gff_file" or die "\nUnable to open $gff_file: $1\n\n";
while (<GFF>) {
  chomp;chomp;

  my @fields = split /\t/;
  $src  = $fields[1];
  $type = $fields[2];

  if ($cur_chr eq '') { $cur_chr = $fields[0]; }
#print "compare " . $fields[0] . " and " . $fields[3] . " against $cur_chr, $bin_start, $bin_end; count=$bin_count\n";

  if ($fields[3] >=$bin_start && $fields[3] <= $bin_end 
          && $fields[0] eq $cur_chr) {
    $bin_count++;
  }
  else {
    do {
       if ($bin_count > 0) {
         # Print cummulative GFF record
         my $attrs = "value=$bin_count;ID=$counter";
         my @rec = ($cur_chr, $src, $type, $bin_start, $bin_end, '.', '.', '.', 
                    $attrs);
         my $rec_str = join "\t", @rec;
         print "$rec_str\n";
       }

       $bin_start = $bin_end;
       $bin_end   += $bin_size;
       $bin_count = 0;
       
       # check if record is in the new bin
       if ($fields[3] >=$bin_start && $fields[3] <= $bin_end 
               && $fields[0] eq $cur_chr) {
          $bin_count++;
       }
    # repeat until bins catch up with this location
    } while ($fields[3] > $bin_end && $fields[0] eq $cur_chr);
  }#else 
    
  if ($fields[0] ne $cur_chr) {
    # start bins at beginning of new chr
    $bin_start = 0;
    $bin_end   = $bin_size;
    $bin_count = 0;
    $cur_chr   = $fields[0];
  }
  
  $counter++;
#last if $counter>100;
}

close GFF;