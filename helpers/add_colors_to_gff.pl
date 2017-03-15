#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Long;


############################
## GetOptions 
#############################
my $key;
GetOptions( 
            "key=s"       => \$key,
          );

my $usage = <<EOS;
  
  program add_colors_to_gff.pl adds a chrom/color key-value pair to the 9th column of a GFF file, 
  for consumption by CViT
  
  Usage: $0 -key KEY  MYFILE.gff 
  
  The parental lines are stripped, as are "Parent=" values in each feature, and IDs (as CViT doesn't need these).
  
  
  Parameter(s):
    -key:    "matches" or "Name"

  The accepted keys are "Name" for chromosome files, e.g. 
    Name=Mt1    
  and "matches" for synteny files, e.g.
    ...;matches=Mt2:24005397..24095553;median_Ks=0.8331

  Input file has data such as ...
    ##gff-version 3
    ##date Wed Jun 22 14:30:34 2011
    ##source gbrowse gbgff gff3 dumper
    Gm01	recent_duplication	synteny	2360256	29846090	.	.	.	ID=1;name=Gm02
    Gm01	recent_duplication	syntenic_region	2360256	4962889	6416.1	-	.	Parent=1;ID=2;=Gm02:1626259..3856658;median_Ks=0.1505
    Gm01	recent_duplication	syntenic_region	5005455	6081494	1501.4	+	.	Parent=1;ID=3;=Gm02:9920653..10476232;median_Ks=0.1283
    
EOS

die $usage if (not defined($key));
die $usage unless ($ARGV[0] and (($key =~ "matches") or ($key =~ "Name")));

 
while (<>) {
  chomp;
  my $line = $_;
  
  $line =~ s/Parent=\d+;//;
  $line =~ s/ID=\d+;//;
  
  if    ($line =~ m/^#/) { print $line . "\n" }
  elsif ($line =~ m/synteny/) { next } # a parental element
  elsif ($line =~ m/$key=Gm01/i) { print $line . ";Color=Indigo\n" }
  elsif ($line =~ m/$key=Gm02/i) { print $line . ";Color=BlueViolet\n" }
  elsif ($line =~ m/$key=Gm03/i) { print $line . ";Color=Purple\n" }
  elsif ($line =~ m/$key=Gm04/i) { print $line . ";Color=MediumVioletRed\n" }
  elsif ($line =~ m/$key=Gm05/i) { print $line . ";Color=DeepPink\n" }
  elsif ($line =~ m/$key=Gm06/i) { print $line . ";Color=Red\n" }
  elsif ($line =~ m/$key=Gm07/i) { print $line . ";Color=OrangeRed\n" }
  elsif ($line =~ m/$key=Gm08/i) { print $line . ";Color=Orange\n" }
  elsif ($line =~ m/$key=Gm09/i) { print $line . ";Color=Gold\n" }
  elsif ($line =~ m/$key=Gm10/i) { print $line . ";Color=SaddleBrown\n" }
  elsif ($line =~ m/$key=Gm11/i) { print $line . ";Color=Maroon\n" }
  elsif ($line =~ m/$key=Gm12/i) { print $line . ";Color=DarkOliveGreen\n" }
  elsif ($line =~ m/$key=Gm13/i) { print $line . ";Color=DarkGreen\n" }
  elsif ($line =~ m/$key=Gm14/i) { print $line . ";Color=Lime\n" }
  elsif ($line =~ m/$key=Gm15/i) { print $line . ";Color=Aqua\n" }
  elsif ($line =~ m/$key=Gm16/i) { print $line . ";Color=DarkCyan\n" }
  elsif ($line =~ m/$key=Gm17/i) { print $line . ";Color=Blue\n" }
  elsif ($line =~ m/$key=Gm18/i) { print $line . ";Color=Navy\n" }
  elsif ($line =~ m/$key=Gm19/i) { print $line . ";Color=Black\n" }
  elsif ($line =~ m/$key=Gm20/i) { print $line . ";Color=DimGray\n" }
  
  elsif ($line =~ m/$key=Mt1/i) { print $line . ";Color=Indigo\n" }
  elsif ($line =~ m/$key=Mt2/i) { print $line . ";Color=MediumVioletRed\n" }
  elsif ($line =~ m/$key=Mt3/i) { print $line . ";Color=Red\n" }
  elsif ($line =~ m/$key=Mt4/i) { print $line . ";Color=DarkOrange\n" }
  elsif ($line =~ m/$key=Mt5/i) { print $line . ";Color=DarkGreen\n" }
  elsif ($line =~ m/$key=Mt6/i) { print $line . ";Color=DarkCyan\n" }
  elsif ($line =~ m/$key=Mt7/i) { print $line . ";Color=Blue\n" }
  elsif ($line =~ m/$key=Mt8/i) { print $line . ";Color=Black\n" }
  
  elsif ($line =~ m/$key=Lj1/i) { print $line . ";Color=Indigo\n" }
  elsif ($line =~ m/$key=Lj2/i) { print $line . ";Color=MediumVioletRed\n" }
  elsif ($line =~ m/$key=Lj3/i) { print $line . ";Color=Red\n" }
  elsif ($line =~ m/$key=Lj4/i) { print $line . ";Color=DarkOrange\n" }
  elsif ($line =~ m/$key=Lj5/i) { print $line . ";Color=DarkGreen\n" }
  elsif ($line =~ m/$key=Lj6/i) { print $line . ";Color=DarkCyan\n" }
    
}

