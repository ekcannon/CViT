#!/usr/bin/perl

# File: CvitImage.pm
# Author: Ethalinda Cannon (ethy@a415software.com) 

# Use: Holds the GD::Image instance of the CViT image along with general
#        drawing attributes (scaling, padding, et cetera). 
#      Draws the title, rulers, and chromosomes.

# new()
# create_image()
# get_image()
# get_image_width()
# get_image_height()
# reverse_ruler()
# set_chrom_padding()
# set_display_ruler()
# set_image_padding()
# set_ruler_max()
# set_ruler_min()
# set_title()
# set_title_height()

# _draw_chromosomes()
# _draw_ruler()
# _draw_title()

package CvitImage;
use strict;
use warnings;
use CvitLib;

use Data::Dumper;  # for debugging



#######
# new()

sub new {
  my ($self, $image_format, $clr_mgr, $font_mgr, $ini, $dbg) = @_;
  
  $self = {};

  # Load image library
  use lib "/Users/ethycannon/installs/GD-2.56";
  if ($image_format eq 'png') {
    use GD;
    use GD::Arrow;
  }
  else {
    use GD::SVG;
    # No double-stranded chromosomes available for SVG images
  }
  $self->{'image_format'} = $image_format;

  # For colors
  $self->{clr_mgr} = $clr_mgr;

  # For fonts
  $self->{font_mgr} = $font_mgr;
  
  # The ini file
  $self->{ini} = $ini;
  
  # For debugging
  $self->{dbg} = $dbg;
  
  $self->{im}         = undef;

  # for sizing the image
  $self->{image_padding}       = $ini->val('general', 'image_padding');
  $self->{chrom_padding_left}  = $ini->val('general', 'chrom_padding_left');
  $self->{chrom_padding_right} = $ini->val('general', 'chrom_padding_right');
  
  $self->{scale_factor}  = $ini->val('general', 'scale_factor');
  $self->{chrom_width}   = $ini->val('general', 'chrom_width');
  $self->{show_strands}  = $ini->val('general', 'show_strands');
  $self->{display_ruler} = $ini->val('general', 'display_ruler');
  $self->{title}         = $ini->val('general', 'title');
  $self->{title_height}  = $ini->val('general', 'title_height');
  
  $self->{image_width}   = 0;
  $self->{image_height}  = 0;
  
  bless($self);
  return $self;
}#new


################
# create_image()
# Creates the base CViT image with chromosomes and rulers

sub create_image {
  my ($self, $ruler_min, $ruler_max, $chromosome_locs_ref) = @_;

  my $scale_factor        = $self->{scale_factor};
  my $image_padding       = $self->{image_padding};
  my $chrom_padding_left  = $self->{chrom_padding_left};
  my $chrom_padding_right = $self->{chrom_padding_right};
  my $chrom_width         = $self->{chrom_width};
  my $show_strands        = $self->{show_strands};
  my $ini                 = $self->{ini};

  # Full ruler length:
  my $rule_len_pixels 
        = ($ruler_max - $ruler_min) * $scale_factor;

  # Calculate image size
  my $num_chroms    = scalar @{$chromosome_locs_ref->{'order'}};
#eksc
  if ($num_chroms < 1) {
  	 my $msg = "\n\nERROR: No backbone chromosomes provided in GFF. "
  	         . "Unable to continue.\n\n";
  	 $self->{dbg}->reportError($msg);
  	 print $msg;
  	 exit;
  }
#^^^^^^^
  
  my $last_chrom = $chromosome_locs_ref->{'order'}->[$num_chroms-1];
  my $last_chrom_pos = $chromosome_locs_ref->{'locations'}->{$last_chrom}->{'xmax'};
  $self->{image_width} = $last_chrom_pos + $image_padding + $chrom_padding_right;
  $self->{image_height} = int($rule_len_pixels + (2 * $image_padding)+1);

  #TODO: some warning about image size could go here
  
  # Make image object (3rd arg=1 -> use true colors)
  my $im;
  if ($self->{image_format} eq 'svg') {
    $im = GD::SVG::Image->new($self->{image_width}, $self->{image_height});
  }
  else {
    $im = new GD::Image($self->{image_width}, $self->{image_height}, 1); # 1=true color
  }
      
  die "\nUnable to create image of size " 
      . $self->{image_width} . " X " 
      . $self->{image_height} 
      . "\n" 
      if (!$im);
      
  # Create colors for GD. Colors are indexed from 0; order matters.
  $self->{clr_mgr}->assign_colors($im);

  # Set background color
  $im->filledRectangle(0, 0, $self->{image_width}, $self->{image_height}, 
                       $self->{clr_mgr}->get_color($im, 'white'));

  # draw a border rectangle around entire image
  #  x,y for upper left; then x,y for lower right.
  my $border_color_name = $ini->val('general', 'border_color', 'gray15');
  $im->rectangle(0, 0, $self->{image_width}-1, $self->{image_height}-1, 
                 $self->{clr_mgr}->get_color($im, $border_color_name));

  $im = $self->_draw_title($im);
  
  # Show the ruler
  if ($self->{display_ruler} ne '0') {
    my $ruler_base = $chromosome_locs_ref->{'chrbase'};
    $im = $self->_draw_ruler($im, $ruler_base, $ruler_min, $ruler_max);
  }#display ruler

  $self->_draw_chromosomes($im, $chromosome_locs_ref);

  # Set the new image in this object
  $self->{im} = $im;
  
  return $im;
}#create_image


#################
# reverse_ruler()

sub reverse_ruler {
  my $self = $_[0];
  $self->{reverse_ruler} = 1;
}#reverse_ruler


################################################################################
# accessers (incomplete; not all fields accessible this way)

sub get_image {
  my $self = $_[0];
  return $self->{im};
}#get_image

sub get_image_width {
  my $self = $_[0];
  return $self->{image_width};
}#get_image_width

sub get_image_height {
  my $self = $_[0];
  return $self->{image_height};
}#get_image_height

sub set_display_ruler {
  my ($self, $display_ruler) = @_;
  $self->{display_ruler} = $display_ruler;
}#set_display_ruler

sub set_image_padding {
  my ($self, $image_padding) = @_;
  $self->{image_padding} = $image_padding;
}#set_image_padding

sub set_chrom_padding {
  my ($self, $chrom_padding_left, $chrom_padding_right) = @_;
  $self->{$chrom_padding_left} = $chrom_padding_left;
  $self->{$chrom_padding_right} = $chrom_padding_right;
}#set_chrom_padding

sub set_ruler_min {
  my ($self, $ruler_min) = @_;
  $self->{ruler_min} = $ruler_min;
}#set_ruler_min

sub set_ruler_max {
  my ($self, $ruler_max) = @_;
  $self->{ruler_max} = $ruler_max;
}#get_ruler_max

sub set_title {
  my ($self, $title) = @_;
  $self->{title} = $title;
}#set_title

sub set_title_height {
  my ($self, $title_height) = @_;
  $self->{title_height} = $title_height;
}#set_title_height



###############################################################################
#                            INTERNAL FUNCTIONS                               #
###############################################################################


#####################
# _draw_chromosomes()

sub _draw_chromosomes {
  my ($self, $im, $chromosome_locs_ref) = @_;

  my $scale_factor  = $self->{scale_factor};
  my $show_strands  = $self->{show_strands};

  my $clr_mgr = $self->{clr_mgr};
  my $ini = $self->{ini};

  my $chr_bdr = $ini->val('general', 'chrom_border');
  my $chrom_width = $ini->val('general', 'chrom_width');

  my $def_chr_color 
      = $clr_mgr->get_color($im, $ini->val('general', 'chrom_color'));
  my $chr_bdr_color 
      = $clr_mgr->get_color($im, $ini->val('general', 'chrom_border_color'));
  my $label_color   
      = $clr_mgr->get_color($im, $ini->val('general', 'chrom_label_color'));

  # get font information
  my ($use_ttf, $font, $font_face, $font_size, $builtin_font);
  if ($ini->val('general', 'chrom_font_face') ne ''
        && $ini->val('general', 'chrom_font_size') ne '') {
    $use_ttf = 1;
    $font_size = $ini->val('general', 'chrom_font_size');
    my $font_name = $ini->val('general', 'chrom_font_face');
    $font_face = $self->{font_mgr}->find_font_face($font_name);
    if ($font_name eq '') {
      # Fall back to default font
      $use_ttf = 0;
    }
  }#get font face for labeling chromosomes
  
  if (!$use_ttf || !$font) {
    $use_ttf = 0;
    $font = $ini->val('general', 'chrom_font');
    if ($font eq '') { $font = 1; };
  }#not ttf or font face not available
  
  print "Draw " . @{$chromosome_locs_ref->{'order'}} . " chromosomes.\n";
  # draw chromosomes
  my $chr = 0;
  foreach my $chromosome (@{$chromosome_locs_ref->{'order'}}) {
    my $x1 = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'xmin'};
    my $y1 = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'ymin'};
    my $x2 = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'xmax'};
    my $y2 = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'ymax'};
    
    # get color
    my $chr_color = $def_chr_color;
    if ($chromosome_locs_ref->{'attributes'}->{$chromosome}->{'color'}) {
       my $color_name = $chromosome_locs_ref->{'attributes'}->{$chromosome}->{'color'};
       $chr_color = $self->{clr_mgr}->get_color($im, $color_name);
    }

    # Draw chromosome (no double strand option for SVG)
    if (!$show_strands || $self->{image_format} eq 'svg') {
      # SVG can draw rectangles with 0 width
      if ($self->{image_format} eq 'svg' && ($x2-$x1) == 0) {
        $im->line($x1, $y1, $x2, $y2, $chr_color);
      }
      else {
        $im->filledRectangle($x1, $y1, $x2, $y2, $chr_color);
      }
      
      if ($chr_bdr > 0) {
        if ($self->{image_format} eq 'svg' && ($x2-$x1) == 0) {
          $im->line($x1, $y1, $x2, $y2, $chr_bdr_color);
        }
        else {
          $im->rectangle($x1, $y1, $x2, $y2, $chr_bdr_color);
        }
      }
    }
    else {
       my $width = $chrom_width/2 - 2;
       my $neg_strand 
          = GD::Arrow::LeftHalf->new(-X1=>$x1+$width, -Y1=>$y1, 
                                      -X2=>$x1+$width, -Y2=>$y2, 
                                      -WIDTH=>$width);
       $im->filledPolygon($neg_strand, $chr_color);
       my $pos_strand
          = GD::Arrow::LeftHalf->new(-X1=>$x2-$width, -Y1=>$y2, 
                                      -X2=>$x2-$width, -Y2=>$y1, 
                                      -WIDTH=>$width);
       if ($chr_bdr > 0) {
         $im->filledPolygon($pos_strand, $chr_color);
       }
    }

    # draw chromosome label
    my $label = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'label'};
    if ($use_ttf) {
      my ($str_width, $str_height)
          = $self->{font_mgr}->get_text_dimension($font, $font_face, $font_size, $label);
      $im->stringFT($label_color, $font_face, $font_size,
                    0,   # angle
                    $x1 + $chrom_width/2 - $str_width/2,
                    $y1 - 5,
                    $label);
    }
    else {
      $im->string($self->{font_mgr}->get_font($font), 
                  $x1 + $chrom_width/2 - 3*length($label), # attempt centering
                  $y1 - 20, 
                  $label, 
                  $label_color);
    }
    
    # No double-strand option for SVG
    if ($show_strands && $self->{image_format} ne 'svg') {
      # show 3'/5' at both ends of each chromosome
      my $tiny_font_face = $ini->val('general', 'tiny_font_face', '');
      if ($tiny_font_face ne '') {
        my $font_file = $self->{font_mgr}->find_font_face($tiny_font_face);
        my $strand_font_size = 6;
        my ($strand_str_width, $strand_str_height)
        = $self->{font_mgr}->get_text_dimension($font, $font_file, $strand_font_size, 
                                                "5'");
        $im->stringFT($label_color,
                      $font_file, $strand_font_size, 0,
                      $x1-$strand_str_width, $y1, 
                      "3'");
        $im->stringFT($label_color,
                      $font_file, $strand_font_size, 0, 
                      $x2, $y1, 
                      "5'");
        $im->stringFT($label_color,
                      $font_file, $strand_font_size, 0, 
                      $x1-$strand_str_width, $y2 + $strand_str_height, 
                      "5'");
        $im->stringFT($label_color,
                      $font_file, $strand_font_size, 0, 
                      $x2, $y2 + $strand_str_height, 
                      "3'");
      }
      else {
        # fall back on built in font
        $im->string($self->{font_mgr}->get_font(2)
                    , $x1, $y1-10, "3'", 
                    $label_color);
        $im->string($self->{font_mgr}->get_font(2), 
                    $x2-2, $y1-10, "5'", 
                    $label_color);
        $im->string($self->{font_mgr}->get_font(2), 
                    $x1, $y2, "5'", 
                    $label_color);
        $im->string($self->{font_mgr}->get_font(2), 
                    $x2-2, $y2, "3'", 
                    $label_color);
      }
    }#label double strands

    # Save feature coordinates
    my $start = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'start'};
    my $end = $chromosome_locs_ref->{'locations'}->{$chromosome}->{'end'};
    my $line = "$chromosome,$chromosome,$start,$end,$x1,$y1,$x2,$y2";
    push @{$self->{feature_coords}}, $line;

    $chr++;
  }#each chromosome

  return $im;
}#_draw_chromosomes


###############
# _draw_ruler()

sub _draw_ruler {
  my ($self, $im, $ruler_base, $ruler_min, $ruler_max) = @_;
  
  my $ini = $self->{ini};
  my $tick_interval        = $ini->val('general', 'tick_interval');
  my $tick_line_width      = $ini->val('general', 'tick_line_width');
  my $minor_tick_divisions = $ini->val('general', 'minor_tick_divisions');
  
  my $ruler_color_name     = $ini->val('general', 'ruler_color');
  my $ruler_color          = $self->{clr_mgr}->get_color($im, $ruler_color_name);
  my $font                 = $ini->val('general', 'ruler_font');
  my $font_face            = $ini->val('general', 'ruler_font_face');
  my $font_size            = $ini->val('general', 'ruler_font_size');

  my $draw_right = ($self->{display_ruler} eq '1' 
                      || $self->{display_ruler} eq 'R');
  my $draw_left  = ($self->{display_ruler} eq '1' 
                      || $self->{display_ruler} eq 'L');
                      
  my $use_ttf;
  if ($font_face ne '' && $font_size != 0) {
    $use_ttf = 1;
    $font_face = $self->{font_mgr}->find_font_face($font_face);
    if ($font_face eq '') {
      # Fall back to default font
      $use_ttf = 0;
    }
  }

  # This many units represented by ruler
  my $num_units = $ruler_max - $ruler_min;

  # Get length of ruler in pixels
  my ($im_width, $im_height) = $im->getBounds();
  my $ruler_len_pixels = $num_units * $self->{scale_factor};

  # This many tick marks on ruler
  my $num_of_ticks = int($num_units / $tick_interval);
    
  # Draw units label
  my $units_label = $ini->val('general', 'ruler_units', 'kbp');
  $units_label =~ s/^['\"](.*)['\"]$/$1/;
  if ($use_ttf) {
    if ($draw_left) {
      $im->stringFT($ruler_color, $font_face, $font_size, 
                    0, 5, $ruler_base - 16, 
                    $units_label, 
                   );      
    }
    if ($draw_right) {
      my ($str_width, $str_height)
          = $self->{font_mgr}->get_text_dimension($font, $font_face, $font_size, 
                                                  $units_label);
      $im->stringFT($ruler_color, $font_face, $font_size, 
                    0, $im_width - $str_width - 5, $ruler_base - 16, 
                    $units_label
                   );
    }
  }#draw units label with TTF
  else {
    if ($draw_left) {
      $im->string($self->{font_mgr}->get_font(1), 
                  5, 
                  $ruler_base - 16, 
                  $units_label, 
                  $ruler_color);
    }
    if ($draw_right) {
      my $str_width = $self->{font_mgr}->get_font_width(1) * length($units_label);
      $im->string($self->{font_mgr}->get_font(1), 
                  $im_width - $str_width - 5, 
                  $ruler_base - 16, 
                  $units_label, 
                  $ruler_color);
    }
  }#draw units label with built-in font
  
  # Left scale starts here:
  my $x_start = 5;

  # Top of both scales:
  my $y_start = $ruler_base;
  
  # draw scale backbone on both sides of image
  if ($draw_left) {
    $im->line($x_start, 
              $y_start, 
              $x_start, 
              $ruler_len_pixels + $y_start, 
              $ruler_color); 
  }
  if ($draw_right) {
    $im->line($im_width-5, 
              $y_start, 
              $im_width-5, 
              $ruler_len_pixels + $y_start, 
              $ruler_color); 
  }
  
  # draw tick marks
  for my $i (0 .. $num_of_ticks) {
    my $tick_pixels = $i * $tick_interval * $self->{scale_factor};
    
    # units might be reversed
    my $tick_label;
    if ($ini->val('general', 'reverse_ruler') == 1) {
      $tick_label = $ruler_max 
                    + $ruler_min - ($i * $tick_interval);
    }
    else {
      $tick_label = $ruler_min + ($i * $tick_interval);
    }
    if ($tick_label =~ /\./) {
      # float value; no more than 2 decimal places
      $tick_label = sprintf("%.2f", $tick_label);
    }
    $tick_label = add_commas($tick_label);
    
    # major tick 
    my $v_major = $tick_pixels + $ruler_base;
  
    # major tick marks
    if ($draw_left) {
      $im->line(5, 
                $v_major, 
                5 + $tick_line_width, 
                $v_major, 
                $ruler_color);
    }
    if ($draw_right) {
      $im->line($im_width - 5, 
                $v_major, 
                $im_width - 5 - $tick_line_width, 
                $v_major, 
                $ruler_color);
    }
    
    # minor tick marks left then right
    for my $j (0 .. $minor_tick_divisions) {
      my $v_minor = $v_major 
                    + $j * $tick_interval 
                    * $self->{scale_factor} / $minor_tick_divisions;
      # stop if past end of chromosome
      last if ($v_minor >= $ruler_base + $ruler_len_pixels); 
      if ($draw_left) {
        $im->line(5,
                  $v_minor, 
                  5 + $tick_line_width/2, 
                  $v_minor, 
                  $ruler_color);
      }
      if ($draw_right) {
        $im->line($im_width - 5, 
                  $v_minor, 
                  $im_width - 5 - $tick_line_width/2, 
                  $v_minor, 
                  $ruler_color);
      }
    }#minor tick marks
    
    # draw numbers at tick marks
    
    # handle a perl weirdness with "0" eqv 0 eqv false eqv ''
    if (!$tick_label) {
      $tick_label = "1";
    }
    
#TODO: not getting correct size of tick label
    # get size of string
    my ($str_width, $str_height)
        = $self->{font_mgr}->get_text_dimension($font, $font_face, $font_size, 
                                                $tick_label);

    if ($use_ttf) {
      if ($draw_left) {
        $im->stringFT($ruler_color,
                      $font_face, 
                      $font_size,
                      0,
                      5 + 2 * $tick_line_width,
                      $v_major + $str_height/3, 
                      $tick_label);
      }
      if ($draw_right) {
        $im->stringFT($ruler_color,
                      $font_face, 
                      $font_size,
                      0,
                      $im_width - (5 + $str_width + $tick_line_width),
                      $v_major + $str_height/3, 
                      $tick_label);
      }
     }
     else {
       if ($draw_left) {
         $im->string($self->{font_mgr}->get_font($font), 
                     5 + 2 * $tick_line_width, 
                     $v_major - $str_height/2, 
                     $tick_label, 
                     $ruler_color);
        }
        if ($draw_right) {
         $im->string($self->{font_mgr}->get_font($font), 
                     $im_width - (5 + $str_width + $tick_line_width), 
                     $v_major - $str_height/2, 
                     $tick_label, 
                     $ruler_color);
        }
     }
  }#tick marks
  
  return $im;
}#_draw_ruler


###############
# _draw_title()

sub _draw_title {
  my ($self, $im) = @_;
  
  my $title               = $self->{title};
  my $title_height        = $self->{title_height};
  my $ini                 = $self->{ini};
  
  # get title font information
  my ($use_ttf, $font_face, $font_size, $font);
  if ($ini->val('general', 'title_font_face', '') ne ''
        && $ini->val('general', 'title_font_size', '') ne '') {
    $use_ttf = 1;
    my $font_name = $ini->val('general', 'title_font_face');
    $font_size = $ini->val('general', 'title_font_size');
    $font_face = $self->{font_mgr}->find_font_face($font_name);
    if ($font_face eq '') {
      # not found, fall back to default font
      $use_ttf = 0;
    }
  }
  
  if (!$use_ttf || !$font) {
    $font = $ini->val('general', 'title_font');
  }
  
  # title location
  my ($title_x, $title_y);
  if ($ini->val('general', 'title_location', '') ne '') {
    my @location = split(/,/, $ini->val('general', 'title_location'));
    $title_x = int($location[0]);
    $title_y = int($location[1]);
  }
  else {
    $title_x = 5;
    $title_y = $title_height;
  }
  
  # title text
  my $title_color_name = $ini->val('general', 'title_color', 'black');
  $title =~ s/^['\"](.*)['\"]$/$1/;
  
  # draw the title
  if ($use_ttf) {
    $im->stringFT($self->{clr_mgr}->get_color($im, $title_color_name),
                  $font_face, 
                  $font_size,
                  0,   # angle 
                  $title_x,
                  $title_y,
                  $title);
  }
  else {
    $im->string($self->{font_mgr}->get_font($font), 
                $title_x, 
                $title_y, 
                $title, 
                $self->{clr_mgr}->get_color($im, $title_color_name));
  }

  return $im;
}#_draw_title



1;  # so that the require or use succeeds