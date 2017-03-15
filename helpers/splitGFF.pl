# file: splitGFF.pl
#
# purpose: split set of GFF records into slices
#
# usages:
#    perl splitGFF.pl slice-length feature-gff-file [feature-gff-file]*

use Data::Dumper;

$slice_length = shift @ARGV;

print "reading GFF...\n";
@gff;
@chrs;
foreach $file (@ARGV) {
  open(GFFIN, "<$file") or die("Unable to open file $file: $!");
  while (<GFFIN>) {
    chomp;
    @fields = split /\s+/;
    if (lc($fields[2]) eq 'chromosome') {
      push @chrs, [@fields];
    }
    else {
      push @gff, [@fields];
    }
  }
  close(GFFIN);
}#read all gff records

print "sorting feature GFF records by chromosome and start position...\n";
my @unsorted_gff = @gff;
@gff = sort {
               if ($a->[0] gt $b->[0]) { return 1; }
               elsif ($a->[0] lt $b->[0]) { return -1; }
               else {
                 if ($a->[3] > $b->[3]) { return 1; }
                 elsif ($a->[3] < $b->[3]) { return -1; }
                 else { return 0; }
               }
             } @unsorted_gff;
my @unsorted_chrs = @chrs;
@chrs = sort {
               if ($a->[0] gt $b->[0]) { return 1; }
               elsif ($a->[0] lt $b->[0]) { return -1; }
               else { return 0; }
             } @unsorted_chrs;

$gff_index  = 0;
$slice_file = 1;

foreach $chr (@chrs) {
  ($chr_name, $f2, $f3, $chr_start, $chr_end, $f6, $f7, $f8, $f9) = @$chr;
#print "handle $chr_name\n";
  $slice_start = $chr_start;
  $slice_end   = $chr_start + $slice_length;
  do {
    if ($slice_end > $chr_end) { $slice_end = $chr_end; }
    
    open GFFOUT, ">slice$slice_file.gff";
#print "   write to slice$slice_file.gff\n";
    print GFFOUT "$chr_name\t$f2\t$f3\t$slice_start\t$slice_end\t$f6\t$f7\t$f8\t$f9\n";
    while ($gff[$gff_index]->[0] eq $chr_name
             && $gff[$gff_index]->[3] < $slice_end) {
      $record = $gff[$gff_index];
      print GFFOUT join("\t", @$record) . "\n";
      $gff_index++;
    }
    close GFFOUT;
#exit;
    $slice_start += $slice_length;
    $slice_end   += $slice_length;
    $slice_file++;
  } until ($gff[$gff_index]->[0] ne $chr_name || $slice_start > $chr_end);
#exit;  
}#each chromosome

#exit;

$num_files = $slice_file;
$slice_file = 1;

while ($slice_file < $num_files) {
  $cmd = "perl ../cvit.pl -c cvit_slice.ini -o slice$slice_file slice$slice_file.gff";
  print "$cmd\n";
  system($cmd);
  $slice_file++;
#exit;
}#each file

