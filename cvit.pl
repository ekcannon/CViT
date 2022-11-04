#!/usr/bin/env perl

# File: cvit.pl
# Author: Ethalinda Cannon (ethy@a415software.com) 

# Use: Generates a images in a range of sizes displaying one or more chromosomes
#      and ranges or positions on those chromosomes, indicated with bars or dots
#      and optional labels. Also  produces a GFF file describing all data and
#      image attributes that could be used by another application.

# Data in: config file(s) and one GFF file specifying ranges and positions. Ranges
#          and positions would both be in one file.
#          Supports GFF version 2 & 3.

# Data out: Images in a range of sizes and a GFF file describing the images and
#           all ranges and positions represented in the images.

# The GFF standard
#    http://www.sequenceontology.org/gff3.shtml

# Types of GFF records interpreted: 
#    chromosome - defines a chromosome (or piece of chromosome)
#    marker-hit - a hit on a marker, displayed as a bar
#    marker     - defines a marker, displayed as a dot
#    clone      - names and gives the range of a clone, displayed by horizontal
#                 lines directly on the chromosome
#    hit        - a specialized position, probably a blast fhit, displayed as a dot
#    centromere - locates a centromere, displayed by wider gray bar directly on
#                 chromosome.
#    measure    - attaches a measure of importance to a range. Could be e-value,
#                 hits per location, et cetera. Value of measure is in attributes,
#                 value=
# otherwise:
#    an undefined position is displayed as a dot
#    and undefined range is displayed as a bar to right of chromosome.
#
# Library documentation:
#    http://perldoc.perl.org/File/Spec.html
#    http://search.cpan.org/dist/GD/
#    http://search.cpan.org/~tcaine/GD-Arrow-0.01/lib/GD/Arrow.pm
#    http://search.cpan.org/~mverb/GDTextUtil-0.86
#    http://search.cpan.org/~wadg/Config-IniFiles-2.38/IniFiles.pm

# draw_all_records()
# draw_legend()
# get_cmd_options()
# get_legend_glyphs()
# get_unique_ID()
# print_coords()
# print_image()
# reverse_coords()

my $VERSION = "1.1";

use strict;
use warnings;
use File::Spec;

# standard libs
use IO::File;
use Getopt::Std;
use Getopt::Long;
use FindBin '$Bin';
use Data::Dumper;  # for debugging

# installed lib
use Config::IniFiles;

my $debug = 1;   # set to 0 to turn off debugging
my $config_file = File::Spec->catfile("$Bin/config", 'cvit.ini');  # default config file

my $warning = <<EOF;

  Usage for the CVIT script:
    perl cvit.pl [opt] gff-file-in [gff-file-in]*

    -c <file>           alternative config file (default: config/cvit.ini)
    -h                  display this list of options
    -i [png/svg]        image type (default: png)
    -l                  lean output: don't create legend or csv file
    -s '<section_option>=<value>[,<section_option>=<value>]*'
                        conf file overrides
    
    *Multiple gff input files make possible various layers: chromosomes, centromeres, borders, etc.
    For example (ignore line wraps):
    perl cvit.pl -c config/cvit_histogram.ini -o MtChrXxMtLjTEs 
         data/MtChrs.gff data/BACborders.gff data/MtCentromeres.gff 
         /web/medicago/htdocs/genome/upload/MtChrXxMtLjTEs.gff
         
    Example: override conf file settings:
    perl cvit.pl -s 'general_title=Homeologous Chromosomes,general_scale_factor=.00003' records.gff
    
    The GFF data MUST contain some sequence records of type 'chromosome' or 
    there will be no way to draw the picture.
    
EOF

### Get command line information

my $title         = '';
my $out_filename  = undef;
my $reverse_ruler = 0;
my $override_str;
my $image_format  = 'png';
my $lean     = 0;
my %cmd_opts = ();
getopts("c:o:s:i:hl", \%cmd_opts);
if (defined($cmd_opts{'c'})) { $config_file  = $cmd_opts{'c'}; }
if (defined($cmd_opts{'o'})) { $out_filename = $cmd_opts{'o'}; }
if (defined($cmd_opts{'s'})) { $override_str = $cmd_opts{'s'}; }
if (defined($cmd_opts{'i'})) { $image_format = $cmd_opts{'i'}; }
if (defined($cmd_opts{'h'})) { die $warning; }
if (defined($cmd_opts{'l'})) { $lean = 1; }

# Get conf override options from -s (if any):
my %override_opts = get_cmd_options($override_str);
#######


### verify that we have enough information to run the script:
if (!($ARGV[0]) && scalar(keys(%cmd_opts)) == 0) { die $warning }
if ($image_format ne 'png' && $image_format ne 'svg') {
  die "\nError: Unknown image type: $image_format\n$warning";
}

print "\n";
#######


### Load local packages
use lib "$FindBin::Bin/pkgs/";
use ConfigManager;
use GFFManager;
use GlyphCalc;
use ColorManager;
use CvitImage;
use FontManager;
use GlyphDrawer;
use errorlog;
use CvitLib;
#######


### Get config information:
if (!(-e $config_file)) {
  die "\nERROR: config file ($config_file) not found\n\n";
}
my $ini = new ConfigManager($config_file);
die "\nERROR: Couldn't parse $config_file!\n\n" if (!$ini);

# check for command line overrides
foreach my $opt (keys %override_opts) {
  # option name is <section>_<option name>
  my ($section, $option) = split /_/, $opt, 2;
print "override: $section = $option\n";
  $ini->setval($section, $option, $override_opts{$opt});
}
#######


### Set debugging/logging information:
my $logfile   = $ini->val('general', 'logfile');
my $errorfile = $ini->val('general', 'errorfile');

my $dbg = ErrorLog->new();
$dbg->createLog($debug, $logfile, $errorfile, "f"); # s=stdout, b=browser, f=log file
$dbg->logMessage("\n\n\n-----------------START----------------");
#######

# log command line
my $cmd = sprintf qx/ps -o args $$/;
$dbg->logMessage($cmd);


### Create unique base name if none given
if (!$out_filename || length($out_filename) == 0) {
  $out_filename = get_unique_ID(10);
}
#######


#### get user-defined sequence types; indicated by 'feature' attribute
my %custom_types = $ini->get_custom_options();
#######


### Read and parse gff input file(s) into tables
my $gff_mgr = new GFFManager($ini, $dbg);
my %GFF;
$GFF{'chromosome'} = []; # array of chromosomes (reference, or backbone sequence) in GFF
$GFF{'range'}      = []; # array of all ranges found in GFF data
$GFF{'position'}   = []; # array of all positions found in GFF data
$GFF{'border'}     = []; # array of all borders (e.g. of BACs) found in GFF data
$GFF{'marker'}     = []; # array of all markers found in GFF data
$GFF{'centromere'} = []; # array of all centromeres found in GFF data
$GFF{'measure'}    = []; # array of all measure-value records in GFF data

print "Reading GFF file(s)...\n";
foreach my $gfffile (@ARGV) {
  $dbg->logMessage("\nRead gff file $gfffile");
  if (!(-e $gfffile)) {
    my $msg = "\nWARNING:unable to find GFF file $gfffile";
    print "$msg\n";
    $dbg->reportError($msg);
  }
  else {
    $gff_mgr->read_gff(\%GFF, $gfffile);
  }
}

if ((scalar $GFF{'chromosome'}) == 0) {
  my $msg = "No chromosomes were found. CViT can't continue";
  print "$msg\n";
  $dbg->reportError($msg);
  exit;
}

# Need this to calculate where things go.
print "image format is $image_format\n";
my $calc = new GlyphCalc($image_format, $ini, $dbg);

# Need the ruler before sorting in case direction is reversed
my ($ruler_min, $ruler_max) = $calc->getRulerMinMax($GFF{'chromosome'});

$gff_mgr->sortGFF(\%GFF, $ruler_max);
#######


### Calculate min/max for each class of measures
my %measure_minmax;
if ($GFF{'measure'} && scalar @{$GFF{'measure'}} > 0) {
  %measure_minmax = $calc->calc_minmax_measures($GFF{'measure'});
  
  # check for invalid min/max values
  my ($isequal, $class_text, $classgff_text, $minmax_value);
  foreach my $class (keys %measure_minmax) {
    next if ($class eq 'min' || $class eq 'max');
    if ($measure_minmax{$class}{'min'} == $measure_minmax{$class}{'max'}) {
      $isequal = 1;
      $class_text = " of class $class";
      $classgff_text = " for records of class $class";
      $minmax_value = $measure_minmax{$class}{'min'};
      last;
    }
  }
  if (!$class_text && $measure_minmax{'min'} == $measure_minmax{'max'}) {
    $isequal = 1;
    $minmax_value = $measure_minmax{'min'};
  }
  if ($isequal) {
    print "\nError while calculating minimum and maximum values for measure\n";
    print "glyphs$class_text: min = max (both are $minmax_value).\n\n";
    print "Check $config_file to make sure min and max in the\n";
    print "[measure] section are set correctly, or check your setting for\n";
    print "value_type and make sure your GFF file has the correct values\n";
    print "set in the column indicated by value_type$classgff_text.\n\n";
    print "Note that you must have at least 2 records in a class of measure glyphs.\n\n";
    print "Unable to recover from this error.\n\n\n";
    exit;
  }
}
#######


### Calculate chromosome locations
# Chromosomes may have fixed or variable spacing
print "Calculating chromosome locations...\n";
my $chromosome_locs_ref = $calc->setChromosomes(\%GFF, \%measure_minmax);
#print Dumper($chromosome_locs_ref);
#######


### Create and write out a CViT image and a legend
#eksc
#print "\nCVIT IMAGE\n";
#^^^^^^
my $clr_mgr = new ColorManager($image_format, File::Spec->catfile($Bin, 'rgb.txt'));
my $font_mgr = new FontManager($image_format);
draw_all_records($calc, $out_filename, \%GFF, $chromosome_locs_ref, [], \%measure_minmax, 1);

if (!$lean) {
  # Draw a separate legend image
  print "\nLEGEND\n";
  draw_legend();
}
#######


###############################################################################
################################### subs ######################################

###################
# draw_all_records()

sub draw_all_records {
  my ($calc, $out_filename, $GFF_ref, $chromosome_locs_ref, $special_ref, 
      $measure_minmax_ref, $write_coords) = @_;

  my $cvit_image = new CvitImage($image_format, $clr_mgr, $font_mgr, $ini, $dbg);
  if ($reverse_ruler == 1) {
    $cvit_image->reverse_ruler();
  }
  $cvit_image->create_image($calc->get_ruler_min(), $calc->get_ruler_max, $chromosome_locs_ref);

  my $glyph_drawer = new GlyphDrawer($image_format, $calc, $cvit_image, $clr_mgr, $font_mgr, $ini, $dbg);
  
  foreach my $glyph (keys %$GFF_ref) {
    if ($glyph eq 'measure') {
      $glyph_drawer->draw_glyph($GFF_ref->{$glyph}, $glyph, $measure_minmax_ref);
    }
    elsif ($glyph ne 'chromosome') {  # chromosomes already placed
      $glyph_drawer->draw_glyph($GFF_ref->{$glyph}, $glyph);
    }
  }

  # print png image
  my $out_image_file = "$out_filename.$image_format";
  print_image($cvit_image->get_image(), $out_image_file);
  
  # print coords file
  if ($write_coords == 1) {
    # print feature locations file
    #      format: name => chromosome,start,end,x1,y1,x2,y2
    my $glyph_coords_ref = $glyph_drawer->{feature_coords};
    my $chrom_coords_ref = $cvit_image->{feature_coords};
    my @feature_coords   = (@$glyph_coords_ref, @$chrom_coords_ref);
    
    if (!$lean) {
      my $out_coords_file = "$out_filename.coords.csv";
      print_coords(\@feature_coords, $out_coords_file);
    }
  }#write out coords
}#draw_all_records


###############
# draw_legend()

sub draw_legend {
  # Get pixels per unit and units per pixel
  my $scale_factor  = $ini->val('general', 'scale_factor'); # pixels
  my $units_per_pixel = 1 / $scale_factor;                  # units
  
#TODO: make this an option?
  # Each glyph will take this much vertical space in pixels:
  my $glyph_height = 25;
   
  # Each glyph will take this much vertical space in units:
  my $glyph_height_units = $units_per_pixel * $glyph_height;

  # Create gff records for each type of glyph
  my %legend_GFF;
  my $new_start = $glyph_height_units; # units
  
  foreach my $glyph (keys %GFF) {
    $legend_GFF{$glyph} = [];
    
    # calculate location(s) for this glyph, return start location for next glyph
    $new_start = get_legend_glyphs($glyph, $new_start, $glyph_height_units, 
                                   $GFF{$glyph}, $legend_GFF{$glyph});
  }
  my $end = $new_start;

  # Create a chromosome record for the legend records
  my $chrstart    = 0;
  my $chrend      = $end;
  my $chromosome  = 'chr';
  my @chromosomes = [$chromosome, '.', '.', $chrstart, $chrend, 
                         '.', '.', '.', "ID=$chromosome"];
  $legend_GFF{'chromosome'} = \@chromosomes;

#TODO: should this be a section in the .ini file?
  # Some drawing attributes will need to be altered
  $ini->setval('general',    'display_ruler',       'L');
  $ini->setval('general',    'image_padding',       35);
  $ini->setval('general',    'title',               'Legend');
  $ini->setval('general',    'title_height',        15);
  $ini->setval('general',    'ruler_min',           0);
  $ini->setval('general',    'ruler_max',           0);
  $ini->setval('general',    'fixed_chrom_spacing', 0);
  $ini->setval('position',   'draw_label',          1);
  $ini->setval('range',      'draw_label',          1);
  $ini->setval('border',     'draw_label',          1);
  $ini->setval('marker',     'draw_label',          1);
  $ini->setval('centromere', 'draw_label',          1);
  $ini->setval('measure',    'draw_label',          1);
  $ini->setval('position',   'transparent',         0);
  $ini->setval('range',      'transparent',         0);
  $ini->setval('border',     'transparent',         0);
  $ini->setval('marker',     'transparent',         0);
  $ini->setval('centromere', 'transparent',         0);
  $ini->setval('measure',    'transparent',         0);
  
  # Need a new glyph calculator for the legend.
  my $calc = new GlyphCalc($image_format, $ini, $dbg);
  
  # Accomodate glyphs and labels to the right of the chromosome
  my ($max_left_label, $max_right_label) = $calc->getLabelWidths(\%legend_GFF);
  my $right_padding = $max_right_label; 
  $ini->setval('general',  'chrom_padding_right', $right_padding);
#TODO: any way to calculate this this rather than arbitrarily padding by 50?
  my $left_padding = $max_left_label + 50;
  $ini->setval('general',  'chrom_padding_left', $left_padding);

  # Recalculate after setting chromosome padding per labels.
  $calc = new GlyphCalc($image_format, $ini, $dbg);
  
  # Place this one chromosome
  $chromosome_locs_ref = $calc->setChromosomes(\%legend_GFF, {});

  draw_all_records($calc, "$out_filename.legend", \%legend_GFF, $chromosome_locs_ref, 
                   \%measure_minmax, {}, 0);
}#draw_legend


####################
# get_cmd_options()

sub get_cmd_options {
  my $option_str = $_[0];
  if (!$option_str) {return ();}

  my %options;

  my @ops = split ',', $option_str;
  foreach my $op (@ops) {
    if (!($op =~ /.*=.*/)) {
      my $msg = "\nError in -s parameter. Format is:\n";
      $msg .= "  -s 'section_option=value[,section_option=value]*\n\n";
      die $msg;
    }
    my ($key, $value) = split /=/, $op, 2;
    $options{$key} = $value;
  }

  return %options;
}#get_cmd_options()


#####################
# get_legend_glyphs()

sub get_legend_glyphs {
  my ($glyph, $start, $glyph_height_units, $records_ref, 
      $legend_records_ref) = @_;

  my @records = @$records_ref;
  my @legend_records = @$legend_records_ref;
  
   if (scalar @records == 0) {
      return $start;
   }
   
   # Height of this glyph
   my $height;
   if ($glyph eq 'position') {
     $height = 0;
   }
   elsif ($glyph eq 'measure' && $ini->val('measure', 'display') eq 'heat') {
     $height = $glyph_height_units;
   }
   else {
     $height = $glyph_height_units/2;
   }
   
#TODO: this could be an ini file option
   # A generic chromosome name
   my $chromosome = 'Chr';
   
   # This will keep track of which variants of this glyph have been handled
   my %types;
   
   foreach my $record (@records) {
      my ($d1, $source, $type, $d2, $d3, $d4, $d5, $d6, $attrs) = @$record;
      my %attributes = $gff_mgr->get_attributes($attrs);
      my $class_name = ($attributes{'class'}) ? $attributes{'class'} : undef;
      my $color_index = 0;
      my $color_name;

      if (!$types{$glyph} && $glyph eq 'measure' 
            && $ini->val('measure', 'display') ne 'distance') {
        $types{$glyph} = 1;
#TODO: multiple measures now allowed
        $types{"$source:$type"} = 1; # only one type of measure allowed
        
        my $value_type = trim($ini->val('measure', 'value_type'));
        if (trim($ini->val('measure', 'display')) eq 'heat') {
          # Get max if value_type is 'score_col'
          my $max_score;
          if ($value_type eq 'score_col') {
            # assumed to be an e-value
            my $max = get_max_score($GFF{'measure'});
            $max_score = sprintf("%.2e", $max);
          }
          else {
            $max_score = 0; # will be calculated elsewhere
          }

          push @$legend_records_ref, 
               [$chromosome, 'legend', 'heatmap_legend', $start, $start+$height, 
                $max_score, '.', '.', "ID=$source $type;value=1"];
        }#heatmap measure
        else {
          push @$legend_records_ref, 
               [$chromosome, 'legend', 'measure', $start, $start+$height, 
                '1', '.', '.', "ID=$source $type;value=1"];
        }#not heatmap measure
        $start += $glyph_height_units+20;
      }#measure
      
      # Add a value=1 attribute to everything since classes and types
      #     may be designated as measures too.
      if ($class_name && $class_name ne '') {
         if (!$types{$class_name}) {
            $types{$class_name} = 1;
            $color_index++;
            push @$legend_records_ref, 
                 [$chromosome, $source, $type, $start, $start+$height, 
                  '.', '.', '.', "name=$class_name;class=$class_name;value=1"];
            $start += $glyph_height_units;
         }#haven't seen this class yet
      }#record has a class
        
      elsif (!$types{"$source:$type"} && $custom_types{"$source:$type"}) {
         $color_name = $ini->val($custom_types{"$source:$type"}, 
                                   'color', 
                                   $ini->val($glyph, 'color'));
         $types{"$source:$type"} = 1;
         push @$legend_records_ref, 
              [$chromosome, $source, $type, $start, $start+$height, 
               '.', '.', '.', "name=$source $type;value=1"];
         $start += $glyph_height_units;
      }#haven't seen this source&type yet
      
      elsif (lc($type) eq 'centromere' && !$types{'centromere'}) {
         $color_name = $ini->val('centromere', 'color');
         $types{'centromere'} = 1;
         push @$legend_records_ref, 
              [$chromosome, $source, $type, $start, $start+$height, 
               '.', '.', '.', "ID=centromere"];
         $start += $glyph_height_units;
      }#centromere
      
      elsif (scalar @$legend_records_ref == 0 && !$types{$glyph}) {
        # only one type for this glyph
        $types{$glyph} = 1;
        # create one fake record
        push @$legend_records_ref,
             [$chromosome, '.', '.', $start, $start+$height, 
              '.', '.', '.', "name=$glyph;value=1"];
        $start += $glyph_height_units;
      }#everything else
   }#each record

   return $start;
}#get_legend_glyphs


#################
# get_max_score()

sub get_max_score {
  my $records_ref = $_[0];
  my @records = @$records_ref;
  my $max = 0;
  foreach my $record (@records) {
    my ($d1, $d2, $d3, $d4, $d5, $score, $d6, $d7, $d8) = @$record;
    if ($score > $max) {
      $max = $score;
    }
  }
  
  return $max;
}#get_max_score


#################
# get_unique_ID()
# Generate a unique string of the requested length.

sub get_unique_ID {
  my $length = $_[0];
  my $unique_id = "";
  
  for(my $i=0 ; $i<$length ;) {
    my $ch = chr(int(rand(127)));
    if( $ch =~ /[a-zA-Z0-9]/) {
      $unique_id .=$ch;
      $i++;
    }
  }
  return $unique_id;
}#get_unique_ID


################
# print_coords()
# Print out the feature coordinates.

sub print_coords {
   my ($feature_coords_ref, $out_coords_file) = @_;
   my @feature_coords = @$feature_coords_ref;
   open OUT, ">$out_coords_file"
      or die "\ncan't open out $out_coords_file: $!";
   print OUT "#name,chromosome,start,end,x1,y1,x2,y2\n";

   foreach my $line (@feature_coords) {
      print OUT "$line\n";
   }
   close OUT;
}#print_coords()


###############
# print_image()
# Print image to file
sub print_image {
  my ($im, $in_path_and_file) = @_;

  open (IMAGE, "> $in_path_and_file") 
    or die "\ncan't open out $in_path_and_file: $!";
  binmode (IMAGE);
    
  if ($image_format eq 'svg') {
    print IMAGE $im->svg();
  }
  else {
    print IMAGE $im->png;
  }
  
  close IMAGE;
}#print_image


##################
# reverse_coords()

sub reverse_coords {
  my ($ruler_max, $records_ref) = $_[0];
  my @records = @$records_ref;
  my @mod_records;
  foreach my $record (@records) {
    my ($chromosome, $source, $type, $start, $end, $score, $strand, $frame, 
        $attrs) = @$record;
    $start = $calc->get_ruler_max() - $start;
    $end = $calc->get_ruler_max() - $end;
    my @new_record = ($chromosome, $source, $type, $start, $end, $score, 
                      $strand, $frame, $attrs);
    push @mod_records, [@new_record];
  }#foreach record
  
  return @mod_records;
}#reverse_coords


##################
# _show_call_stack

sub _show_call_stack {
	my($path, $line, $subr);
	my $max_depth = 30;
	my $i = 1;
	print "--- Begin stack trace ---\n";
	while ( (my @call_details = (caller($i++))) && ($i<$max_depth) )
	{
		print "$call_details[1] line $call_details[2] in function $call_details[3]\n";
	}
	print "--- End stack trace ---\n";
}#_show_call_stack

