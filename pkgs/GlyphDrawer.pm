#!/usr/bin/perl

# File: GlyphDrawer.pm
# Author: Ethalinda Cannon (ethy@a415software.com) 

# subs:
#  new()
#  draw_glyph()
#  get_error()
#  _draw_border()
#  _draw_centromere()
#  _draw_heat_bar()
#  _draw_heatmap_legend()
#  _draw_marker()
#  _draw_position()
#  _draw_range()
#  _get_glyph_color()
#  _handle_measure_glyph()
#  _will_fit()

# Use: Draws glyphs on a CViT image.

package GlyphDrawer;

use strict;
use warnings;
use List::Util qw(max min);
use CvitLib;

use Data::Dumper;      # for debugging


#######
# new()

sub new {
  my ($self, $image_format, $calc, $cvit_image, $clr_mgr, $font_mgr, $ini, $dbg) = @_;
  
  $self  = {};
  
  # Load image library
  if ($image_format eq 'png') {
    use GD;
  }
  else {
    use GD::SVG;
  }
  $self->{'image_format'} = $image_format;

  # For handling GFF records
  $self->{gff_mgr} = new GFFManager($ini, $dbg);
  
  # For placing glyphs:
  $self->{calc} = $calc;
  
  # For colors
  $self->{clr_mgr} = $clr_mgr;
  $self->{font_mgr} = $font_mgr;
  
  # The ini file
  $self->{ini} = $ini;
  
  # For debugging & error handling
  $self->{dbg} = $dbg;
  $self->{error} = '';
  
  # The image
  $self->{cvit_image} = $cvit_image;
  
  # For keeping track of class colors:
  $self->{next_class_color} = 0;

  # Custom glyph types
  my %custom_types;
  foreach my $section ($ini->Sections()) {
    if ($ini->val($section, 'feature')) {
      my $feature_name = $ini->val($section, 'feature');
      $custom_types{$feature_name} = $section;
    }
  }#each section
  $self->{custom_types} = \%custom_types;
  
  # For piling up positions and ranges
  $self->{position_bins}       = {};
  $self->{rt_range_pileup_end} = {};
  $self->{lf_range_pileup_end} = {};
  $self->{bumpout}             = 0;

  # For keeping track of pixel locations of features
  $self->{feature_coords} = [];
  
  # For 'measure' glyphs
  $self->{measure_params} = {};
  $self->{real_min} = 0;
  $self->{real_max} = 0;
  $self->{num_heat_colors} = 0;
  
  $self->{heat_color_unit} = {('all' => 1)};
  
  bless($self);
  return $self;
}#new


##############
# draw_glyph()
# Draw glyphs for the given set of records and type.

sub draw_glyph {
  my ($self, $records_ref, $glyph) = @_;
  
  my $dbg = $self->{dbg};
  
  my $measure_minmax_ref;
  if ($glyph eq 'measure') {
    $measure_minmax_ref = $_[3];
  }

  # Dereference arrays and hashes
  my @records = @$records_ref;

  # Make sure there's something to draw
  if (scalar @records == 0) {
    return;
  }

  # Where all the drawing options are:
  my $ini = $self->{ini};
  
  # Get default options from ini file (most could be overridden later)
  my %def_opts = $ini->get_drawing_options($glyph);

  # make this a little easier
  my $calc= $self->{calc};
  
  # The actual image...
  my $im = $self->{cvit_image}->get_image();
  
  # Applies only if glyph is 'measure':
  my ($heat_colors);
  if ($glyph eq 'measure') {
    $self->{measure_params} = $measure_minmax_ref;

    if ($def_opts{'display'} eq 'heat') {
      # We'll need these colors...
      my $im = $self->{cvit_image}->get_image();
      $self->{clr_mgr}->create_heat_colors($def_opts{'heat_colors'}, $im);
      my $heat_colors_ref = scalar $self->{clr_mgr}->{heat_colors};
      $self->{num_heat_colors} = $self->{clr_mgr}->num_heat_colors();
      my $num_heat_colors = $self->{clr_mgr}->num_heat_colors();

      #...and this interval for each class:
      foreach my $classkey (keys %{$measure_minmax_ref}) {
        if ($classkey ne 'min' && $classkey ne 'max') {
          $self->{heat_color_unit}->{$classkey} 
            = $num_heat_colors / ($measure_minmax_ref->{$classkey}{'max'} 
                  - $measure_minmax_ref->{$classkey}{'min'});
        }
        else {
          $self->{heat_color_unit}{'all'}
            = $num_heat_colors / ($measure_minmax_ref->{'max'} 
                  - $measure_minmax_ref->{'min'});
        }
      }
    }
  }#measure glyph
  
  # Draw all records for this type of glyph
  print "\nDraw " . @records . " $glyph" . "s.\n";
  my %unknown_chrs;
  foreach my $record (@records) {
    my %r = $self->{gff_mgr}->get_record_hash($record);

    # Make sure this record references a known chromosome
    if (!$calc->{chromosome_locs}->{'locations'}->{$r{'chromosome'}}) {
      $unknown_chrs{$r{'chromosome'}} = 1;
      next;
    }

    # Calculate relative value (starting from lowest value on scale)
    my $rel_start = $r{'start'} - $self->{calc}->get_ruler_min();
    my $rel_end   = $r{'end'} - $self->{calc}->get_ruler_min();

    # if feature doesn't fit on chr, skip it
    if ($rel_start < 0 || $r{'end'} > $self->{calc}->get_ruler_max()) {
      print "  A feature of type $glyph with coords $r{'start'}, $r{'end'} ";
      print "doesn't fit on chromosome $r{'chromosome'}; skipped\n";
      next;
    }

    # Look for overrides in a custom type ini section:
    my %opts 
      = $ini->get_drawing_options_overrides($glyph, $r{'source'}, 
                                              $r{'type'}, \%def_opts);
      
    # Save all drawing options in temporary ini file (in memory)
    $ini->save_drawing_options($glyph, \%opts);
    
    # The glyph color:
    my $color_name = $self->_get_glyph_color($glyph, $r{'attrs'}, \%opts);

    # Draw the glyph
    my ($x1, $y1, $x2, $y2, $pileup);
    
    if ($glyph eq 'measure') {
      ($x1, $y1, $x2, $y2, $pileup)
          = $self->_handle_measure_glyph($im, $rel_start, $rel_end, $color_name, 
                                         \%r, \%opts);
    }#draw measure
    
    # not a 'measure' glyph
    else {
      if ($glyph ne 'centromere' && $glyph ne 'position' && $glyph ne 'range'
            && $glyph ne 'range' && $glyph ne 'marker' && $glyph ne 'measure'
            && $glyph ne 'border') {
        # Non-fatal error (other glyph types may be valid)
        print "\nError: unknown glyph type: '$glyph'.\n\n";
        return;
      }
      
      # Functions generated here include:
      #   _calc_border_location, _calc_centromere_location, _calc_marker_location
      #   _calc_range_location, _calc_position_location
      my $calc_func = '$calc->calc_' . $glyph . '_location(';
      $calc_func .= "'".$r{'chromosome'}."', $rel_start, $rel_end, '" .$r{'strand'}. "')";
      ($x1, $y1, $x2, $y2, $pileup) = eval($calc_func); 

      # Functions generated here include:
      #   _draw_border, _draw_centromere, _draw_marker, _draw_position, _draw_range
      if ($self->_will_fit($x1, $y1, $x2, $y2)) {
        # draw the glyph
        my $draw_func = "\$self->_draw_$glyph(\$im, $x1, $y1, $x2, $y2, ";
        $draw_func .= "'$color_name', " . $opts{'transparent'} . ")";
        eval($draw_func);
      }
    }#draw non-measure glyph

    # get feature name
    my $name = $self->{gff_mgr}->get_name($r{'attrs'});

    # draw label, if enabled
    if ($opts{'draw_label'} == 1 
          && ($name && $name ne '')
          && (!$pileup || $pileup < 2)) {
      # get font information 
      my $use_ttf = $self->{font_mgr}->useTrueType(\%opts);
    
      # location
      my ($lx1, $ly1, $lx2, $ly2) 
            = $calc->get_label_coords($name, $r{'chromosome'}, 
                                      $x1, $x2, $y1, $y2, \%opts);

      # color
      my $label_color = $self->{clr_mgr}->get_color($im, $opts{'label_color'});

      # Draw label and get coordinates
      my ($str_width, $str_height);
      my @feature_box; #x1, y1, x2, y2
      if ($use_ttf) {
        my $font_face = $self->{font_mgr}->find_font_face($opts{'font_face'});
        $im->stringFT($label_color, 
                      $font_face, $opts{'font_size'},
                      0, $lx1, $ly1,   # angle, x, y 
                      $name);
        @feature_box = (int(min $x1, $lx1),
                        int(min $y1, $ly1),
                        int(max $x2, $lx2), 
                        int(max $y2, $ly2)
                       );
      }#true type font
      
      #not true type font
      else {
        my $font_obj = $self->{font_mgr}->get_font($opts{'font'});
        $im->string($font_obj, $lx1, $ly1, $name, $label_color);
        @feature_box = (int(min $x1, $lx1),
                        int(min $y1, $ly1),
                        int(max $x2, $lx2), 
                        int(max $y2, $ly2)
                       );
      }
    }#draw label
    
    my $line = "$name,".$r{'chromosome'}.",".$r{'start'}.",".$r{'end'}.",$x1,$y1,$x2,$y2,";
    $line .= $r{'attrstr'};
    push @{$self->{feature_coords}}, $line;
    
    $dbg->handle_error("record [" . (join ",", @{$record}) . "]", $self, $self->{dbg}, 1);
  }#each record

  if (scalar (keys %unknown_chrs)) {
#eksc
    my $msg = "Some features in GFF data were mapped to unknown chromosomes.\n";
#^^^^^^^
    $msg .= "The unknown chromosomes are: " . (join ', ', keys %unknown_chrs);
    $self->{dbg}->reportError($msg);
    print "\n$msg\n\n";
  }

  return $im;
}#draw_glyph


sub get_error {
  my $self = $_[0];
  
  my $error      = $self->{error};
  $self->{error} = '';
  
  return $error;
}#get_error


###############################################################################
#                            INTERNAL FUNCTIONS                               #
###############################################################################


###############
# _draw_border (function call is constructed)

sub _draw_border {
  my ($self, $im, $x1, $y1, $x2, $y2, $color_name, $transparent) = @_;
  
  my $fill              = $self->{ini}->val('PresentGlyph', 'fill');
  my $border_color_name = $self->{ini}->val('PresentGlyph', 'border_color');
  
  if ($fill == 1) {
    $im->filledRectangle($x1+1, $y1, $x2-1, $y2, 
                         $self->{clr_mgr}->get_color($im, $color_name, $transparent));
    $im->line($x1, $y1, $x2, $y1, 
              $self->{clr_mgr}->get_color($im, $border_color_name, $transparent));
    $im->line($x1, $y2, $x2, $y2, 
              $self->{clr_mgr}->get_color($im, $border_color_name, $transparent));
  }
  else {
    # indicate just top and bottom border of range with horizontal lines
    $im->line($x1, $y1, $x2, $y1, 
              $self->{clr_mgr}->get_color($im, $color_name, $transparent));
    $im->line($x1, $y2, $x2, $y2, 
              $self->{clr_mgr}->get_color($im, $color_name, $transparent));
  }
}#_draw_border


####################
# _draw_centromere()

sub _draw_centromere {
  my ($self, $im, $x1, $y1, $x2, $y2, $color_name, $transparent) = @_;
  $im->filledRectangle($x1, $y1, $x2, $y2, 
                       $self->{clr_mgr}->get_color($im, $color_name, $transparent));
}#_draw_centromere


##################
# _draw_heat_bar()

sub _draw_heat_bar {
  my ($self, $im, $x1, $y1, $x2, $y2, $color) = @_;
  
  # SVG can't draw rectangles of 0 width or height
  if ($self->{image_format} eq 'svg' && (($x2 - $x1) == 0) || ($y2 - $y1) == 0) {
    $im->line($x1, $y1, $x2 ,$y2, $color);
  }
  else {
    $im->filledRectangle($x1, $y1, $x2, $y2, $color);
  }
}#_draw_heat_bar


########################
# _draw_heatmap_legend()
# Draw a legend image showing the range of heat colors

sub _draw_heatmap_legend {
  my ($self, $im, $init_x1, $init_y1, $init_x2, $init_y2, $min, $max, $score, 
      $label) = @_;

  if (!defined $label) { $label = ''; };
  
  my $ini          = $self->{ini};
  my $scale_factor = $self->{cvit_image}->{scale_factor}; 
  
  my $heat_colors = $self->{ini}->val('measure', 'heat_colors');
  
  # Create heat colors and get a handy pointer to the array
  $self->{clr_mgr}->create_heat_colors($heat_colors, $im);
  my $heat_colors_ref = scalar $self->{clr_mgr}->{heat_colors};

  my $inc = 10;
  my $color_inc = $self->{clr_mgr}->num_heat_colors() / $inc;
  my $width = ($init_x2 - $init_x1) / $inc;
  my $font;

  # calculate starting location:
  my $y1 = $init_y1;
  my $y2 = $y1+$width;
  my $x1 = $init_x1;
  my $x2 = $x1+$width;

  # show the range of colors
  for (my $i=0; $i<$inc; $i++) {
    my $color = $heat_colors_ref->[$color_inc * $i];
    $im->filledRectangle($x1, $y1, $x2, $y2, $color);
    $y1 = $y2;
    $y2 += $width;
  }
  
  # label range
  $x2 = $x1 + 2*$width; 
  $y1 = $init_y1;

  my $value_type = $ini->val('measure', 'value_type');
  my ($min_label, $max_label);
  if ($value_type eq 'score_col') {
    #assumed to be an e-value
    $value_type = 'e-value';
    $min_label = '0';
    $max_label = $score;
  }
  elsif ($value_type eq 'value_attr') {
    $value_type = 'value';
    $min_label = sprintf("%.2d", $min);
    $max_label = sprintf("%.2d", $max);
  }

  # if possible, use tiny font to draw min/max values
  my $tiny_font_face 
        = $self->{font_mgr}->find_font_face(
            $self->{ini}->val('general', 'tiny_font_face'));
  if ($tiny_font_face ne '') {
    my $font_size = 6;
    $im->stringFT($self->{clr_mgr}->get_color($im, 'black'),
                  $tiny_font_face, $font_size, 
                  0, $x2, $y1, 
                  $min_label);
    $im->stringFT($self->{clr_mgr}->get_color($im, 'black'),
                  $tiny_font_face, $font_size, 
                  0, $x2, $y2, 
                  $max_label);
  }#use tiny font
  else {
    # fall back to generic font
    $font = $self->{font_mgr}->get_font(3);
  
    $im->string($font, $x2, $y1-6, $min_label, 
                $self->{clr_mgr}->get_color($im, 'black')); 
    $im->string($font, $x2, $y2-6, $max_label, 
                $self->{clr_mgr}->get_color($im, 'black')); 
  }#use generic font

  # draw value type
  my ($str_width, $str_height);
  if ($ini->val('measure', 'font_face') ne ''
        && $ini->val('measure', 'font_size', 0) != 0) {
    my $font_face  = $self->{font_mgr}->find_font_face($ini->val('measure', 'font_face'));
    my $font_size  = $ini->val('measure', 'font_size');
    my $font_color = $self->{clr_mgr}->get_color($im, 'black');
    ($str_width, $str_height) 
          = $self->{font_mgr}->get_text_dimension(
              $font_face, $font_size, $font_color, ' ');
    $im->stringFT($font_color, $font_face, $font_size, 
                  0,                   # angle
                  $x2 + 2*$width-3,    # start x
                  $y1 - $str_height/2, # start y
                  "$label $value_type");
  }
  else {
    $font = $ini->val('measure', 'font');
    my $font_name = $self->{font_mgr}->get_font($font);
    $str_height = $self->{font_mgr}->get_font_height($font);
    $im->string($font_name, 
                $x2 + 2*$width + 2, 
                $y1 + ($y2 - $y1) / 2 - 3*$str_height/4,
                "$label $value_type", 
                $self->{clr_mgr}->get_color($im, 'black'));
  }
}#draw_heatmap_legend


#######################
# _draw_histogram_bar()

sub _draw_histogram_bar {
  my ($self, $im, $x1, $y1, $x2, $y2, $color_name, $transparent) = @_;
  $im->filledRectangle($x1, $y1, $x2, $y2, 
                       $self->{clr_mgr}->get_color($im, $color_name, $transparent));
}#_draw_histogram_bar


################
# _draw_marker()

sub _draw_marker {
  my ($self, $im, $x1, $y1, $x2, $y2, $color_name, $transparent) = @_;
  my $color = $self->{clr_mgr}->get_color($im, $color_name, $transparent);
  $im->line($x1, $y1, $x2, $y1, $color);
}#_draw_marker


##################
# _draw_position()

sub _draw_position {
  my ($self, $im, $x1, $y1, $x2, $y2, $color_name, $transparent) = @_;

  my $ini = $self->{ini};
  my $shape = $ini->val('PresentGlyph', 'shape');
  my $width = $ini->val('PresentGlyph', 'width');

  my $color = $self->{clr_mgr}->get_color($im, $color_name, $transparent);

  if ($shape =~ /^circle/) { # circle
    # centers the circle on the x, y position
    $im->arc($x1+$width/2, 
             $y1+$width/2,
             $width, 
             $width, 
             0, 360, $color);
    $im->fill($x1+$width/2, $y1+$width/2, $color);
  }
  
  elsif ($shape =~ /^rect/) { # rectangle
    # center the rectangle the way circles are centered above
    if ($width < 3) { # min rect height seems to be 3 pixels so draw a line
      $im->line($x1-$width/2, $y1, $x1+$width/2, $y1, $color);
    }
    else {
      $im->filledRectangle($x1, $y1, $x2, $y2, $color);
    }
  }
  
  elsif ($shape =~ /^doublecircle/) {
    $im->arc($x1+$width/2, 
             $y1, 
             $width, 
             $width, 
             0, 360, $color);
    $im->arc($x1+3*$width/2, 
             $y1, 
             $width, 
             $width, 
             0, 360, $color);
             
    if ($self->{image_format} eq 'png') {
      $im->fill($x1+$width/2, $y1, $color);
      $im->fill($x1+3*$width/2, $y1, $color);
    }
    else {
      # No fill() in GD::SVG, so keep drawing smaller circles
    }
  }
  
  else { die " unknown dot shape [$shape] (should be circle, doublecircle or rect)\n" }
}#_draw_position


###############
# _draw_range()

sub _draw_range {
  my ($self, $im, $x1, $y1, $x2, $y2, $color_name, $transparent) = @_;
#print "_draw_range($x1, $y1, $x2, $y2, $color_name, $transparent)\n";

  my $color = $self->{clr_mgr}->get_color($im, $color_name, $transparent);
  
  # SVG can't handle 0-height or -width rectangles
  if ($self->{image_format} eq 'svg' && (($x2 - $x1) == 0) || ($y2 - $y1) == 0) {
    $im->line($x1, $y1, $x2 ,$y2, $color);
  }
  else {
    $im->filledRectangle($x1, $y1, $x2, $y2, $color);
  }
}#_draw_range


###############
# _get_glyph_color()

sub _get_glyph_color {
  my ($self, $glyph, $attr_ref, $opts_ref) = @_;
  my $color_name = $opts_ref->{'color_name'};

  # use class color?
  if (exists($attr_ref->{'class'})) {
    my $class = $attr_ref->{'class'};
    if ($opts_ref->{'classes'}->{$class}) {
      $color_name = $opts_ref->{'classes'}->{$class};
    }#class color already assigned
    else {
      # create this color in the image object
      $opts_ref->{'classes'}->{$class} 
          = $opts_ref->{'class_colors'}[$self->{next_class_color}];
      $color_name = $opts_ref->{'classes'}->{$class};
      $self->{next_class_color}++;
    }#assign color to class
  }#use class color

  # override color (color attr in col 9 has the last say)?
  if ($attr_ref->{'color'} && $attr_ref->{'color'} ne '') {
    # overrides setting in .ini file and class color
    $color_name = $attr_ref->{'color'};
  }
    
  return $color_name;
}#_get_glyph_color


#######################
# _handle_measure_glyph
# Note: similar to GlyphCalc::_handle_measure_glyph but does the drawing as well.

sub _handle_measure_glyph {
  my ($self, $im, $rel_start, $rel_end, $color_name, $r, $opts_ref) 
        = @_;

  my ($x1, $y1, $x2, $y2, $pileup);
  my $ini   = $self->{ini};
  my $calc  = $self->{calc};
  my $dbg   = $self->{dbg};

  my ($value, $real_min, $real_max);
                                
  my $class = ($r->{'attrs'}->{'class'}) ? $r->{'attrs'}->{'class'} : undef;

  if ($r->{'type'} eq 'heatmap_legend') {
    ($real_min, $real_max) = $calc->getRealMinMax($class);
    $value = get_value($real_min, $real_max, $r->{'score'}, $r->{'attrs'}, $opts_ref, $dbg);
      
    ($x1, $y1, $x2, $y2)
        = $calc->calc_heatmap_legend($r->{'chromosome'}, $rel_start, $rel_end, 
                                      $value, $r->{'strand'}, 
                                      $real_min, $real_max);
    if ($self->_will_fit($x1, $y1, $x2, $y2)) {
      $self->_draw_heatmap_legend($im, $x1, $y1, $x2, $y2, $real_min, $real_max, 
                                  $r->{'score'}, $r->{'attr'}->{id});
    }#glyph fits
  }#heatmap_legend
  
  elsif ($opts_ref->{'display'} eq 'histogram') {
    ($real_min, $real_max) = $calc->getRealMinMax($class);
    $value = get_value($real_min, $real_max, $r->{'score'}, $r->{'attrs'}, $opts_ref, $dbg);

    ($x1, $y1, $x2, $y2, $pileup) 
        = $calc->calc_histogram_bar($r->{'chromosome'}, $rel_start, $rel_end, 
                                     $value, $r->{'strand'}, $real_min, $real_max);
    if ($self->_will_fit($x1, $y1, $x2, $y2)) {
      $self->_draw_histogram_bar($im, $x1, $y1, $x2, $y2, $color_name, 
                                 $opts_ref->{'transparent'});
    }#glyph fits
  }#histogram

  elsif ($opts_ref->{'display'} eq 'heat') {
    ($real_min, $real_max) = $calc->getRealMinMax($class);
    $value = get_value($real_min, $real_max, $r->{'score'}, $r->{'attrs'}, $opts_ref, $dbg);

    # If display=heatmap, make sure we have the interval
    my $heat_color_unit;
    if (defined $class && $self->{heat_color_unit}->{$class}) {
      $heat_color_unit = $self->{heat_color_unit}->{$class};
    }
    else {
      $heat_color_unit = $self->{heat_color_unit}->{'all'};
    }

    if ($opts_ref->{'draw_as'} eq 'position') {
      ($x1, $y1, $x2, $y2, $pileup) 
           = $calc->calc_position_location($r->{'chromosome'}, 
                                                   $rel_start, $rel_end, 
                                                   $r->{'strand'});
    }
    else {
      ($x1, $y1, $x2, $y2, $pileup) 
           = $calc->calc_range_location($r->{'chromosome'}, 
                                         $rel_start, $rel_end, $r->{'strand'});
    }
        
    if ($self->_will_fit($x1, $y1, $x2, $y2)) {
      # Calculate heat color
      my $color_index = int (($value - $real_min) * $heat_color_unit);
      if ($color_index >= $self->{num_heat_colors}) { 
        $color_index = $self->{num_heat_colors} - 1;
      }
      if ($color_index < 0) {
        $color_index = 0;
      }
      my $heat_colors_ref = $self->{clr_mgr}->{heat_colors};
      my @heat_colors = @$heat_colors_ref;
      my $color = $heat_colors[$color_index];
      $self->_draw_heat_bar($im, $x1, $y1, $x2, $y2, $color);
    }#glyph fits
  }#heatmap

  elsif ($opts_ref->{'display'} eq 'distance') {
    ($real_min, $real_max) = $calc->getRealMinMax('');
    $value = get_value($real_min, $real_max, $r->{'score'}, $r->{'attrs'}, $opts_ref, $dbg);
    ($x1, $y1, $x2, $y2, $pileup) 
        = $calc->calc_distance_measure($r->{'chromosome'}, $rel_start, $rel_end, 
                                       $r->{'strand'}, $value, $real_min, 
                                       $real_max, $opts_ref);
    if ($opts_ref->{'draw_as'} eq 'position') {
      $self->_draw_position($im, $x1, $y1, $x2, $y2, $color_name, 
                            $opts_ref->{'transparent'});
    }
    else {
      $self->_draw_range($im, $x1, $y1, $x2, $y2, $color_name, 
                         $opts_ref->{'transparent'});
    }
  }#distance
  
  return ($x1, $y1, $x2, $y2, $pileup);
}#_handle_measure_glyph


###############
# _will_fit()

sub _will_fit {
  my ($self, $x1, $y1, $x2, $y2) = @_;
  if (!defined $x1) {
    &show_call_stack;
  }
  
  # make sure this will fit on the image
  my $im_width = $self->{cvit_image}->get_image_width();
  my $im_height = $self->{cvit_image}->get_image_height();
  if ($x1 > $im_width || $x2 > $im_width 
        || $y1 > $im_height || $y2 > $im_height) {
    return 0;
  }
  else {
    return 1;
  }
}#_will_fit


1;  # so that the require or use succeeds