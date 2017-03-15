#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Long;

# version: see version notes at end
# Authors: Benjamin Mulaosmanovic, Steven Cannon

############################
## GetOptions 
#############################

my ($queryfile, $genefile);
my $unique = 0;
my $pct_iden_min = 0;
my $e_value_max = 10;
my $report = "query";

GetOptions( 
            "unique"         => \$unique,
            "queryfile=s"    => \$queryfile,
            "genefile=s"     => \$genefile,
            "report:s"       => \$report,
            "pct_iden_min:f" => \$pct_iden_min,
            "e_value_max:f"  => \$e_value_max
          );

############################
## Usage, IO 
#############################

my $usage_string = <<EOS;
 Usage: $0 [-unique] -queryfile BLASTINPUT -genefile GENEINPUT 

 Input is 
   EITHER 
     - a tabular blastp output file (blast format option -m8) 
   OR 
     - a list of queries AND a GFF file containing genes and their coordinates. 
 
 Returns a gff file with coordinates. Output is to STDOUT.
 
 
 Options:
   -unique : if a target sequence is matched by two or more queries, only the match with the 
    lowest E-value will be shown.
    Requires that query input be in blast -m8 output format, since the selection of unique
    records is made using target ID and then by E-value (not present in two-column input).
   
   -report: "query" or "target" ("q" or "t") as the ID reported in the GFF "Name" attribute. Default "query"
   
   -pct_iden_min: minimum acceptable percent identity in the alignment. Values [0-100]. Default 0.
   
   -e_value_max: maximum acceptable E-value. Values [10-0]. Default 10.
   
EOS

############################
## Main 
#############################

my %target_hash;
my @output;
my $columns;

### Put "genes" GFF into a hash
open (my $GENES, "< $genefile") or die "can't open $genefile: $!";
while (<$GENES>) {
  chomp;
  my $line = $_;
  my $gene_name="";
  if ( $line =~ m/[gG]ene.+Name=([^;]+)/ ) {
    $gene_name = $1;
    $target_hash{$gene_name} = $line;      
  }
  if ( $line =~ m/[gG]ene.+ID=([^;]+)/ ){
    $gene_name = $1;
    $target_hash{$gene_name} = $line;
  }
}

### Process query file, and generate array containing GFF output (may not be unique by gene "Name")
open (my $QUERY, "< $queryfile") or die "can't open $queryfile: $!";
while (<$QUERY>) {
  chomp;
  my @query = split /\t/, $_;
  
  $columns = scalar(@query);
  die "query file has $columns columns, but must have 2 or 12 (query/target or blast: m -8 format).\n" 
    if ($columns != 2 and $columns != 12);
  
  my ($Q, $T, $identity);
  my $e_value = ".";
  
  if ($columns == 2) { ($Q, $T, $identity, $e_value) =
	  ($query[0], $query[1], 100, 0) }
  elsif ($columns == 12) { ($Q, $T, $identity, $e_value) = 
          ($query[0], $query[1], $query[2], $query[10]) }
  
  $Q=~s/,/|/g; #Prevents errors from occuring in making cvit coords file (uses commas as delimeter)
  $T=~s/,/|/g;
  $Q =~ s/\r|\n//g; #correctly handles list input from gene families 
  $T =~ s/\r|\n//g;
  if(!defined($target_hash{$T})){ print STDERR "Can't find $T in $genefile\n"; next; }
  my @gff = split /\t/, $target_hash{$T};
  
  if ($identity >= $pct_iden_min and $e_value <= $e_value_max) {
    if ($report =~ /^q/i) { # report the query in key-value field "Name"
      push @output, "$gff[0]\t$gff[1]\t$gff[2]\t$gff[3]\t$gff[4]\t$e_value\t.\t.\tName=$Q;class=$Q;target=$T\n";
    }
    elsif ($report =~ /^t/i) { # report the target name in key-value field "Name"
      push @output, "$gff[0]\t$gff[1]\t$gff[2]\t$gff[3]\t$gff[4]\t$e_value\t.\t.\tName=$T;class=$Q;target=$T\n";
    }
    else { die "unexpected report type (not q or t): [$report]\n" }
  }
}


### Uniq-ify the array wrt gene name and E-value, if requested
if (not($unique)) { # "-unique 0", so print all hits, regardless of uniqueness wrt target IDs
  print @output
}
else { # "-unique 1" -- but this doesn't make sense, since the choice of reported (non-unique) gene would be arbitrary.
  if ($columns == 2) {
    die "Requires that query input be in blast -m8 output format, since the selection of unique\n",
        "records is made using target ID and then by E-value (not present in two-column input).\n";
  }
  
  # sort first by target gene name, then by E-value (lowest first)
  my @sorted = map { $_->[2] }
               sort { $a->[0] cmp $b->[0]
                       ||
                      $a->[1] <=> $b->[1]
                    } map { [ /Name=([^;]+)/, (split(/\t/, $_))[5], $_ ] } @output;
                     #        gene_name            e-value          line
  
  my %seen_line;
  for my $line (@sorted) {
    my $name = $line;
    $name =~ s/.+Name=([^;]+;).+/$1/;
    
    if ($seen_line{$name}) { next }
    else {
      print $line;
      $seen_line{$name}++;
    }
  }
}


__END__

Versions: 
2011
01 4-13 BM - start
02 4-14 SC - refactor; add -unique
03 4-15 SC - disallow -unique for two-column input
04 6-16 SC - clarifications in usage message
05 6-29 SC - add flags to 1) report query or target ID and 2) filter by pct identity and E-value
06 7-08 BM - Adds both ID and Name to hash (some gene names correspond to Name only, some to ID only)
