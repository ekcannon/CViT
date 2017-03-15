#!/usr/bin/perl

# File: GlyphCalc.pm
# Authors: Ethalinda Cannon (ethy@a415software.com), Steven Cannon (scannon@iastate.edu)

# Use: Calculate positions for features on a CViT image.

# calc_border_location()
# calc_centromere_location()
# calc_heatmap_legend()
# calc_histogram_bar()
# calc_marker_location()
# calc_distance_measure()
# calc_position_location()
# calc_range_location()
# get_label_coords()
# calc_minmax_measures()
# getRealMinMax()
# getLabelWidths()
# setChromosomes()
# setFixedChromosomes()
# setVariableChromosomes()

package GlyphCalc;
use strict;
use warnings;
use List::Util qw(max min);
use CvitLib;

use Data::Dumper;      # for debugging


#######
# new()

sub new {
  my ($self, $image_format, $ini, $dbg) = @_;
  
  $self  = {};
  
  # Load image library
  use lib "/Users/ethycannon/installs/GD-2.56";
  if ($image_format eq 'png') {
    use GD;
  }
  else {
    use GD::SVG;
  }
  $self->{'image_format'} = $image_format;

  # The ini file
  $self->{ini} = $ini;
  
  # For calculating label locations
  $self->{font_mgr} = new FontManager($image_format);
  
  # For handling GFF records
  $self->{gff_mgr} = new GFFManager($ini, $dbg);
  
  # For debugging
  $self->{dbg} = $dbg;
  
  # Number of pixels per unit
  $self->{scale_factor}  = $ini->val('general', 'scale_factor');

  # For chromosome placement
  $self->{title_height}        = $ini->val('general', 'title_height');
  $self->{image_padding}       = $ini->val('general', 'image_padding');
  $self->{num_chroms}          = undef;
  $self->{chrom_spacing}       = $ini->val('general', 'chrom_spacing');
  $self->{chrom_width}         = $ini->val('general', 'chrom_width');
  $self->{chrom_padding_left}  = $ini->val('general', 'chrom_padding_left');
  $self->{chrom_padding_right} = $ini->val('general', 'chrom_padding_right');
  $self->{show_strands}        = $ini->val('general', 'show_strands');
  
  # All about the chromosomes
  $self->{chromosome_locs} = {
        'chrbase'    => $self->{image_padding} + $self->{title_height},
        'order'      => [],
        'attributes' => {},
        'locations'  => {}};

  # To avoid re-calculating:
  $self->{reverse_ruler} = $ini->val('general', 'reverse_ruler');
  $self->{ruler_min} = 0;
  $self->{ruler_max} = 0;
  
  # For piling up positions and ranges
  $self->{position_bins}       = {};
  $self->{rt_range_pileup_end} = {};
  $self->{lf_range_pileup_end} = {};
  $self->{bumpout}             = 0;

  # For measure glyphs
  $self->{measure_params} = {};

  # For keeping track of pixel locations of features
  $self->{feature_coords} = [];
  
  bless($self);
  return $self;
}#new


#########################
# calc_border_location() -- called as eval($calc_func)

sub calc_border_location {
  my ($self, $chromosome, $start, $end, $strand) = @_;
  
  my $reverse_ruler = $self->{reverse_ruler};
  my $chromosome_locs_ref = $self->{chromosome_locs};
  my $scale_factor  = $self->{scale_factor};
  my $chrom_width   = $self->{chrom_width};
  
  my ($x1, $y1, $x2, $y2);

  # feature start is relative to chr start
  my $range_size = $end - $start;
  if ($reverse_ruler == 1) {
    my $chrymax = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'ymax'};
    $y1 = int($chrymax - $scale_factor*($start + $range_size));
    $y2 = int($y1 + $range_size * $scale_factor);
  }
  else {
    my $chryloc = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'ymin'};
    $y1 = int($chryloc + $scale_factor * $start);
    $y2 = int($y1 + $range_size * $scale_factor);
  }

  my $chrxloc = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'xmin'};
  $x1 = $chrxloc;
  $x2 = $x1 + $chrom_width;
  
  return ($x1, $y1, $x2, $y2, 0);   # borders don't "pileup"
}#calc_border_location


############################
# calc_centromere_location() -- called as eval($calc_func)

sub calc_centromere_location {
  my ($self, $chromosome, $start, $end, $strand) = @_;

  my $reverse_ruler = $self->{reverse_ruler};
  my $chromosome_locs_ref = $self->{chromosome_locs};
  my $scale_factor  = $self->{scale_factor};
  my $chrom_width   = $self->{chrom_width};
  
  my $ini = $self->{ini};
  my $centromere_overhang = $ini->val('centromere', 'centromere_overhang');
  
  my ($x1, $y1, $x2, $y2);
  
  my $chrxloc = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'xmin'};
  $x1 = int($chrxloc - $centromere_overhang);
  $x2 = int($x1 + $chrom_width + 2 * $centromere_overhang);
  
  if ($reverse_ruler == 1) {
    my $chrymax = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'ymax'};
    $y1 = int($chrymax - $scale_factor * $end);
    $y2 = int($chrymax - $scale_factor * $start);
  }
  else {
    my $chryloc = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'ymin'};
    $y1 = int($chryloc + $scale_factor * $start);
    $y2 = int($chryloc + $scale_factor * $end);
  }

  return ($x1, $y1, $x2, $y2, 0);  # centromeres don't "pileup"
}#calc_centromere_location


########################
# calc_distance_measure()

sub calc_distance_measure {
  my ($self, $chromosome, $start, $end, $strand, $value, $min, $max, $opts) = @_;
  my ($x1, $y1, $x2, $y2, $pileup);
  
  # value indicated by distance from center of chromosome;
  #   offset is meaningless
#  $self->{ini}->setval('PresentGlyph', 'offset', 0);
  
  # no concept of pileup here:
  $pileup = 0;
#  $self->{ini}->setval('PresentGlyph', 'enable_pileup', 0);
  
  # first, get base position
  if ($opts->{'draw_as'} eq 'position') {
    ($x1, $y1, $x2, $y2, $pileup) 
         = $self->calc_position_location($chromosome, $start, $end, $strand);
  }
  else {
    ($x1, $y1, $x2, $y2, $pileup) 
         = $self->calc_range_location($chromosome, $start, $end, $strand);
  }
      
  # then calculate distance based on value and min/max, 
  #    scaled to fit within max_distance
  my $max_dist = $opts->{'max_distance'};
  my $range    = $max - $min;
  my $zero_loc = (0 < $min) 
                    ? 0 
                    : int($max_dist * (0-$min)/$range);
  my $interval = $value - $min;
  my $dist     = int($max_dist * ($interval/$range));

  if ($dist > $zero_loc) {
    $x1 += $dist-$zero_loc;
    $x2 += $dist-$zero_loc;
  }
  elsif ($dist < $zero_loc) {
    $x1 -= $zero_loc-$dist;
    $x2 -= $zero_loc-$dist;
  }
  
  
  # return the coordinates of the glyph
  return ($x1, $y1, $x2, $y2, $pileup);
}#calc_distance_measure


#######################
# calc_heatmap_legend()

sub calc_heatmap_legend {
  my ($self, $chromosome, $start, $end, $min_label, $max_label, $label) = @_;

  my $chromosome_locs_ref = $self->{chromosome_locs};
  my $scale_factor  = $self->{scale_factor};
  my $chrom_width   = $self->{chrom_width};
  
  my $inc   = 10;
  my $width = int(($end - $start)*$scale_factor / $inc);

  # calculate starting location:
  my $chryloc = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'ymin'};
  my $y1 = int($chryloc + $scale_factor * $start);
  my $y2 = $y1+$width;
  
  my $chrxloc = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'xmin'};
  my $x1 = int($chrxloc + $chrom_width);
  my $x2 = $x1 + $inc*$width;

  return ($x1, $y1, $x2, $y2);
}#calc_heatmap_legend


#######################
# calc_histogram_bar()

sub calc_histogram_bar {
  my ($self, $chromosome, $start, $end, $value, $strand, $min, $max) = @_;

  my $reverse_ruler = $self->{reverse_ruler};
  my $chromosome_locs_ref = $self->{chromosome_locs};
  my $scale_factor  = $self->{scale_factor};
  my $chrom_width   = $self->{chrom_width};
  my $chrom_spacing = $self->{chrom_spacing};

  my $ini = $self->{ini};
  my $offset = $ini->val('PresentGlyph', 'offset');
  
  # Note that histograms assume the min is 0, so adjust the values accordingly
  $value = $value - $min;
  my $max_histogram = ($chrom_spacing - 2*$chrom_width);
  my $histogram_unit = $ini->val('PresentGlyph', 'hist_perc')
                          * ($max_histogram / ($max - $min)); 

  my ($x1, $y1, $x2, $y2);

  my $hist_width = int($value * $histogram_unit);

  my $chrxloc = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'xmin'};
  if ($offset > 0) {
    $x1 = int($chrxloc + $chrom_width + $offset);
    $x2 = $x1 + $hist_width;
  }
  else {
    $x1 = int($chrxloc - $hist_width + $offset);
    $x2 = $x1 + $hist_width;
  }

  if ($reverse_ruler == 1) {
    my $chrymax = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'ymax'};
    $y1 = int($chrymax - $scale_factor * $end);
    $y2 = int($chrymax - $scale_factor * $start);
  }
  else {
    my $chryloc = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'ymin'};
    $y1 = int($chryloc + $scale_factor * $start);
    $y2 = int($chryloc + $scale_factor * $end);
  }
  
  return ($x1, $y1, $x2, $y2, 0);  # histograms don't "pileup"
}#calc_histogram_bar


#########################
# calc_marker_location() -- called as eval($calc_func)

sub calc_marker_location {
  my ($self, $chromosome, $start, $end, $strand) = @_;
  
  my $reverse_ruler = $self->{reverse_ruler};
  my $chromosome_locs_ref = $self->{chromosome_locs};
  my $scale_factor  = $self->{scale_factor};
  my $chrom_width   = $self->{chrom_width};
  
  my $ini = $self->{ini};
  my $width  = int($ini->val('PresentGlyph', 'width'));
  my $offset = int($ini->val('PresentGlyph', 'offset'));
  
  my ($x1, $y1, $x2, $y2);
  
  # calculate y location on image for marker
  if ($reverse_ruler == 1) {
    my $chrymax = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'ymax'};
    $y1 = int($chrymax - $scale_factor * $start);
    $y2 = $y1;
  }
  else {
    my $chryloc = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'ymin'};
    $y1 = int($chryloc + $scale_factor * $start);
    $y2 = $y1;
  }

  # calculate x locations on image for marker
  my $chrxloc = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'xmin'};
  if ($self->{show_strands} == 1) {
    if ($strand eq '-') {
      # left side
      $x1 = $chrxloc - $width - $offset;
      $x2 = $x1 + $width;
    }
    elsif ($strand eq '+') {
      # right side
      $x1 = $chrxloc + $chrom_width + $offset;
      $x2 = $x1 + $width;
    }
    else {
      # inside chrom
      $x1 = $chrxloc;
      $x2 = $x1 + $chrom_width;
    }
  }
  else {
    if ($offset > 0) {
      # right side
      $x1 = $chrxloc + $chrom_width + $offset;
      $x2 = $x1 + $width;
    }
    else {
      # left side
      $x1 = $chrxloc + $offset - $width;
      $x2 = $x1 + $width;
    }
  }
  
  return ($x1, $y1, $x2, $y2, 0);  # markers don't "pileup"
}#calc_marker_location


###########################
# calc_minmax_measures()

sub calc_minmax_measures {
  my ($self, $measure_ref) = @_;
  my @measures = @$measure_ref;

  my $ini = $self->{ini}; # shorthand
  
  my %measure_minmax;
  $measure_minmax{'min'} = $ini->val('measure', 'min');
  $measure_minmax{'max'} = $ini->val('measure', 'min');
  
  # Note that this prevents different value types for different classes
  my $value_type = $ini->val('measure', 'value_type');
  foreach my $m (@measures) {
    my %attrs = $self->{gff_mgr}->get_attributes($m->[8]);

    # 'class' attribute in GFF enables display of more than on measure type
    my $class;
    if (defined $attrs{'class'} && $attrs{'class'} ne '') {
      $class = $attrs{'class'}
    }
    else {
      $class = undef;
    }

    my $value = 0;
    if ($value_type eq 'value_attr' && defined $attrs{'value'}) {
      # use value= attribute
      $value = $attrs{'value'};
    }
    elsif ($value_type eq 'score_col' && $m->[5]) {
      # use score column
      $value = $m->[5];
    }
    else {
      # Can't do anything with this record
      next;
    }

    if (defined $class) {
      if (!$measure_minmax{$class}) {
        $measure_minmax{$class} = {'min' => $value, 
                                   'max' => $value,
                                   'display' => $m->[1] . ':' . $m->[2],
                                  };
      }
      else {
        if ($measure_minmax{$class}->{'min'} > $value) {
          $measure_minmax{$class}->{'min'} = $value;
        }
        if ($measure_minmax{$class}->{'max'} < $value) {
          $measure_minmax{$class}->{'max'} = $value
        }
      }
    }#measure belongs to a class

    # total min/max
    if ($measure_minmax{'min'} > $value) {
      $measure_minmax{'min'} = $value;
    }
    if ($measure_minmax{'max'} < $value) {
      $measure_minmax{'max'} = $value
    }
  }#each measure

  return %measure_minmax;
}#calc_minmax_measures


###########################
# calc_position_location() -- called as eval($calc_func)

sub calc_position_location {
  my ($self, $chromosome, $start, $end, $strand) = @_;

  my $reverse_ruler = $self->{reverse_ruler};
  my $chromosome_locs_ref = $self->{chromosome_locs};
  my $scale_factor  = $self->{scale_factor};
  my $chrom_width   = $self->{chrom_width};

  my $ini = $self->{ini};

  my $width  = $ini->val('PresentGlyph', 'width');
  my $offset = $ini->val('PresentGlyph', 'offset');
  my $shape  = $ini->val('PresentGlyph', 'shape');

  my $enable_pileup = $ini->val('PresentGlyph', 'enable_pileup');
  my $pileup_width  = $width + $ini->val('PresentGlyph', 'pileup_gap');
  
  my ($x1, $x2, $y1, $y2, $pileup_count);
  
  # calculate y positions:
  if ($reverse_ruler == 1) {
    my $chrymax = $chromosome_locs_ref->{'chrbase'};
    $y1 = int($chrymax - $scale_factor * $start);
  }
  else {
    my $chryloc = $chromosome_locs_ref->{'chrbase'};
    $y1 = int($chryloc + $scale_factor * $start);
  }
  $y2 = int($y1 + $width);

  # calculate x positions (pile up close postions)
  if ($shape =~ /^doublecircle/) {
    # double circles are unique: drawn on top of chrs, no offset, no piling-up
    #   and width is doubled
    my $glyph_width = 2 * $width;
    my $chr_width = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'xmax'}
                  - $chromosome_locs_ref->{'locations'}->{$chromosome}->{'xmin'};
    my $glyph_offset = ($chr_width - $glyph_width) / 2;
    $x1 = int($chromosome_locs_ref->{'locations'}->{$chromosome}->{'xmin'} 
              + $glyph_offset);
    $x2 = int($chromosome_locs_ref->{'locations'}->{$chromosome}->{'xmax'} 
              - $glyph_offset);
  }#is a doublecircle position
  else {
    my $chrxloc = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'xmin'};
    if (!$enable_pileup) {
      $pileup_count = 0;
    }
    
    my $position_bins = $self->{position_bins};
    my $bin = $y1 / $width;
  
    if ($offset < 0 
          || ($self->{show_strands} == 1 && $strand eq '-')) {
      # draw on left side of chrom
      if ($enable_pileup) {
        $pileup_count = $position_bins->{$chromosome}{'minus'}[$bin]++;
      }
      $x1 = int($chrxloc + $offset - $width/2
                 - $pileup_count * $pileup_width);
    }#draw on left side
    else {
      # draw on right side of chrom
      if ($enable_pileup) {
        $pileup_count = $position_bins->{$chromosome}{'plus'}[$bin]++;
      }

      $x1 = int($chrxloc + $chrom_width + $offset + $width/2
                 + $pileup_count * $pileup_width + 1);
    }#draw on right side
    $x2 = int($x1 + $width);
  }#not a doublecircle position

  return ($x1, $y1, $x2, $y2, $pileup_count);
}#calc_position_location


########################
# calc_range_location() -- called as eval($calc_func)

sub calc_range_location {
  my ($self, $chromosome, $start, $end, $strand) = @_;

  my $reverse_ruler = $self->{reverse_ruler};
  my $chromosome_locs_ref = $self->{chromosome_locs};
  my $scale_factor  = $self->{scale_factor};
  my $chrom_width   = $self->{chrom_width};

  my $ini = $self->{ini};
  my $width         = $ini->val('PresentGlyph', 'width');
  my $offset        = $ini->val('PresentGlyph', 'offset');
  my $enable_pileup = $ini->val('PresentGlyph', 'enable_pileup');
  my $pileup_width  = $width + $ini->val('PresentGlyph', 'pileup_gap');

  my ($x1, $x2, $y1, $y2, $pileup_count);
  
  # feature start is relative to chr start
  my $range_size = $end - $start;
  if ($reverse_ruler == 1) {
    my $chrymax = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'ymax'};
    $y1 = int($chrymax - $scale_factor*($start+$range_size));
  }
  else {
    my $chryloc = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'ymin'};
    $y1 = int($chryloc + $scale_factor * $start);
  }
  $y2 = int($y1 + $range_size * $scale_factor);
  
  # calculate height. Will be at least 2 pixels
  my $h = ($end-$start) * $scale_factor;
  if ($h < 2) {
    $h = 2;
  }
  
  # check to see if this range needs to be bumped out; convenience vars
  my $rt_range_pileup_end = $self->{rt_range_pileup_end};
  my $lf_range_pileup_end = $self->{lf_range_pileup_end};
  
  my $bumpout = $self->{bumpout};
  $pileup_count = 0;

  if (!$enable_pileup) {
    $bumpout = 0;
    $self->{bumpout} = $bumpout;
  }
  else {
    if ($self->{show_strands} == 1 && $strand eq '+') {
      # double strands
      if (!$rt_range_pileup_end->{$chromosome} 
            || $end*$scale_factor < $rt_range_pileup_end->{$chromosome}) {
         # starting a new chromosome; reset pileup_end
         $rt_range_pileup_end->{$chromosome} = int($start * $scale_factor) + $h;
         $bumpout = 0;
      }
      elsif (int($start*$scale_factor) <= $rt_range_pileup_end->{$chromosome}) {
         # bump out the range bar
         $pileup_count = 1; # just indicates that ranges are piled up, not actual count
         $bumpout += $width + $pileup_width;
      }
      else {
         # start a new pileup
         $rt_range_pileup_end->{$chromosome} = int($end * $scale_factor) + $h;
         $bumpout = 0;
      }
    }#double strands, range on right side of chromosome
    
    else {
      if (!$lf_range_pileup_end->{$chromosome} 
            || int($start*$scale_factor) > $lf_range_pileup_end->{$chromosome}) {
         # starting a new chromosome; reset pileup_end
         $lf_range_pileup_end->{$chromosome} = int($start * $scale_factor) + $h;
         $bumpout = 0;
      }
      # note: features are ordered by position
      elsif (int($start*$scale_factor) <= $lf_range_pileup_end->{$chromosome}) {
         # bump out the range bar
         $pileup_count = 1; # just indicates that ranges are piled up, not actual count
         $bumpout += $width + $pileup_width;
      }
      else {
         # start a new pileup
         $lf_range_pileup_end->{$chromosome} = int($start * $scale_factor) + $h;
         $bumpout = 0;
      }
    }#range on left side of chromosome
  
    $self->{rt_range_pileup_end} = $rt_range_pileup_end;
    $self->{lf_range_pileup_end} = $lf_range_pileup_end;
    $self->{bumpout}             = $bumpout;
  }

  my $chrxloc = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'xmin'};
  if (($self->{show_strands} == 1 && $strand eq '-')
            || $offset < 0) {
    # draw to the left of the chromosome
    $x1 = $chrxloc + $offset - $bumpout - $width;
    $x2 = $x1 + $width;
  }
  elsif ($self->{show_strands} == 1 
            && $strand ne '+' && $strand ne '-') {
    # draw on top of the two strands (ignore bumpout)
    $x1 = $chrxloc + 2;
    $x2 = $x1 + $chrom_width - 4;
  }#show chromosome strands
  else {
    # draw right of chromosome according to offset
    $x1 = $chrxloc
          + $chrom_width + $offset + $bumpout;
    $x2 = $x1 + $width;
  }

  return ($x1, $y1, $x2, $y2, $pileup_count);
}#calc_range_location


####################
# get_label_coords()

sub get_label_coords {
  my ($self, $label, $chromosome, $x1, $x2, $y1, $y2, $opts) = @_;

  my ($str_width, $str_height);
  my @bounds; #x1, y1, x2, y2
  my $draw_right = 1;
  my $label_x = $x1;
  my $label_y = $y1;

  my $chr_xloc = $self->{chromosome_locs}->{'locations'}->{$chromosome}->{'xmax'};

  ($str_width, $str_height) 
      = $self->{font_mgr}->get_text_dimension($opts->{'font'},
                                              $opts->{'font_face'}, 
                                              $opts->{'font_size'}, 
                                              $label);
  if ($self->{font_mgr}->useTrueType($opts)) {
    $label_y += int($str_height/4);
  }
  else {
    $label_y -= int($str_height/2);
  }

  if ($opts->{'label_offset'} < 0) {
    # right-justify on the left side of the chromosome
    $draw_right = 0;
    $label_x = $x1 + $opts->{'label_offset'} - $str_width - $opts->{'width'};
    @bounds = ($label_x, $label_y,
               $label_x + $str_width, $label_y + $str_height);
  }
  else {
    $label_x = $x2 + $opts->{'label_offset'};
    @bounds = ($label_x, $label_y,
               $label_x + $str_width, $label_y + $str_height);
  }

  return @bounds;
}#get_label_coords


#################
# getRealMinMax()

sub getRealMinMax {
  my ($self, $class) = @_;
  my ($real_min, $real_max);
  if (defined $class && $self->{measure_params} && $self->{measure_params}->{$class}) {
    $real_min = $self->{measure_params}->{$class}->{'min'};
    $real_max = $self->{measure_params}->{$class}->{'max'};
  }
  elsif ($self->{measure_params}) {
    $real_min = $self->{measure_params}->{'min'};
    $real_max = $self->{measure_params}->{'max'};
  }
  if (!defined $real_min && !defined $real_max) {
    # This case is most likely to happen when drawing the legend.
    $real_min = 0;
    $real_max = 10;
  }

  return ($real_min, $real_max);
}#getRealMinMax


#################
# get_ruler_min()

sub get_ruler_min {
  my $self = $_[0];
  return $self->{ruler_min};
}#get_ruler_min


#################
# get_ruler_max()

sub get_ruler_max {
  my $self = $_[0];
  return $self->{ruler_max};
}#get_ruler_max


#################
# getRulerMinMax()

sub getRulerMinMax {
  my ($self, $chromosomes_ref) = @_;
  
  # Check if already calculated
  if (!($self->{ruler_min} == 0 && $self->{ruler_max} == 0)) {
    return ($self->{ruler_min},$self->{ruler_max});
  }
  
  # Need to calculate ruler min/max
  my @chromosomes = @$chromosomes_ref;
  
  my $ini = $self->{ini};
  my $ruler_min = $ini->val('general', 'ruler_min');
  my $ruler_max = $ini->val('general', 'ruler_max');
  foreach my $record (@chromosomes) {
    my ($chromosome, $source, $type, $start, $end, $d1, $d2, $d3, $attrs) = @$record;
    if ($start < $ruler_min) {$ruler_min = $start;}
    if ($end > $ruler_max) {$ruler_max = $end;};    
  }
  
  $self->{ruler_min} = $ruler_min;
  $self->{ruler_max} = $ruler_max;
  
  return ($ruler_min, $ruler_max);
}#getRulerMinMax


##################
# getLabelWidths()

sub getLabelWidths {
  my ($self, $GFF_ref) = @_;

  my $max_left_label  = 0;
  my $max_right_label = 0;
  
  foreach my $glyph (keys %$GFF_ref) {
    # Get default options from ini file (most could be overridden later)
    my %def_opts = $self->{ini}->get_drawing_options($glyph);

    next if ($glyph eq 'chromosome');
    next if (scalar @{$GFF_ref->{$glyph}} == 0);

    foreach my $record (@{$GFF_ref->{$glyph}}) {
      my %r = $self->{gff_mgr}->get_record_hash($record);
      my %opts 
        = $self->{ini}->get_drawing_options_overrides($glyph, $r{'source'}, 
                                                      $r{'type'}, \%def_opts);
      if ($opts{'draw_label'}) {
        my $name = '';
        if (defined $r{'attrs'}{'name'} && $r{'attrs'}{'name'} ne '') {
          $name = $r{'attrs'}{'name'};
        }
        elsif (defined $r{'attrs'}{'id'} && $r{'attrs'}{'id'} ne '') {
          $name = $r{'attrs'}{'id'};
        }
        if ($name ne '') {
          my ($str_width, $str_height) 
              = $self->{font_mgr}->get_text_dimension($opts{'font'}, 
                                                      $opts{'font_face'}, 
                                                      $opts{'font_size'}, 
                                                      $name);
          if ($opts{'label_offset'} < 0) {
            if ($str_width > $max_left_label) {
              $max_left_label = $str_width;
            }
          }
          else {
            if ($str_width > $max_right_label) {
              $max_right_label = $str_width;
            }
          }
        }#has a label
      }#draw label
    }#each record
  }#each glyph
  
  return ($max_left_label, $max_right_label);
}#getLabelWidths


#################
# setChromosomes()

sub setChromosomes { 
  my ($self, $GFF_ref, $measure_minmax) = @_;

  # min/max values; used for measures only
  $self->{measure_params} = $measure_minmax;

  my $fixed_spacing = $self->{ini}->val('general', 'fixed_chrom_spacing');

  # get basic information
  $self->_parse_chromosomes($GFF_ref->{'chromosome'});

  # number of chromosomes:
  $self->{num_chroms} = scalar @{$GFF_ref->{'chromosome'}};

  # ruler min/max depends on chromosome lengths
  my ($ruler_min, $ruler_max) = $self->getRulerMinMax($GFF_ref->{'chromosome'});

  # calculate chromosome locations
  my $chromosome_locs;
  if ($fixed_spacing) {
    $chromosome_locs = $self->setFixedChromosomes($ruler_min, $ruler_max, $GFF_ref);
  }
  else {
    $chromosome_locs = $self->setVariableChromosomes($ruler_min, $ruler_max, $GFF_ref);
  }

  # Clear bins for piling up glyphs
  $self->{position_bins}       = {};
  $self->{rt_range_pileup_end} = {};
  $self->{lf_range_pileup_end} = {};
  $self->{bumpout}             = 0;
  
  return $chromosome_locs;
}#setChromosomes


#######################
# setFixedChromosomes()

sub setFixedChromosomes {
  # Fixed spacing of chromosomes based on settings in ini file.
  my ($self, $ruler_min, $ruler_max, $GFF_ref) = @_;
  
  my @chromosomes = @{$GFF_ref->{'chromosome'}};
  
  # Values in .ini file will be overridden if exceeded by chromosome start/end
  my $ini = $self->{ini};
  
  my $chrom_width = $ini->val('general', 'chrom_width');

  # calculate where the chromosomes will be located (in pixels)
  for my $i (0 .. $#chromosomes) {
    my %cr = $self->{gff_mgr}->get_record_hash($chromosomes[$i]);
    
    # record proper chromosome order
    push @{$self->{chromosome_locs}->{'order'}}, $cr{'chromosome'};
    
    # x-coord
    my $chrxloc = $self->{image_padding} + $self->{chrom_padding_left} 
                  + ($self->{chrom_spacing} * $i);

    # y-coord
    my $chryloc = $self->{chromosome_locs}->{'chrbase'} 
                + ($cr{'start'} - $ruler_min) * $self->{scale_factor};
    
    # y max
    my $chrymax = int($chryloc + ($cr{'end'} - $cr{'start'}) * $self->{scale_factor});
    
    my $chr = $cr{'chromosome'}; # shorthand
    $self->{chromosome_locs}->{'locations'}->{$chr}->{'start'} = $cr{'start'};
    $self->{chromosome_locs}->{'locations'}->{$chr}->{'end'}   = $cr{'end'};
    $self->{chromosome_locs}->{'locations'}->{$chr}->{'xmin'}  = $chrxloc;
    $self->{chromosome_locs}->{'locations'}->{$chr}->{'xmax'}  = $chrxloc + $chrom_width;
    $self->{chromosome_locs}->{'locations'}->{$chr}->{'ymin'}  = $chryloc;
    $self->{chromosome_locs}->{'locations'}->{$chr}->{'ymax'}  = $chrymax;
  }#each chromosome
  
  return $self->{chromosome_locs};
}#setFixedChromosomes


###########################
# setVariableChromosomes()

sub setVariableChromosomes {
  my ($self, $ruler_min, $ruler_max, $GFF_ref) = @_;
  
  my @chromosomes = @{$GFF_ref->{'chromosome'}};
  
  # Values in .ini file will be overridden if exceeded by chromosome start/end
  my $ini = $self->{ini};

  my $chrom_width = $ini->val('general', 'chrom_width');

  # put all chromosomes at the same x position initially (will be moved later)
  my $chrxloc = $self->{image_padding} + $self->{chrom_padding_left};
  for my $i (0 .. $#chromosomes) {
    my %cr = $self->{gff_mgr}->get_record_hash($chromosomes[$i]);
    
    # record proper chromosome order
    push @{$self->{chromosome_locs}->{'order'}}, $cr{'chromosome'};

    # y-coord
    my $chryloc = $self->{chromosome_locs}->{'chrbase'} 
                + ($cr{'start'} - $ruler_min) * $self->{scale_factor};
    
    # y max
    my $chrymax = int($chryloc + ($cr{'end'} - $cr{'start'}) * $self->{scale_factor}+1);
    
    my $chr = $cr{'chromosome'}; # shorthand
    $self->{chromosome_locs}->{'locations'}->{$chr}->{'start'}      = $cr{'start'};
    $self->{chromosome_locs}->{'locations'}->{$chr}->{'end'}        = $cr{'end'};
    $self->{chromosome_locs}->{'locations'}->{$chr}->{'xmin'}       = $chrxloc;
    $self->{chromosome_locs}->{'locations'}->{$chr}->{'xmax'}       = $chrxloc + $chrom_width;
    $self->{chromosome_locs}->{'locations'}->{$chr}->{'ymin'}       = $chryloc;
    $self->{chromosome_locs}->{'locations'}->{$chr}->{'ymax'}       = $chrymax;
    $self->{chromosome_locs}->{'locations'}->{$chr}->{'min_glyphx'} = 0;
    $self->{chromosome_locs}->{'locations'}->{$chr}->{'max_glyphx'} = 0;
  }#each chromosome

  # loop through all glyphs; calculate position, track min/max for each chr
  foreach my $glyph (keys %$GFF_ref) {
    next if ($glyph eq 'chromosome');

    my @records = @{$GFF_ref->{$glyph}};
    next if (scalar @records == 0);  # nothing to do
    
    # Get default options from ini file (most could be overridden later)
    my %def_opts = $ini->get_drawing_options($glyph);

    foreach my $rec_ref (@records) {
      my %r = $self->{gff_mgr}->get_record_hash($rec_ref);

      # Make sure this record references a known chromosome
      next if (!$self->{chromosome_locs}->{'locations'}->{$r{'chromosome'}});

      # Calculate relative value (starting from lowest value on scale)
      my $rel_start = $r{'start'} - $ruler_min;
      my $rel_end   = $r{'end'} - $ruler_min;

      # if feature doesn't fit on chr, skip it
      next if ($rel_start < 0 || $r{'end'} > $ruler_max);

      # Look for overrides in a custom type ini section:
      my %opts 
          = $ini->get_drawing_options_overrides($glyph, 
                                                $r{'source'}, 
                                                $r{'type'}, 
                                                \%def_opts);

      # Save all drawing options in temporary ini section (in memory)
      $ini->save_drawing_options($glyph, \%opts);
      
      my ($x1, $y1, $x2, $y2, $pileup); # glyph position
      my ($lx1, $ly1, $lx2, $ly2);      # label position
      if ($glyph eq 'measure') {
        ($x1, $y1, $x2, $y2, $pileup)
            = $self->_handle_measure_glyph($rel_start, $rel_end, \%r, \%opts);
      }#handle measure
      
      # not a 'measure' glyph
      else {
        # Functions generated here include:
        #   calc_border_location, calc_centromere_location, calc_marker_location
        #   calc_range_location, calc_position_location
        my $calc_func = '$self->calc_' . $glyph . "_location('"
                      . $r{'chromosome'} . "', $rel_start, $rel_end, '" 
                      . $r{'strand'}. "')";
        ($x1, $y1, $x2, $y2, $pileup) = eval($calc_func);
      }
      
      # Get label coords
      my $name = $self->{gff_mgr}->get_name($r{'attrs'});
      if ($opts{'draw_label'} == 1 
            && ($name && $name ne '') 
            && (!$pileup || $pileup < 2)) {
        ($lx1, $ly1, $lx2, $ly2) 
              = $self->get_label_coords($name, $r{'chromosome'}, 
                                        $x1, $x2, $y1, $y2, \%opts);
      }
      else {
        ($lx1, $ly1, $lx2, $ly2) = ($x1, $y1, $x2, $y2);
      }

      my $dist1 
          = $lx1 
            - $self->{chromosome_locs}->{'locations'}->{$r{'chromosome'}}{'xmin'};
      my $dist2 
          = $lx2 
            - $self->{chromosome_locs}->{'locations'}->{$r{'chromosome'}}{'xmin'};
            
      if ($dist1 < $self->{chromosome_locs}->{'locations'}->{$r{'chromosome'}}{'min_glyphx'}) {
        $self->{chromosome_locs}->{'locations'}->{$r{'chromosome'}}{'min_glyphx'} = $dist1;
      }
      if ($dist2 > $self->{chromosome_locs}->{'locations'}->{$r{'chromosome'}}{'max_glyphx'}) {
        $self->{chromosome_locs}->{'locations'}->{$r{'chromosome'}}{'max_glyphx'} = $dist2;
      }
    }#each record
  }#each glyph type
  
  # Place chromosomes a minimum of chrom_spacing apart
  for my $i (1 .. $#chromosomes) { # skip first chrom
    my $chromosome = lc($chromosomes[$i][0]);
    my $prev_chromosome = lc($chromosomes[$i-1][0]);

    # x-coord
    my $spacing = $self->{chromosome_locs}->{'locations'}->{$prev_chromosome}->{max_glyphx};
    $spacing += -($self->{chromosome_locs}->{'locations'}->{$chromosome}->{min_glyphx});
    $spacing += 4; # a little breathing room
    if ($spacing < $self->{chrom_spacing}) {
      $spacing = $self->{chrom_spacing};
    }

    my $chrxloc = $self->{chromosome_locs}->{'locations'}->{$prev_chromosome}->{'xmax'}
                + $spacing;
    $self->{chromosome_locs}->{'locations'}->{$chromosome}->{'xmin'} = $chrxloc;
    $self->{chromosome_locs}->{'locations'}->{$chromosome}->{'xmax'} = $chrxloc + $chrom_width;
  }

  return $self->{chromosome_locs};
}#setVariableChromosomes



###############################################################################
#                            INTERNAL FUNCTIONS                               #
###############################################################################


#########################
# _handle_measure_glyph()

sub _handle_measure_glyph {
  my ($self, $rel_start, $rel_end, $r, $opts_ref) = @_;

  my ($x1, $y1, $x2, $y2, $pileup);
  my $ini   = $self->{ini};
  my $calc  = $self->{calc};
  my %attrs = $self->{gff_mgr}->get_attributes($r->{'attrs'});
  my $dbg   = $self->{dbg};

  my $class = (defined $r->{'attrs'} && $r->{'attrs'}->{'class'}) 
                  ? $r->{'attrs'}->{'class'} : undef;
  my ($real_min, $real_max) = $self->getRealMinMax($class);
  my $value = get_value($real_min, $real_max, $r->{'score'}, \%attrs, $opts_ref, $dbg);
  
  if ($r->{'type'} eq 'heatmap_legend') {

    ($x1, $y1, $x2, $y2)
        = $self->calc_heatmap_legend($r->{'chromosome'}, $rel_start, $rel_end, 
                                      $value, $r->{'score'}, $real_min, $real_max);
  }#heatmap_legend
      
  elsif ($opts_ref->{'display'} eq 'histogram') {

    # just get size of max value to avoid visually skewed images if a chrom has all
    #   low values (it may be placed close to its neighbor and the low values thereby
    #   obscured because they fill available space).
    ($x1, $y1, $x2, $y2, $pileup) 
        = $self->calc_histogram_bar($r->{'chromosome'}, $rel_start, $rel_end, 
                                    $real_max, $r->{'score'}, $real_min, $real_max);
  }#histogram
      
  elsif ($opts_ref->{'display'} eq 'heat') {

    if ($opts_ref->{'draw_as'} eq 'position') {
      ($x1, $y1, $x2, $y2, $pileup) 
           = $self->calc_position_location($r->{'chromosome'}, 
                                            $rel_start, $rel_end, 
                                            $r->{'score'});
    }
    else {
      ($x1, $y1, $x2, $y2, $pileup) 
           = $self->calc_range_location($r->{'chromosome'}, 
                                        $rel_start, $rel_end, $r->{'score'});
    }
  }#heat
      
  elsif ($opts_ref->{'display'} eq 'distance') {
    ($real_min, $real_max) = $self->getRealMinMax('');
    $value = get_value($real_min, $real_max, $r->{'score'}, \%attrs, $opts_ref, $dbg);    
    ($x1, $y1, $x2, $y2, $pileup) 
        = $self->calc_distance_measure($r->{'chromosome'}, $rel_start, $rel_end, 
                                       $r->{'score'}, $value, $real_min, $real_max, 
                                       $opts_ref);
  }#distance
  
  # Don't report errors here. They will be caught and reported when glyphs are displayed.
  $dbg->clear_error();
  
  # return the coordinates of the glyph
  return ($x1, $y1, $x2, $y2, $pileup);
}#_handle_measure_glyph


######################
# _parse_chromosomes()

sub _parse_chromosomes { 
  my ($self, $chromosomes_ref) = @_;
  
  my @chromosomes = @$chromosomes_ref;
  
  # array of chromosome names and sizes in units:
  foreach my $record (@chromosomes) {
    my %r = $self->{gff_mgr}->get_record_hash($record);
    my %attributes = %{$r{'attrs'}};

    my $label;
    if ($attributes{'name'}) {
      $label = $attributes{'name'};
    }
    elsif ($attributes{'id'}) {
      $label = $attributes{'id'};
    }
    else {
      $label = $r{'chromosome'};
    }
    $self->{chromosome_locs}->{'locations'}->{$r{'chromosome'}}->{'label'} = trim($label);
    $self->{chromosome_locs}->{'attributes'}->{$r{'chromosome'}} = \%attributes;
  }#foreach chromosome
}#_parse_chromosomes


1;  # so that the require or use succeeds