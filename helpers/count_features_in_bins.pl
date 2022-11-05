#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;

my $usage = <<EOS;
  Synopsis: zcat SNP_FILE(s) | count_features_in_bins.pl -bin BINSIZE [options]
  
  Count number of features falling within bins of given size.
  Report output in GFF format.

  Data should come in on STDIN, in tab-delimited format, and must contain at least two
  columns: one with chromosome (or other seqid) and one with coordinates on the seqid.
  The data should be sorted first on the sequid and second on the coordinates.

  Column numbers can be specified. The default is seqids in col 1, coords in col 2.
  For default MUMmer show-snps, for example, set -sequid 9 -coord 1.

  Required:
  -bin_size   Bin size, e.g. 10000.
  [coordinate data on STDIN]
 
  Options:
  -seqid_col  Number of column containing the sequid (e.g. chromosome); 1 indexed. Default 1.
  -coord_col  Number of column containing feature coordinates; 1-indexed. Default 2.
  -outfile    Output filename
  -source     Name to use in gff source column (col 2). Default show-snps, corresponding with MUMmer
  -type       Name to use in gff type column (col 3). Default "SNP"
  -help       This message (boolean) 
EOS

my ($bin_size, $help, $outfile);
my ($seqid_col, $coord_col) = (1,2);
my ($source, $type) = ("show-snps", "SNP");

GetOptions (
  "bin_size=i" =>  \$bin_size,   # required
  "seqid_col:i" => \$seqid_col,
  "coord_col:i" => \$coord_col,
  "outfile:s" =>   \$outfile,
  "source:s" =>    \$source,
  "type:s" =>      \$type,
  "help" =>        \$help,
);

die $usage if ($help || not defined($bin_size));

$coord_col--;
$seqid_col--;
if ($coord_col<0 || $seqid_col<0){ 
  die "Parameters coord_col and seqid_col must be 1 or greater. Column indices are one-indexed.\n";
}

my $cur_chr   = '';
my ($bin_count, $bin_start, $counter) = (0, 0, 0);
my $bin_end   = $bin_size;

# Read coordinate data on STDIN
while (<>) {
  chomp;
  next if /^\s*$/;

  my @fields = split /\t/;

  if ($fields[$coord_col] !~ /^\d+/) { # likely header
    next;
  }

  if ($cur_chr eq '') { $cur_chr = $fields[$seqid_col]; }

  if ($fields[$coord_col] >=$bin_start && $fields[$coord_col] <= $bin_end 
          && $fields[$seqid_col] eq $cur_chr) {
    $bin_count++;
  }
  else {
    do {
       if ($bin_count > 0) {
         # Print cummulative GFF record
         my $attrs = "value=$bin_count;ID=$counter";
         my @rec = ($cur_chr, $source, $type, $bin_start, $bin_end, '.', '.', '.', 
                    $attrs);
         my $rec_str = join "\t", @rec;
         print "$rec_str\n";
       }

       $bin_start = $bin_end;
       $bin_end   += $bin_size;
       $bin_count = 0;
       
       # check if record is in the new bin
       if ($fields[$coord_col] >=$bin_start && $fields[$coord_col] <= $bin_end 
               && $fields[$seqid_col] eq $cur_chr) {
          $bin_count++;
       }
    # repeat until bins catch up with this location
    } while ($fields[$coord_col] > $bin_end && $fields[$seqid_col] eq $cur_chr);
  }#else 
    
  if ($fields[$seqid_col] ne $cur_chr) {
    # start bins at beginning of new chr
    $bin_start = 0;
    $bin_end   = $bin_size;
    $bin_count = 0;
    $cur_chr   = $fields[$seqid_col];
  }
  
  $counter++;
}

__END__

# Derived from binCounter.pl by Ethy Cannon (from the CViT package).
# This variant is a little more general, but is tailored to output of MUMmer show-snps.
# S. Cannon
# 2022-10-31 New script, deriving from binCounter.pl
# 2022-11-05 Set default column indices to -seqid 1 -coord 2 ; and add -source, -type
