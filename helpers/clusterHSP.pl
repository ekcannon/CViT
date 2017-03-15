#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Long;

# version: see version notes at end
# Authors: Benjamin Mulaosmanovic, Steven Cannon

############################
## GetOptions 
#############################
my ($inputfile, $type, $source);
my $hspdistance = 10000;
my $pct_iden_min = 0;
my $e_value_max = 10;
GetOptions( 
            "inputfile=s"    => \$inputfile,
            "source=s"       => \$source,
            "type=s"         => \$type,
            "distance:i"     => \$hspdistance,
            "pct_iden_min:f" => \$pct_iden_min,
            "e_value_max:f"  => \$e_value_max
          );

############################
## Usage, IO 
#############################

my $usage_string = <<EOS;
  Usage: $0 -inputfile BlastOutput [-distance HSPdistance] -source Source -type Type
 
  Clusters HSPs that are within user defined distance. Returns a gff file with coordinates. Output is to STDOUT.
  
  Required:
    -inputfile: Blast output in -m 8 format. Must be sorted by chromosome and target start coordinate (column 2 and 9)

    -source:    Species name or database name used in blast (to appear in column 2 of gff)

    -type:      To appear in column 3 of gff
   
  Options:
    -distance:  Distance allowed between HSPs (default: 10000)
    
    -pct_iden_min: minimum acceptable percent identity in the alignment. Values [0-100]. Default 0.
    
    -e_value_max: maximum acceptable E-value. Values [10-0]. Default 10.
EOS

############################
## Main 
############################

my ($start, $end, $identity, $e_value, $Tid, $Qid) = (0, 0, 0, $10, "", "");
open (my $IN, "< $inputfile") or die "can't open $inputfile: $!";
while (my $line = <$IN>) {
    chomp($line);
    my @bits = split(/\t/,$line);
    if ($bits[2] >= $pct_iden_min and $bits[10] <= $e_value_max) {
      if ($start == 0 || $end == 0) {
          ($Qid, $Tid, $identity, $start, $end, $e_value) = ($bits[0], $bits[1], $bits[2], $bits[8], $bits[9], $bits[10]);
      }    
      elsif ($Tid ne $bits[1] || $Qid ne $bits[0]) {
          if($start < $end){ print "$Tid\t$source\t$type\t$start\t$end\t.\t+\t.\tName=$Qid;class=$Qid\n"; }
          else { print "$Tid\t$source\t$type\t$end\t$start\t.\t-\t.\tName=$Qid;class=$Qid\n";}
          ($Qid, $Tid, $identity, $start, $end, $e_value) = ($bits[0], $bits[1], $bits[2], $bits[8], $bits[9], $bits[10]);
      }
      elsif (($bits[9]-$end) > $hspdistance) {
          if ($start < $end){ print "$Tid\t$source\t$type\t$start\t$end\t.\t+\t.\tName=$Qid;class=$Qid\n"; }
          else { print "$Tid\t$source\t$type\t$end\t$start\t.\t-\t.\tName=$Qid;class=$Qid\n";}
          ($Qid, $Tid, $identity, $start, $end, $e_value) = ($bits[0], $bits[1], $bits[2], $bits[8], $bits[9], $bits[10]);
      }
      elsif ($bits[9] > $end && ($bits[9]-$end)<=$hspdistance) {
          $end = $bits[9];
      }
      else { next }
    } # endif: check $pct_iden_min and $e_value_max
}
if ( $start < $end ) { print "$Tid\t$source\t$type\t$start\t$end\t.\t+\t.\tName=$Qid;class=$Qid\n" }
else { print "$Tid\t$source\t$type\t$end\t$start\t.\t-\t.\tName=$Qid;class=$Qid\n" }

__END__

Versions: 
2011
01 4-13 BM - start
02 4-14 SC - minor reformatting; and change default hspdistance to 10000
03 6-30 SC - add filters pct_iden_min and e_value_max

