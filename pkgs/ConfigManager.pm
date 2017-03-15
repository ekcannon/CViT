#!/usr/bin/perl

# File: ConfigManager.pm
# Authors: Ethalinda Cannon (ethy@a415software.com), Steven Cannon (scannon@iastate.edu)

# Use: Read and manipulate .ini files.
#      Set defaults, parameter types, permit creation of temporary sections,
#      write out default .ini file.
#
# Documentation:
#   http://search.cpan.org/~wadg/Config-IniFiles-2.38/IniFiles.pm

# initValues()
# AddSection()
# get_custom_options()
# get_drawing_options()
# get_drawing_options_overrides()
# newval()
# Parameters()
# save_drawing_options()
# Sections()
# setval()
# val()
# writeIniFile()

package ConfigManager;
use strict;
use warnings;
use CvitLib;

use Data::Dumper;      # for debugging


#######
# new()

sub new {
  my ($self, $config_file) = @_;
  
  $self  = {};
  $self->{config} = {};
  $self->{custom_types} = {};
  
  # Make sure $config_file exists
  if ($config_file && !(-e $config_file)) {
    print "\nError: unable to find config file: $config_file\n";
    return $self;
  }
  
  if ($config_file) {
    $self->{ini} = new Config::IniFiles( -file => $config_file);
  }
  else {
    $self->{ini} = new Config::IniFiles();
  }
  bless($self);

  $self->initValues($self->{ini});
  
  return $self;
}#new


##############
# initValues()
#
# Read .ini file then set values, comments, defaults, and parameter types in a
# new hash, $self-{config}.
#
# NOTE: comments are parsed by the web tool, cvit-web to build the input form.
# NOTE: types are needed to return empty string, non-false 0, and false 0. (ick)

sub initValues {
  my ($self, $ini) = @_;
  my $config = $self->{config};
  
  #### The [general] section
  
  $config->{'general'}->{'comment'} = <<COMMENT
;###############################################################################
; Config file for CViT
;
; This file contains a number of pre-defined sections that determine the
;  appearance of various features on the CViT image. 
;
; Optional sections can be added, roughly corresponding to a GBrowse track
;  which can define the appearance of particular sequence types.
;
; Comments are parsed by utilities that need information about the options.
;  use extreme care if editing these.
;###############################################################################
COMMENT
  ;
  $config->{types}->{'logfile'} = 'string';
  $config->{'general'}->{'logfile'}->{'comment'} = <<COMMENT
Write log information to this file
TYPE: constant
COMMENT
  ;
  $config->{'general'}->{'logfile'}->{'value'} = trim($ini->val('general', 'logfile', 'cvit.log'));
  
  $config->{types}->{'errorfile'} = 'string';
  $config->{'general'}->{'errorfile'}->{'comment'} = <<COMMENT
Write errors to this file
TYPE: constant
COMMENT
  ;
  $config->{'general'}->{'errorfile'}->{'value'} = trim($ini->val('general', 'errorfile', 'cvit.log'));
  
  $config->{types}->{'title'} = 'string';
  $config->{'general'}->{'title'}->{'comment'} = <<COMMENT
Label for image
TYPE: string
COMMENT
  ;
  $config->{'general'}->{'title'}->{'value'} = trim($ini->val('general', 'title', 'CViT image'));

  $config->{types}->{'title_height'} = 'integer';
  $config->{'general'}->{'title_height'}->{'comment'} = <<COMMENT
Space allowance for title in pixels, can ignore if font face and size set
TYPE: integer|DEFAULT: 20
COMMENT
  ;
  $config->{'general'}->{'title_height'}->{'value'} = make_int($ini->val('general', 'title_height', 20));

  $config->{types}->{'title_font_face'} = 'string';
  $config->{'general'}->{'title_font_face'}->{'comment'} = <<COMMENT
Font face file name to use for title, ignored if empty
TYPE: font
COMMENT
  ;
  $config->{'general'}->{'title_font'}->{'value'} = trim($ini->val('general', 'title_font', 1));
  
  $config->{types}->{'title_font'} = 'integer';
  $config->{'general'}->{'title_font'}->{'comment'} = <<COMMENT
; Which built-in font to use (title_font_face overrides this setting)
;  0=gdLargeFont, 1=gdMediumBoldFont, 2=gdSmallFont, 3=gdTinyFont
; TYPE: enum|VALUES: (0,1,2,3)|DEFAULT: 1
COMMENT
  ;
  $config->{'general'}->{'title_font_face'}->{'value'} = trim($ini->val('general', 'title_font_face', 'vera/Vera.ttf'));
  
  $config->{types}->{'title_font_size'} = 'integer';
  $config->{'general'}->{'title_font_size'}->{'comment'} = <<COMMENT
Title font size in points, used only in conjuction with font_face
TYPE: integer|DEFAULT: 10
COMMENT
  ;
  $config->{'general'}->{'title_font_size'}->{'value'} = make_int($ini->val('general', 'title_font_size', 10));
  
  $config->{types}->{'title_color'} = 'string';
  $config->{'general'}->{'title_color'}->{'comment'} = <<COMMENT
Title font color
TYPE: color
COMMENT
  ;
  $config->{'general'}->{'title_color'}->{'value'} = trim($ini->val('general', 'title_color', 'black'));
  
  $config->{types}->{'title_location'} = 'string';
  $config->{'general'}->{'title_location'}->{'comment'} = <<COMMENT
Title location as x,y coords, ignored if missing
TYPE: coordinates
COMMENT
  ;
  $config->{'general'}->{'title_location'}->{'value'} = trim($ini->val('general', 'title_location', '')); 
  
  $config->{types}->{'image_padding'} = 'integer';
  $config->{'general'}->{'image_padding'}->{'comment'} = <<COMMENT
Space around chroms, in pixels
TYPE: integer|DEFAULT: 10
COMMENT
  ;
  $config->{'general'}->{'image_padding'}->{'value'} = make_int($ini->val('general', 'image_padding', 60));
  
  $config->{types}->{'scale_factor'} = 'float';
  $config->{'general'}->{'scale_factor'}->{'comment'} = <<COMMENT
How much to scale units (pixels per unit). NOTE: if set too high, the image 
  will be too large to create
TYPE: float|DEFAULT: .0025
COMMENT
  ;
  $config->{'general'}->{'scale_factor'}->{'value'} = make_float($ini->val('general', 'scale_factor', .0025));
  
  $config->{types}->{'border_color'} = 'string';
  $config->{'general'}->{'border_color'}->{'comment'} = <<COMMENT
Color of the border around the image
TYPE: color|DEFAULT: black
COMMENT
  ;
  $config->{'general'}->{'border_color'}->{'value'} = trim($ini->val('general', 'border_color', 'black'));
  
  $config->{types}->{'tiny_font_face'} = 'string';
  $config->{'general'}->{'tiny_font_face'}->{'comment'} = <<COMMENT
The prefered tiny font when small labels are needed: (note that silkscreen 
  does not have lower case letters)
TYPE: font
COMMENT
  ;
  $config->{'general'}->{'tiny_font_face'}->{'value'} = trim($ini->val('general', 'tiny_font_face', 'silkscreen/slkscr.ttf'));
  
  $config->{types}->{'chrom_width'} = 'integer';
  $config->{'general'}->{'chrom_width'}->{'comment'} = <<COMMENT
How wide (pixels) to draw a chromosome
TYPE: integer|DEFAULT: 10
COMMENT
  ;
  $config->{'general'}->{'chrom_width'}->{'value'} = make_int($ini->val('general', 'chrom_width', 10));
  
  $config->{types}->{'fixed_chrom_spacing'} = 'boolean';
  $config->{'general'}->{'fixed_chrom_spacing'}->{'comment'} = <<COMMENT
; Fixed or variable chromosome spacing. If variable, chrom_spacing will give minimum
;  distance between chromosomes
; TYPE: boolean|DEFAULT: 1
COMMENT
  ;
  $config->{'general'}->{'fixed_chrom_spacing'}->{'value'} = make_int($ini->val('general', 'fixed_chrom_spacing', 1));

  $config->{types}->{'chrom_spacing'} = 'integer';
  $config->{'general'}->{'chrom_spacing'}->{'comment'} = <<COMMENT
How far apart to space the chromosomes
TYPE: integer|DEFAULT: 90
COMMENT
  ;
  $config->{'general'}->{'chrom_spacing'}->{'value'} = make_int($ini->val('general', 'chrom_spacing', 90));
  
  $config->{types}->{'chrom_padding_left'} = 'integer';
  $config->{'general'}->{'chrom_padding_left'}->{'comment'} = <<COMMENT
Extra chrom padding on the left
TYPE: integer|DEFAULT: 0
COMMENT
  ;
  $config->{'general'}->{'chrom_padding_left'}->{'value'} = make_int($ini->val('general', 'chrom_padding_left', 0));
  
  $config->{types}->{'chrom_padding_right'} = 'integer';
  $config->{'general'}->{'chrom_padding_right'}->{'comment'} = <<COMMENT
Extra chrom padding on the right
TYPE: integer|DEFAULT: 0
COMMENT
  ;
  $config->{'general'}->{'chrom_padding_right'}->{'value'} = make_int($ini->val('general', 'chrom_padding_right', 0));
  
  $config->{types}->{'chrom_color'} = 'string';
  $config->{'general'}->{'chrom_color'}->{'comment'} = <<COMMENT
Fill color for the chromosome bar
TYPE: color|DEFAULT: gray50
COMMENT
  ;
  $config->{'general'}->{'chrom_color'}->{'value'} = trim($ini->val('general', 'chrom_color', 'gray50'));
  
  $config->{types}->{'chrom_border'} = 'boolean';
  $config->{'general'}->{'chrom_border'}->{'comment'} = <<COMMENT
Whether or not to draw a border for the chromosome bar
TYPE: boolean|DEFAULT: 1
COMMENT
  ;
  $config->{'general'}->{'chrom_border'}->{'value'} = make_int($ini->val('general', 'chrom_border', 1));
  
  $config->{types}->{'chrom_border_color'} = 'string';
  $config->{'general'}->{'chrom_border_color'}->{'comment'} = <<COMMENT
Border color for the chromosome bar
TYPE: color|DEFAULT: black
COMMENT
  ;
  $config->{'general'}->{'chrom_border_color'}->{'value'} = trim($ini->val('general', 'chrom_border_color', 'black'));
  
  $config->{types}->{'chrom_font'} = 'integer';
  $config->{'general'}->{'chrom_font'}->{'comment'} = <<COMMENT
Which built-in font to use (ruler_font_face overrides this setting)
 0=gdLargeFont, 1=gdMediumBoldFont, 2=gdSmallFont, 3=gdTinyFont
TYPE: enum|VALUES: (0,1,2,3)|DEFAULT: 1
COMMENT
  ;
  $config->{'general'}->{'chrom_font'}->{'value'} = make_int($ini->val('general', 'chrom_font', 1));
  
  $config->{types}->{'chrom_font_face'} = 'string';
  $config->{'general'}->{'chrom_font_face'}->{'comment'} = <<COMMENT
Font face file name to use to label chromosomes
TYPE: font
COMMENT
  ;
  $config->{'general'}->{'chrom_font_face'}->{'value'} = trim($ini->val('general', 'chrom_font_face', 'vera/Vera.ttf'));
  
  $config->{types}->{'chrom_font_size'} = 'integer';
  $config->{'general'}->{'chrom_font_size'}->{'comment'} = <<COMMENT
Font size for chromosome labels in points, used only in conjuction 
  with font_face
TYPE: integer|DEFAULT: 10
COMMENT
  ;
  $config->{'general'}->{'chrom_font_size'}->{'value'} = make_int($ini->val('general', 'chrom_font_size', 10));
  
  $config->{types}->{'chrom_label_color'} = 'string';
  $config->{'general'}->{'chrom_label_color'}->{'comment'} = <<COMMENT
Color for chromosome bar label
TYPE: color|DEFAULT: gray50
COMMENT
  ;
  $config->{'general'}->{'chrom_label_color'}->{'value'} = trim($ini->val('general', 'chrom_label_color', 'gray50'));
  
  $config->{types}->{'show_strands'} = 'boolean';
  $config->{'general'}->{'show_strands'}->{'comment'} = <<COMMENT
1=show both strands, 0=don't; both strands will fit inside chrom_width
TYPE: boolean|DEFAULT: 0
COMMENT
  ;
  $config->{'general'}->{'show_strands'}->{'value'} = make_int($ini->val('general', 'show_strands', 0));
  
  $config->{types}->{'display_ruler'} = 'string';
  $config->{'general'}->{'display_ruler'}->{'comment'} = <<COMMENT
The ruler is a guide down either side of image showing units
  0=none, 1=both, L=left side only, R=right side only
TYPE: enum|VALUES: 0,1,L,R|DEFAULT: 1
COMMENT
  ;
  $config->{'general'}->{'display_ruler'}->{'value'} = trim($ini->val('general', 'display_ruler', 1));
  
  $config->{types}->{'reverse_ruler'} = 'boolean';
  $config->{'general'}->{'reverse_ruler'}->{'comment'} = <<COMMENT
1=ruler units run greatest to smallest, 0=normal order
TYPE: boolean|DEFAULT: 0
COMMENT
  ;
  $config->{'general'}->{'reverse_ruler'}->{'value'} = make_int($ini->val('general', 'reverse_ruler', 0));
  
  $config->{types}->{'rule_units'} = 'string';
  $config->{'general'}->{'ruler_units'}->{'comment'} = <<COMMENT
Ruler units (e.g. "cM, "kb")
TYPE: string
COMMENT
  ;
  $config->{'general'}->{'ruler_units'}->{'value'} = trim($ini->val('general', 'ruler_units', 'kb'));
  
  $config->{types}->{'ruler_min'} = 'float';
$config->{'general'}->{'ruler_min'}->{'comment'} = <<COMMENT
Minimum value on ruler, if > min chrom value, will be adjusted; -1 = min chr val
TYPE: float|DEFAULT: 0
COMMENT
  ;
  $config->{'general'}->{'ruler_min'}->{'value'} = make_float($ini->val('general', 'ruler_min', 0.0));
  
  $config->{types}->{'ruler_max'} = 'float';
  $config->{'general'}->{'ruler_max'}->{'comment'} = <<COMMENT
Maximum value on ruler, if < max chrom value, will be adjusted; -1 = max chr val
TYPE: float|DEFAULT: 0
COMMENT
  ;
  $config->{'general'}->{'ruler_max'}->{'value'} = make_float($ini->val('general', 'ruler_max', 0));
  
  $config->{types}->{'ruler_color'} = 'string';
  $config->{'general'}->{'ruler_color'}->{'comment'} = <<COMMENT
Color to use for the ruler(s)
TYPE: color|DEFAULT: gray60
COMMENT
  ;
  $config->{'general'}->{'ruler_color'}->{'value'} = trim($ini->val('general', 'ruler_color', 'gray60'));
  
  $config->{types}->{'ruler_font'} = 'string';
  $config->{'general'}->{'ruler_font'}->{'comment'} = <<COMMENT
Which built-in font to use (ruler_font_face overrides this setting)
 0=gdLargeFont, 1=gdMediumBoldFont, 2=gdSmallFont, 3=gdTinyFont
TYPE: enum|VALUES: (0,1,2,3)|DEFAULT: 1
COMMENT
  ;
  $config->{'general'}->{'ruler_font'}->{'value'} = make_int($ini->val('general', 'ruler_font', 1));
  
  $config->{types}->{'ruler_font_face'} = 'string';
  $config->{'general'}->{'ruler_font_face'}->{'comment'} = <<COMMENT
Font face file name to use for ruler, ignored if empty
TYPE: font
COMMENT
  ;
  $config->{'general'}->{'ruler_font_face'}->{'value'} = trim($ini->val('general', 'ruler_font_face', ''));
  
  $config->{types}->{'ruler_font_size'} = 'integer';
  $config->{'general'}->{'ruler_font_size'}->{'comment'} = <<COMMENT
Ruler font size in points, used only in conjuction with font_face
TYPE: integer
COMMENT
  ;
  $config->{'general'}->{'ruler_font_size'}->{'value'} = make_int($ini->val('general', 'ruler_font_size', 0));
  
  $config->{types}->{'tick_line_width'} = 'integer';
  $config->{'general'}->{'tick_line_width'}->{'comment'} = <<COMMENT
Width of ruler tick marks in pixels
TYPE: integer|DEFAULT: 8
COMMENT
  ;
  $config->{'general'}->{'tick_line_width'}->{'value'} = make_int($ini->val('general', 'tick_line_width', 8.0));
  
  $config->{types}->{'tick_interval'} = 'float';
  $config->{'general'}->{'tick_interval'}->{'comment'} = <<COMMENT
Ruler tick mark units in original chromosome units
TYPE: float|DEFAULT: 10000
COMMENT
  ;
  $config->{'general'}->{'tick_interval'}->{'value'} = make_float($ini->val('general', 'tick_interval', 10000));
  
  $config->{types}->{'minor_tick_divisions'} = 'float';
  $config->{'general'}->{'minor_tick_divisions'}->{'comment'} = <<COMMENT
Number of minor divisions per major tick (1 for none)
TYPE: float|DEFAULT: 2
COMMENT
  ;
  $config->{'general'}->{'minor_tick_divisions'}->{'value'} = make_int($ini->val('general', 'minor_tick_divisions', 2));

  $config->{types}->{'class_colors'} = 'array';
  $config->{'general'}->{'class_colors'}->{'comment'} = <<COMMENT
Use these colors in this order when displaying sequences of different classes.
 For example, different gene families, BACs in different phases.
See rgb.txt for possible colors
TYPE: classcolors
COMMENT
  ;
  $config->{'general'}->{'class_colors'}->{'value'} = [split ', ', $ini->val('general', 'class_colors', "red, green, blue, orange, purple, turquoise, OliveDrab, honeydew, chocolate, tomato, aquamarine, MediumSlateBlue, azure, LawnGreen, SkyBlue, chartreuse, LightYellow, maroon, yellow, FloralWhite, cyan, salmon")];

  ### Types for parameters that appear under one or more glyph types
  $config->{types}->{'centromere_overhang'} = 'integer';
  $config->{types}->{'color'}               = 'string';
  $config->{types}->{'transparent'}         = 'boolean';
  $config->{types}->{'draw_label'}          = 'boolean';
  $config->{types}->{'font'}                = 'integer';
  $config->{types}->{'font_face'}           = 'string';
  $config->{types}->{'font_size'}           = 'integer';
  $config->{types}->{'label_offset'}        = 'integer';
  $config->{types}->{'label_color'}         = 'string';
  $config->{types}->{'shape'}               = 'string';
  $config->{types}->{'width'}               = 'integer';
  $config->{types}->{'offset'}              = 'integer';
  $config->{types}->{'enable_pileup'}       = 'boolean';
  $config->{types}->{'pileup_gap'}          = 'integer';
  $config->{types}->{'fill'}                = 'boolean';
  $config->{types}->{'border_color'}        = 'string';
  $config->{types}->{'value_type'}          = 'string';
  $config->{types}->{'min'}                 = 'float';
  $config->{types}->{'max'}                 = 'float';
  $config->{types}->{'display'}             = 'string';
  $config->{types}->{'draw_as'}             = 'string';
  $config->{types}->{'heat_colors'}         = 'string';
  $config->{types}->{'max_distance'}        = 'float';
  $config->{types}->{'hist_perc'}           = 'float';


  # The [classes] section
  $config->{'classes'}->{'comment'} = <<COMMENT
Assign colors to classes like this: <class-name> = <color>
COMMENT
  ;


  # The [centromere] section
  $config->{'centromere'}->{'comment'} = <<COMMENT
#################
A centromere is a specialized feature; displayed over top the chromosome bar.
 A centromere is identified by the word "centromere" in the 3rd column of the
 GFF file.
COMMENT
  ;
  
  $config->{'centromere'}->{'centromere_overhang'}->{'comment'} = <<COMMENT
Centromere rectangle or line extends this far on either side of the 
  chromosome bar
TYPE: integer|DEFAULT: 2
COMMENT
  ;
  $config->{'centromere'}->{'centromere_overhang'}->{'value'} = make_int($ini->val('centromere', 'centromere_overhang', 2));
  
  # need to add a width for centromeres (not defined in config file); required for label
  $config->{'centromere'}->{'width'}->{'value'} 
    = $config->{'centromere'}->{'centromere_overhang'}->{'value'} * 2;
      
  $config->{'centromere'}->{'color'}->{'comment'} = <<COMMENT
Color to use when drawing the centromere
TYPE: color|DEFAULT: gray30
COMMENT
  ;
  $config->{'centromere'}->{'color'}->{'value'} = trim($ini->val('centromere', 'color', 'gray30'));

  $config->{'centromere'}->{'transparent'}->{'comment'} = <<COMMENT
Whether or not to use transparency
TYPE: boolean|DEFAULT: 0
COMMENT
  ;
  $config->{'centromere'}->{'transparent'}->{'value'} = make_int($ini->val('centromere', 'transparent', 0));

  $config->{'centromere'}->{'draw_label'}->{'comment'} = <<COMMENT
1 = draw centromere label, 0 = don't
TYPE: boolean|DEFAULT: 0
COMMENT
  ;
  $config->{'centromere'}->{'draw_label'}->{'value'} = make_int($ini->val('centromere', 'draw_label', 0));

  $config->{'centromere'}->{'font'}->{'comment'} = <<COMMENT
Which built-in font to use for centromere labels (font_face overrides this
  setting) 0=gdLargeFont, 1=gdMediumBoldFont, 2=gdSmallFont, 3=gdTinyFont
TYPE: enum|VALUES: 0,1,2,3|DEFAULT: 2
COMMENT
  ;
  $config->{'centromere'}->{'font'}->{'value'} = make_int($ini->val('centromere', 'font', 2));

  $config->{'centromere'}->{'font_face'}->{'comment'} = <<COMMENT
Font face file name to use for centromere label
TYPE: font
COMMENT
  ;
  $config->{'centromere'}->{'font_face'}->{'value'} = trim($ini->val('centromere', 'font_face', 'vera/Vera.ttf'));

  $config->{'centromere'}->{'font_size'}->{'comment'} = <<COMMENT
Font size in points, used only in conjuction with font_face
TYPE: integer|DEFAULT: 6
COMMENT
  ;
  $config->{'centromere'}->{'font_size'}->{'value'} = make_int($ini->val('centromere', 'font_size', 6));

  $config->{'centromere'}->{'label_offset'}->{'comment'} = <<COMMENT
Start labels this many pixels right of region bar (negative value to move
  label to the left)
TYPE: integer
COMMENT
  ;
  $config->{'centromere'}->{'label_offset'}->{'value'} = make_int($ini->val('centromere', 'label_offset', 4));

  $config->{'centromere'}->{'label_color'}->{'comment'} = <<COMMENT
Color to use for labels
TYPE: color|DEFAULT: gray30
COMMENT
  ;
  $config->{'centromere'}->{'label_color'}->{'value'} = trim($ini->val('centromere', 'label_color', 'gray30'));


  # The [position] section

  $config->{'position'}->{'comment'} = <<COMMENT
#################
Positions are displayed as dots or rectangles beside the chromosome bar.
Positions that are too close to be stacked are "piled up" in a line.
A sequence feature is designated a position if its section sets glyph=position
  or if the start and end coordinates are equivalent.
COMMENT
  ;
  $config->{'position'}->{'color'}->{'comment'} = <<COMMENT
Color to use when drawing positions, can be overridden with the 
 color= attribute in the GFF file
TYPE: color|DEFAULT: red
COMMENT
  ;
  $config->{'position'}->{'color'}->{'value'} = trim($ini->val('position', 'color', 'maroon'));

  $config->{'position'}->{'transparent'}->{'comment'} = <<COMMENT
Whether or not to use transparency
TYPE: boolean|DEFAULT: 0
COMMENT
  ;
  $config->{'position'}->{'transparent'}->{'value'} = make_int($ini->val('position', 'transparent', 0));

  $config->{'position'}->{'shape'}->{'comment'} = <<COMMENT
Shape to indicate a position
TYPE: enum|VALUES: circle,rect,doublecircle|DEFAULT: circle
COMMENT
  ;
  $config->{'position'}->{'shape'}->{'value'} = trim($ini->val('position', 'shape', 'circle'));

  $config->{'position'}->{'width'}->{'comment'} = <<COMMENT
Width of the shape
TYPE: integer|DEFAULT: 5
COMMENT
  ;
  $config->{'position'}->{'width'}->{'value'} = make_int($ini->val('position', 'width', 5));

  $config->{'position'}->{'offset'}->{'comment'} = <<COMMENT
Offset shape this many pixels from chromosome bar
TYPE: integer
COMMENT
  ;
  $config->{'position'}->{'offset'}->{'value'} = make_int($ini->val('position', 'offset', 4));

  $config->{'position'}->{'enable_pileup'}->{'comment'} = <<COMMENT
Whether or not to "pileup" overlaping glyphs
TYPE: boolean|DEFAULT: 1
COMMENT
  ;
  $config->{'position'}->{'enable_pileup'}->{'value'} = make_int($ini->val('position', 'enable_pileup', 1));

  $config->{'position'}->{'pileup_gap'}->{'comment'} = <<COMMENT
The space between adjacent, piled-up positions
TYPE: integer|DEFAULT: 0
COMMENT
  ;
  $config->{'position'}->{'pileup_gap'}->{'value'} = make_int($ini->val('position', 'pileup_gap', 0));

  $config->{'position'}->{'draw_label'}->{'comment'} = <<COMMENT
1 = draw position label, 0 = don't
TYPE: boolean|DEFAULT: 1
COMMENT
  ;
  $config->{'position'}->{'draw_label'}->{'value'} = make_int($ini->val('position', 'draw_label', 1));

  $config->{'position'}->{'font'}->{'comment'} = <<COMMENT
Which built-in font to use for position labels (font_face overrides this
  setting) 0=gdLargeFont, 1=gdMediumBoldFont, 2=gdSmallFont, 3=gdTinyFont
TYPE: enum|VALUES: 0,1,2,3|DEFAULT: 2
COMMENT
  ;
  $config->{'position'}->{'font'}->{'value'} = make_int($ini->val('position', 'font', 2));

  $config->{'position'}->{'font_face'}->{'comment'} = <<COMMENT
Font face file name to use for labeling positions (overrides 'font' setting)
TYPE: font
COMMENT
  ;
  $config->{'position'}->{'font_face'}->{'value'} = trim($ini->val('position', 'font_face', 'vera/Vera.ttf'));

  $config->{'position'}->{'font_size'}->{'comment'} = <<COMMENT
Font size in points, used only in conjunction with font_face
TYPE: integer
COMMENT
  ;
  $config->{'position'}->{'font_size'}->{'value'} = make_int($ini->val('position', 'font_size', 6));

  $config->{'position'}->{'label_offset'}->{'comment'} = <<COMMENT
Start labels this many pixels right of region bar (negative value to move
  label to the left)
TYPE: integer
COMMENT
  ;
  $config->{'position'}->{'label_offset'}->{'value'} = make_int($ini->val('position', 'label_offset', 4));

  $config->{'position'}->{'label_color'}->{'comment'} = <<COMMENT
Color to use for labels
TYPE: color|DEFAULT: black
COMMENT
  ;
  $config->{'position'}->{'label_color'}->{'value'} = trim($ini->val('position', 'label_color', 'black'));

  
  # The [range] section
  
  $config->{'range'}->{'comment'} = <<COMMENT
#################
Ranges are displayed as bars alongside the chromosome bar or as borders 
  draw within the chromosome bar.
A sequence feature is designated a range if its section sets glyph=range or
  if the start and end coordinates differ
COMMENT
  ;
  $config->{'range'}->{'color'}->{'comment'} = <<COMMENT
Color for drawing ranges; can be overridden with the color= 
  attribute in GFF file.
TYPE: color|DEFAULT: green
COMMENT
  ;
  $config->{'range'}->{'color'}->{'value'} = trim($ini->val('range', 'color', 'green'));

  $config->{'range'}->{'transparent'}->{'comment'} = <<COMMENT
Whether or not to use transparency
TYPE: boolean|DEFAULT: 0
COMMENT
  ;
  $config->{'range'}->{'transparent'}->{'value'} = make_int($ini->val('range', 'transparent', 0));

  $config->{'range'}->{'width'}->{'comment'} = <<COMMENT
Draw range bars this thick
TYPE: integer|DEFAULT: 6
COMMENT
  ;
  $config->{'range'}->{'width'}->{'value'} = make_int($ini->val('range', 'width', 6));

  $config->{'range'}->{'offset'}->{'comment'} = <<COMMENT
Draw range bars this much to the right of the corresponding chromosome
 (negative value to move bar to the left)
TYPE: integer
COMMENT
  ;
  $config->{'range'}->{'offset'}->{'value'} = make_int($ini->val('range', 'offset', 3));

  $config->{'range'}->{'enable_pileup'}->{'comment'} = <<COMMENT
Whether or not to "pileup" overlaping glyphs
TYPE: boolean|DEFAULT: 1
COMMENT
  ;
  $config->{'range'}->{'enable_pileup'}->{'value'} = make_int($ini->val('range', 'enable_pileup', 1));

  $config->{'range'}->{'pileup_gap'}->{'comment'} = <<COMMENT
Space between adjacent, piled-up ranges
TYPE: integer|DEFAULT: 0
COMMENT
  ;
  $config->{'range'}->{'pileup_gap'}->{'value'} = make_int($ini->val('range', 'pileup_gap', 0));

  $config->{'range'}->{'draw_label'}->{'comment'} = <<COMMENT
1 = draw range label, 0 = don't
TYPE: boolean|DEFAULT: 1
COMMENT
  ;
  $config->{'range'}->{'draw_label'}->{'value'} = make_int($ini->val('range', 'draw_label', 1));

  $config->{'range'}->{'font'}->{'comment'} = <<COMMENT
Which built-in font to use for range labels (font_face overrides this setting)
  0=gdLargeFont, 1=gdMediumBoldFont, 2=gdSmallFont, 3=gdTinyFont
TYPE: enum|VALUES: 0,1,2,3|DEFAULT: 1
COMMENT
  ;
  $config->{'range'}->{'font'}->{'value'} = make_int($ini->val('range', 'font', 1));

  $config->{'range'}->{'font_face'}->{'comment'} = <<COMMENT
Font face file name to use for labeling ranges (overrides 'font' setting)
TYPE: font
COMMENT
  ;
  $config->{'range'}->{'font_face'}->{'value'} = trim($ini->val('range', 'font_face', 'vera/Vera.ttf'));

  $config->{'range'}->{'font_size'}->{'comment'} = <<COMMENT
Font size in points, used only in conjunction with font_face
TYPE: integer
COMMENT
  ;
  $config->{'range'}->{'font_size'}->{'value'} = make_int($ini->val('range', 'font_size', 6));

  $config->{'range'}->{'label_offset'}->{'comment'} = <<COMMENT
Start labels this many pixels right of region bar (negative value to move
  label to the left)
TYPE: integer
COMMENT
  ;
  $config->{'range'}->{'label_offset'}->{'value'} = make_int($ini->val('range', 'label_offset', 5));

  $config->{'range'}->{'label_color'}->{'comment'} = <<COMMENT
Color to use for labels
TYPE: color|DEFAULT: black
COMMENT
  ;
  $config->{'range'}->{'label_color'}->{'value'} = trim($ini->val('range', 'label_color', 'black'));


  # The [border] section
  
  $config->{'border'}->{'comment'} = <<COMMENT
#################
A border is displayed directly over the chromosome.
A sequence feature is designated a range if its section sets glyph=border.
COMMENT
  ;
  $config->{'border'}->{'color'}->{'comment'} = <<COMMENT
Color for filling borders; can be over-ridden with the color= 
  attribute in GFF file.
TYPE: color|DEFAULT: red
COMMENT
  ;
  $config->{'border'}->{'color'}->{'value'} = trim($ini->val('border', 'color', 'red'));

  $config->{'border'}->{'border_color'}->{'comment'} = <<COMMENT
Color for drawing borders; can be over-ridden with the color= 
  attribute in GFF file.
TYPE: color|DEFAULT: red
COMMENT
  ;
  $config->{'border'}->{'border_color'}->{'value'} = trim($ini->val('border', 'border_color', 'black'));

  $config->{'border'}->{'fill'}->{'comment'} = <<COMMENT
1=fill in area between borders, 0=don't
TYPE: boolean|DEFAULT: 0
COMMENT
  ;
  $config->{'border'}->{'fill'}->{'value'} = make_int($ini->val('border', 'fill', 0));

  # create an internal option, width, not specified in config file; required for label
  $config->{'border'}->{'width'}->{'value'} = 0;
  
  $config->{'border'}->{'transparent'}->{'comment'} = <<COMMENT
Whether or not to use transparency
TYPE: boolean|DEFAULT: 0
COMMENT
  ;
  $config->{'border'}->{'transparent'}->{'value'} = make_int($ini->val('border', 'transparent', 0));

  $config->{'border'}->{'draw_label'}->{'comment'} = <<COMMENT
1 = show labels, 0 = don't
TYPE: boolean|DEFAULT: 1
COMMENT
  ;
  $config->{'border'}->{'draw_label'}->{'value'} = make_int($ini->val('border', 'draw_label', 1));

  $config->{'border'}->{'font'}->{'comment'} = <<COMMENT
Built-in font to use for border labels (font_face overrides this setting)
  0=gdLargeFont, 1=gdMediumBoldFont, 2=gdSmallFont, 3=gdTinyFont
TYPE: enum|VALUES: 0,1,2,3|DEFAULT: 1
COMMENT
  ;
  $config->{'border'}->{'font'}->{'value'} = make_int($ini->val('border', 'font', 1));

  $config->{'border'}->{'font_face'}->{'comment'} = <<COMMENT
Font face file name to use for labeling borders (overrides 'font' setting)
TYPE: font
COMMENT
  ;
  $config->{'border'}->{'font_face'}->{'value'} = trim($ini->val('border', 'font_face', 'vera/Vera.ttf'));

  $config->{'border'}->{'font_size'}->{'comment'} = <<COMMENT
Font size in points, used only in conjunction with font_face
TYPE: integer
COMMENT
  ;
  $config->{'border'}->{'font_size'}->{'value'} = make_int($ini->val('border', 'font_size', 6));

  $config->{'border'}->{'label_offset'}->{'comment'} = <<COMMENT
Start labels this many pixels right of chromosome (negative value to move
  label to the left)
TYPE: integer
COMMENT
  ;
  $config->{'border'}->{'label_offset'}->{'value'} = make_int($ini->val('border', 'label_offset', 5));

  $config->{'border'}->{'label_color'}->{'comment'} = <<COMMENT
Color to use for labels
TYPE: color|DEFAULT: black
COMMENT
  ;
  $config->{'border'}->{'label_color'}->{'value'} = trim($ini->val('border', 'label_color', 'black'));


  # The [marker] section

  $config->{'marker'}->{'comment'} = <<COMMENT
#################
 Markers are displayed as lines next to the chromosome.
 A sequence feature is designated a marker if its section sets glyph=marker
COMMENT
  ;
  $config->{'marker'}->{'color'}->{'comment'} = <<COMMENT
Color for drawing markers; can be over-ridden with the color= 
  attribute in GFF file.
TYPE: color|DEFAULT: red
COMMENT
  ;
  $config->{'marker'}->{'color'}->{'value'} = trim($ini->val('marker', 'color', 'turquoise'));

  $config->{'marker'}->{'transparent'}->{'comment'} = <<COMMENT
Whether or not to use transparency
TYPE: boolean|DEFAULT: 0
COMMENT
  ;
  $config->{'marker'}->{'transparent'}->{'value'} = make_int($ini->val('marker', 'transparent', 0));

  $config->{'marker'}->{'offset'}->{'comment'} = <<COMMENT
Draw marker this much to the right of the corresponding chromosome
 (negative value to move bar to the left)
TYPE: integer
COMMENT
  ;
  $config->{'marker'}->{'offset'}->{'value'} = make_int($ini->val('marker', 'offset', 2));

  $config->{'marker'}->{'width'}->{'comment'} = <<COMMENT
Marker tic is this long
TYPE: integer|DEFAULT: 5
COMMENT
  ;
  $config->{'marker'}->{'width'}->{'value'} = make_int($ini->val('marker', 'width', 5));

  $config->{'marker'}->{'draw_label'}->{'comment'} = <<COMMENT
1=draw marker labels, 0=don't
TYPE: boolean|DEFAULT: 1
COMMENT
  ;
  $config->{'marker'}->{'draw_label'}->{'value'} = make_int($ini->val('marker', 'draw_label', 1)); 

  $config->{'marker'}->{'font'}->{'comment'} = <<COMMENT
Built-in font to use for labeling markers (font_face overrides this setting)
  0=gdLargeFont, 1=gdMediumBoldFont, 2=gdSmallFont, 3=gdTinyFont
TYPE: enum|VALUES: 0,1,2,3|DEFAULT: 1
COMMENT
  ;
  $config->{'marker'}->{'font'}->{'value'} = make_int($ini->val('marker', 'font', 1));

  $config->{'marker'}->{'font_face'}->{'comment'} = <<COMMENT
Font face file name to use for labeling markers (overrides 'font' setting)
TYPE: font
COMMENT
  ;
  $config->{'marker'}->{'font_face'}->{'value'} = trim($ini->val('marker', 'font_face', 'vera/Vera.ttf'));

  $config->{'marker'}->{'font_size'}->{'comment'} = <<COMMENT
Font size in points, used only in conjunction with font_face
TYPE: integer
COMMENT
  ;
  $config->{'marker'}->{'font_size'}->{'value'} = make_int($ini->val('marker', 'font_size', 6));

  $config->{'marker'}->{'label_offset'}->{'comment'} = <<COMMENT
Start label this far from the right of the marker (negative value=left)
TYPE: integer
COMMENT
  ;
  $config->{'marker'}->{'label_offset'}->{'value'} = make_int($ini->val('marker', 'label_offset', 8));

  $config->{'marker'}->{'label_color'}->{'comment'} = <<COMMENT
Color to use for labels
TYPE: color|DEFAULT: black
COMMENT
  ;
  $config->{'marker'}->{'label_color'}->{'value'} = trim($ini->val('marker', 'label_color', 'gray0'));


  # The [measure] section
  
  $config->{'measure'}->{'comment'} = <<COMMENT
#################
Measures are heat or histogram values with start and end coordinates in GFF.
Value is indicated by score (6th) column in GFF or in value= attribute in 9th 
  column of GFF.
If value_type = score_col, the value is assumed to be an e-value or p-value,
  which will need modification because of the non-linear distribution
COMMENT
  ;
  $config->{'measure'}->{'value_type'}->{'comment'} = <<COMMENT
Measure value is in either the score column (6th) of the GFF file or a 
  value= attribute in the 9th column.
TYPE: enum|VALUES: score_col,value_attr
COMMENT
  ;
  $config->{'measure'}->{'value_type'}->{'value'} = trim($ini->val('measure', 'value_type', 'score_col'));

  $config->{'measure'}->{'min'}->{'comment'} = <<COMMENT
Minimum value; will be overridden if actual minimum value is less
TYPE: integer|DEFAULT: 0
COMMENT
  ;
  $config->{'measure'}->{'min'}->{'value'} = make_int($ini->val('measure', 'min', 0));

  $config->{'measure'}->{'max'}->{'comment'} = <<COMMENT
Maximum value; will be overridden if actual maximum value is greater
TYPE: integer|DEFAULT: 0
COMMENT
  ;
  $config->{'measure'}->{'max'}->{'value'} = make_int($ini->val('measure', 'max', 0));

  $config->{'measure'}->{'display'}->{'comment'} = <<COMMENT
How to display the measurement for each record
TYPE: enum|VALUES: histogram,heat,distance|DEFAULT: heat
COMMENT
  ;
  $config->{'measure'}->{'display'}->{'value'} = trim($ini->val('measure', 'display', 'heat'));

  $config->{'measure'}->{'draw_as'}->{'comment'} = <<COMMENT
How to interpret the measure glyph (heatmap and distance only)
TYPE: enum|VALUES: range,position,border,marker|DEFAULT: range
COMMENT
  ;
  $config->{'measure'}->{'draw_as'}->{'value'} = trim($ini->val('measure', 'draw_as', 'range'));

  $config->{'measure'}->{'shape'}->{'comment'} = <<COMMENT
Heatmap and distance only: shape (don't use 'circle' if measure has meaningful length)
TYPE: enum|VALUES: circle,rect|DEFAULT: rect
COMMENT
  ;
  $config->{'measure'}->{'shape'}->{'value'} = trim($ini->val('measure', 'rect', 'rect'));

  $config->{'measure'}->{'width'}->{'comment'} = <<COMMENT
Heatmap and distance only: width of rect or circle
TYPE: integer|DEFAULT: 2
COMMENT
  ;
  $config->{'measure'}->{'width'}->{'value'} = make_int($ini->val('measure', 'width', 2));

  $config->{'measure'}->{'enable_pileup'}->{'comment'} = <<COMMENT
Heatmap and distance only: whether or not to "pileup" overlaping glyphs
TYPE: boolean|DEFAULT: 1
COMMENT
  ;
  $config->{'measure'}->{'enable_pileup'}->{'value'} = make_int($ini->val('measure', 'enable_pileip', 1));

  $config->{'measure'}->{'pileup_gap'}->{'comment'} = <<COMMENT
Heatmap and distance only: space between adjacent, piled-up ranges
TYPE: integer|DEFAULT: 0
COMMENT
  ;
  $config->{'measure'}->{'pileup_gap'}->{'value'} = make_int($ini->val('measure', 'pileup_gap', 0));

  $config->{'measure'}->{'heat_colors'}->{'comment'} = <<COMMENT
Heatmap only: color sche to use for scale
TYPE: enum|VALUES: redgreen,grayscale|DEFAULT: redgreen
COMMENT
  ;
  $config->{'measure'}->{'heat_colors'}->{'value'} = trim($ini->val('measure', 'heat_colors', 'redgreen'));

  $config->{'measure'}->{'color'}->{'comment'} = <<COMMENT
Histogram only: color of measure glyph
TYPE: color|DEFAULT: red
COMMENT
  ;
  $config->{'measure'}->{'color'}->{'value'} = trim($ini->val('measure', 'color', 'red'));

  $config->{'measure'}->{'max_distance'}->{'comment'} = <<COMMENT
Distance only: max distance from chromosome
TYPE: integer|DEFAULT: 25
COMMENT
  ;
  $config->{'measure'}->{'max_distance'}->{'value'} = make_int($ini->val('measure', 'max_distance', 25));

  $config->{'measure'}->{'hist_perc'}->{'comment'} = <<COMMENT
Histograms only: percentage of gap between chromosomes to fill with max values
TYPE: float|DEFAULT: .9
COMMENT
  ;
  $config->{'measure'}->{'hist_perc'}->{'value'} = make_float($ini->val('measure', 'hist_perc', .9));

  $config->{'measure'}->{'transparent'}->{'comment'} = <<COMMENT
Whether or not to use transparency
TYPE: boolean|DEFAULT: 0
COMMENT
  ;
  $config->{'measure'}->{'transparent'}->{'value'} = make_int($ini->val('measure', 'transparent', 0));

  $config->{'measure'}->{'offset'}->{'comment'} = <<COMMENT
Distance from chromosome to draw shape
TYPE: integer
COMMENT
  ;
  $config->{'measure'}->{'offset'}->{'value'} = make_int($ini->val('measure', 'offset', 2));

  $config->{'measure'}->{'draw_label'}->{'comment'} = <<COMMENT
1=draw marker labels, 0=don't
TYPE: boolean|DEFAULT: 0
COMMENT
  ;
  $config->{'measure'}->{'draw_label'}->{'value'} = make_int($ini->val('measure', 'draw_label', 0));

  $config->{'measure'}->{'fill'}->{'comment'} = <<COMMENT
1 = fill in borders, 0 = don't
TYPE: boolean|DEFAULT: 1
COMMENT
  ;
  $config->{'measure'}->{'fill'}->{'value'} = make_int($ini->val('measure', 'fill', 1));

  $config->{'measure'}->{'font'}->{'comment'} = <<COMMENT
Built-in font to use for labeling markers (font_face overrides this setting)
  0=gdLargeFont, 1=gdMediumBoldFont, 2=gdSmallFont, 3=gdTinyFont
TYPE: enum|VALUES: 0,1,2,3|DEFAULT: 1
COMMENT
  ;
  $config->{'measure'}->{'font'}->{'value'} = make_int($ini->val('measure', 'font', 1));

  $config->{'measure'}->{'font_face'}->{'comment'} = <<COMMENT
Font face file name to use for labeling measures (overrides 'font' setting)
TYPE: font
COMMENT
  ;
  $config->{'measure'}->{'font_face'}->{'value'} = trim($ini->val('measure', 'font_face', 'vera/Vera.ttf'));

  $config->{'measure'}->{'font_size'}->{'comment'} = <<COMMENT
Font size in points, used only in conjunction with font_face
TYPE: integer
COMMENT
  ;
  $config->{'measure'}->{'font_size'}->{'value'} = make_int($ini->val('measure', 'font_size', 6));

  $config->{'measure'}->{'label_offset'}->{'comment'} = <<COMMENT
Start labels this many pixels right of region bar (negative value to move
  label to the left)
TYPE: integer
COMMENT
  ;
  $config->{'measure'}->{'label_offset'}->{'value'} = make_int($ini->val('measure', 'label_offset', 5));

  $config->{'measure'}->{'label_color'}->{'comment'} = <<COMMENT
Color to use for labels
TYPE: color|DEFAULT: black
COMMENT
  ;
  $config->{'measure'}->{'label_color'}->{'value'} = trim($ini->val('measure', 'label_color', 'black'));
  
  # Get custom types
  my %custom_types = $self->get_custom_options();
  $self->{custom_types} = \%custom_types;
}#initValues


##############
# AddSection()

sub AddSection {
  my ($self, $section) = @_;
  if (!$self->{config}->{$section}) {
    $self->{config}->{$section} = {};
  }
}#AddSection


########################
# get_custom_options()

sub get_custom_options {
  my $self = $_[0];
  
  my %custom_types;
  foreach my $section ($self->Sections()) {
    if ($self->val($section, 'feature')) {
      my $feature_name = $self->val($section, 'feature');
      $custom_types{$feature_name} = $section;
    }
  }#each section
  
  return %custom_types;
}#get_custom_options


########################
# get_drawing_options()

sub get_drawing_options {
  my ($self, $glyph) = @_;
  
  my %opts;
  
  # Get default opts:  
  my $ini = $self->{ini};

  $opts{'color_name'}        = $self->val($glyph, 'color');
  $opts{'border_color_name'} = $self->val($glyph, 'border_color');
  $opts{'width'}             = $self->val($glyph, 'width');
  $opts{'fill'}              = $self->val($glyph, 'fill');
  $opts{'transparent'}       = $self->val($glyph, 'transparent');
  $opts{'shape'}             = $self->val($glyph, 'shape');
  $opts{'offset'}            = $self->val($glyph, 'offset');
  $opts{'enable_pileup'}     = $self->val($glyph, 'enable_pileup');
  $opts{'pileup_gap'}        = $self->val($glyph, 'pileup_gap');
  $opts{'draw_label'}        = $self->val($glyph, 'draw_label');
  $opts{'font'}              = $self->val($glyph, 'font');
  $opts{'font_face'}         = $self->val($glyph, 'font_face');
  $opts{'font_size'}         = $self->val($glyph, 'font_size');
  $opts{'label_offset'}      = $self->val($glyph, 'label_offset');
  $opts{'label_color'}       = $self->val($glyph, 'label_color');

  if ($glyph eq 'measure') {
    $opts{'min'}             = $self->val('measure', 'min');
    $opts{'max'}             = $self->val('measure', 'max');
    $opts{'display'}         = $self->val('measure', 'display');
    $opts{'draw_as'}         = $self->val('measure', 'draw_as');
    $opts{'heat_colors'}     = $self->val('measure', 'heat_colors');
    $opts{'value_type'}      = $self->val('measure', 'value_type');
    $opts{'max_distance'}    = $self->val('measure', 'max_distance');
    $opts{'hist_perc'}       = $self->val('measure', 'hist_perc');
  }#measure glyph
  
  # Each class will have a different color. 
  $opts{'class_colors'} = $self->{config}->{'general'}{'class_colors'}->{'value'};

  # Class colors for specific named classes may be defined in ini file.
  my %classes;
  my @class_assignments = $ini->Parameters('classes');
  foreach my $class (@class_assignments) {
    $classes{$class} = $ini->val('classes', $class);
  }
  
  $opts{'classes'} = {%classes};

  return %opts;
}#get_drawing_options


#################################
# get_drawing_options_overrides()

sub get_drawing_options_overrides {
  my ($self, $glyph, $source, $type, $def_optref) = @_;
  
  my %opts = %$def_optref;
  my $ini = $self->{ini};
  
  # Check for custom overrides.
  my $section;
  my $custom_types = $self->{custom_types};
  if (defined $custom_types->{"$source:$type"}) {
     $section = $custom_types->{"$source:$type"};

     # check for overrides in custom section
     $opts{'color_name'}   
        = trim($ini->val($section, 'color',        $opts{'color_name'}));
     $opts{'border_color_name'} 
        = trim($ini->val($section, 'border_color', $opts{'border_color_name'}));
     $opts{'width'}        
        = make_int($ini->val($section,  'width',        $opts{'width'}));
     $opts{'fill'}         
        = make_int($ini->val($section,  'fill',         $opts{'fill'}));
     $opts{'transparent'}  
        = make_int($ini->val($section,  'transparent',  $opts{'transparent'}));
     $opts{'shape'}        
        = trim($ini->val($section, 'shape',        $opts{'shape'}));
     $opts{'offset'}       
        = make_int($ini->val($section,  'offset',       $opts{'offset'}));
     $opts{'enable_pileup'}
        = make_int($ini->val($section,  'enable_pileup',$opts{'enable_pileup'}));
     $opts{'pileup_gap'}   
        = make_int($ini->val($section,  'pileup_gap',   $opts{'pileup_gap'}));
     $opts{'draw_label'}   
        = make_int($ini->val($section,  'draw_label',   $opts{'draw_label'}));
     $opts{'font'}         
        = make_int($ini->val($section,  'font',         $opts{'font'}));
     $opts{'font_face'}    
        = trim($ini->val($section, 'font_face',    $opts{'font_face'}));
     $opts{'font_size'}    
        = make_int($ini->val($section,  'font_size',    $opts{'font_size'}));
     $opts{'label_offset'} 
        = make_int($ini->val($section,  'label_offset', $opts{'label_offset'}));
     $opts{'label_color'}  
        = trim($ini->val($section, 'label_color',  $opts{'label_color'}));

     # measures only
     $opts{'value_type'}  
        = trim($ini->val($section, 'value_type',  $opts{'value_type'}));
     $opts{'min'}  
        = make_float($ini->val($section,'min',         $opts{'min'}));
     $opts{'max'}  
        = make_float($ini->val($section,'max',         $opts{'max'}));
     $opts{'display'}  
        = trim($ini->val($section, 'display',     $opts{'display'}));
     $opts{'draw_as'}  
        = trim($ini->val($section, 'draw_as',     $opts{'draw_as'}));
     $opts{'heat_colors'}  
        = trim($ini->val($section, 'heat_colors', $opts{'heat_colors'}));
     $opts{'max_distance'}  
        = make_int($ini->val($section,  'max_distance',$opts{'max_distance'}));
     $opts{'hist_perc'}  
        = make_float($ini->val($section,'hist_perc',   $opts{'hist_perc'}));
  }#not a measure glyph

  return %opts;
}#get_drawing_options_overrides


##########
# newval()

sub newval {
  my ($self, $section, $parameter, $value) = @_;
  $self->{$section}->{$parameter} = {};
  $self->{$section}->{$parameter}->{'value'} = $value;
}#newval


##############
# Parameters()

sub Parameters {
  my ($self, $section) = @_;
  return keys %{$self->{config}->{$section}};
}#Parameters


########################
# save_drawing_options()

sub save_drawing_options {
  my ($self, $glyph, $optref) = @_;
  
  my $ini = $self->{ini};
  
  # save these drawing attributes in a temp ini section (in memory only)
  if (!$ini->SectionExists('PresentGlyph')) {
    $ini->AddSection('PresentGlyph'); 
  }
  $ini->newval('PresentGlyph', 'color',         $optref->{'color_name'});
  $ini->newval('PresentGlyph', 'border_color',  $optref->{'border_color_name'});
  $ini->newval('PresentGlyph', 'width',         $optref->{'width'});
  $ini->newval('PresentGlyph', 'fill',          $optref->{'fill'});
  $ini->newval('PresentGlyph', 'transparent',   $optref->{'transparent'});
  $ini->newval('PresentGlyph', 'shape',         $optref->{'shape'});
  $ini->newval('PresentGlyph', 'offset',        $optref->{'offset'});
  $ini->newval('PresentGlyph', 'enable_pileup', $optref->{'enable_pileup'});
  $ini->newval('PresentGlyph', 'pileup_gap',    $optref->{'pileup_gap'});
  $ini->newval('PresentGlyph', 'draw_label',    $optref->{'draw_label'});
  $ini->newval('PresentGlyph', 'font',          $optref->{'font'});
  $ini->newval('PresentGlyph', 'font_face',     $optref->{'font_face'});
  $ini->newval('PresentGlyph', 'font_size',     $optref->{'font_size'});
  $ini->newval('PresentGlyph', 'label_offset',  $optref->{'label_offset'});
  $ini->newval('PresentGlyph', 'label_color',   $optref->{'label_color'});
  if ($glyph eq 'measure') {
    $ini->newval('PresentGlyph', 'display',     $optref->{'display'});
    $ini->newval('PresentGlyph', 'draw_as',     $optref->{'draw_as'});
    $ini->newval('PresentGlyph', 'value_type',  $optref->{'value_type'});
    $ini->newval('PresentGlyph', 'min',         $optref->{'min'});
    $ini->newval('PresentGlyph', 'max',         $optref->{'max'});
    $ini->newval('PresentGlyph', 'max_distance',$optref->{'max_distance'});
    $ini->newval('PresentGlyph', 'hist_perc',   $optref->{'hist_perc'});
  }#measure
  
  $self->{ini} = $ini;
}#_save_drawing_options


############
# Sections()
#
# mimics Config::ini->Sections()

sub Sections {
  my $self = $_[0];
  # in memory
  my @sections = keys %{$self->{config}};

  # check in .ini file
  sub uniq {
    return keys %{{ map { $_ => 1 } @_ }};
  }
  push @sections, $self->{ini}->Sections();
  @sections = uniq(@sections);

  return @sections;
}#Sections


##########
# setval()
#
# mimics Config::ini->setval()

sub setval {
  my ($self, $section, $parameter, $value) = @_;
  $self->{config}->{$section}->{$parameter}->{'value'} = $value;
}#set


#######
# val()
#
# mimics Config::ini->val()

sub val {
  my ($self, $section, $parameter, $default) = @_;

  if (defined $self->{config}->{$section}->{$parameter}) {
    if (!$self->{config}->{$section}->{$parameter}->{'value'}) {
      return $self->_get_null_for_type($parameter);
    }
    else {
      return trim($self->{config}->{$section}->{$parameter}->{'value'});
    }
  }
  elsif (defined $default 
          && !(defined $self->{ini}->val($section, $parameter))) {
    $self->{config}->{$section}->{$parameter}->{'value'} = $default;
    return $default;
  }
  elsif (defined $self->{ini}->val($section, $parameter)) {
    my $val = trim($self->{ini}->val($section, $parameter));
    if (!$val) {
      return $self->_get_null_for_type($parameter);
    }
    else {
      return $val;
    }
  }
  else {
    return '';
  }
}#val


#################
# writeIniFile()

# Consider losing this. Config::IniFiles::WriteConfig doesn't preserve order of or within 
#   sections, comments appear more or less randomly

sub writeIniFile {
  my ($self, $filename) = @_;
  
#TODO: set ini from {config} before writing out
  my $new_ini = new Config::IniFiles();
  
  my $cfg = $self->{config};  # shorthand
  foreach my $section (keys %{$cfg}) {
    next if ($section eq 'types');
    $new_ini->AddSection($section);
    $new_ini->SetSectionComment($section, $cfg->{$section}->{'comment'});
    foreach my $param (keys %{$cfg->{$section}}) {
      $new_ini->newval($section, $param, $cfg->{$section}->{$param});
    }
  }

  $new_ini->WriteConfig($filename);
}#writeIniFile


##########################################################################################
###############################   internal functions  ####################################

######################
# _get_null_for_type()

sub _get_null_for_type {
  my ($self, $parameter) = @_;
  my $type = $self->{config}->{types}{$parameter};
  if (defined $type) {
    if ($type eq 'integer') {
      return '0E0';
    }
    elsif ($type eq 'float') {
      return '0.0';
    }
    elsif ($type eq 'boolean') {
      return 0;
    }
    elsif ($type eq 'array') {
      return [];
    }
    else {
      return '';
    }
  }
  else {
    return '';
  }
}#_get_null_for_type


1;  # so that the require or use succeeds