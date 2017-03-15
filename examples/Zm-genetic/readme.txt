basic genetic example
---------------------

An example of a genetic map based on cM showing chromosomes with varying start
coordinates which are variably space to accomodate features as needed.

Shows centromeres and a few well-known loci on the maize genome using the
IMB2 2008 neigborbors map.

http://www.maizegdb.org/cgi-bin/displaycompletemaprecord.cgi?id=1140202

Execute with:
  PNG output
  $ perl cvit.pl -c examples/Zm-genetic/cvit_gen.ini -o examples/Zm-genetic/genetic examples/Zm-genetic/ZmChrs_gen.gff examples/Zm-genetic/features.gff
  SVG output
  $ perl cvit.pl -i svg -c examples/Zm-genetic/cvit_gen.ini -o examples/Zm-genetic/genetic examples/Zm-genetic/ZmChrs_gen.gff examples/Zm-genetic/features.gff
