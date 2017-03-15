#!/usr/bin/perl

# File: FontManager.pm
# Author: Ethalinda Cannon (ethy@a415software.com) 
#
# Use: Manage fonts for CViT.
#
# Documentation:
#   File::Spec     - http://perldoc.perl.org/File/Spec.html
#   File::Basename - http://perldoc.perl.org/File/Basename.html
#   GD             - http://search.cpan.org/dist/GD/GD.pm
#   Data::Dumper   - http://search.cpan.org/~smueller/Data-Dumper-2.128/Dumper.pm

package FontManager;

use strict;
use warnings;
use File::Spec;
use File::Basename;
use CvitLib;
use Data::Dumper;

use FindBin '$Bin';


#######
# new()

sub new {
  my ($self, $image_format) = @_;
  
  $self = {};
  
  # Load image library
  if ($image_format eq 'png') {
    use GD;
    use GD::Text;
  }
  else {
    use GD::SVG;
    # Can't measure text dimensions; will have to guess
  }
  $self->{'image_format'} = $image_format;

  # create fonts
  my ($gdLargeFont, $gdMediumBoldFont, $gdSmallFont, $gdTinyFont);
  if ($image_format eq 'svg') {
    $gdLargeFont      = gdLargeFont;
    $gdMediumBoldFont = gdMediumBoldFont;
    $gdSmallFont      = gdSmallFont;
    $gdTinyFont       = gdTinyFont;
  }
  else {
    $gdLargeFont      = GD::gdLargeFont;
    $gdMediumBoldFont = GD::gdMediumBoldFont;
    $gdSmallFont      = GD::gdSmallFont;
    $gdTinyFont       = GD::gdTinyFont;
  }
  my @fonts = ($gdLargeFont, $gdMediumBoldFont, $gdSmallFont, $gdTinyFont);
  $self->{fonts} = [@fonts];
  $self->{fontsdir} = File::Spec->catdir($Bin, 'fonts');

  # to keep track of ttf fonts
  my %ttfs;
  
  bless($self);
  return $self;
}#new


#############
# find_font_face()

sub find_font_face {
  my ($self, $font_face) = @_;

#TODO: fix this
  # Printing with TTFs isn't working with GD::SVG
  if ($self->{image_format} eq 'svg') {
    return '';
  }
  
  # trim leading and trailing whitespace
 	$font_face = trim($font_face);

  # Has this font already been found?
  if ($self->{ttfs}{$font_face}) {
    return $self->{ttfs}{$font_face};
  }
  
  my $fontsdir = $self->{fontsdir};
  my $fontfile = File::Spec->catfile($fontsdir, $font_face);
  if (-e $fontfile) {
    $self->{ttfs}{$font_face} = $fontfile;
    return $fontfile;
  }
  
  elsif (-e $font_face) {
    $self->{ttfs}{$font_face} = $font_face;
    return $font_face;
  }
  
  else {
    $font_face = basename($font_face);
    if (opendir(DIR, $fontsdir)) {
      my @dirs = readdir(DIR);
      foreach my $dir (@dirs) {
        my $subdir = File::Spec->catdir($fontsdir, $dir);
        if (-d $subdir) {
          opendir(SUBDIR, $subdir);
          my @files = grep(/^$font_face$/, readdir(SUBDIR));
          if (scalar @files > 0) {
            $fontfile = File::Spec->catfile($subdir, $font_face);
            $self->{ttfs}{$font_face} = $fontfile;
            return $fontfile;
          }
          closedir(SUBDIR);
        }
      }
      closedir(DIR);
    }
  }

  # If we get here we failed
  print "WARNING: Unable to find font file $font_face\n";
  return '';
}#find_font_face


############
# get_font()

sub get_font {
  my ($self, $font_num) = @_;
  my $fonts_ref = $self->{fonts};
  
  if (!$font_num) {
    print "\nWarning: missing font number. Will default to font # 1\n\n";
    $font_num = 1;
  }
  if ($font_num < 1 || $font_num > scalar @$fonts_ref) {
    print "\nWarning: invalid font number: $font_num. ";
    print "The font number must be between 1 and " . scalar @$fonts_ref . ". ";
    print "Will default to font # 1\n\n";
    $font_num = 1;
  }
  
  if ($font_num < scalar @$fonts_ref) {
    return $fonts_ref->[$font_num];
  }
  else {
    return $fonts_ref->[0];
  }
}#get_font


###################
# get_font_height()

sub get_font_height {
  my ($self, $font_num) = @_;
  if ($font_num == 0) {
    return 16;
  }
  elsif ($font_num == 1) {
    return 14;
  }
  elsif ($font_num == 2) {
    return 13;
  }
  elsif ($font_num == 3) {
    return 8;
  }
}#get_font_height


##################
# get_font_width()

sub get_font_width {
  my ($self, $font_num) = @_;
  if ($font_num == 0) {
    return 8;
  }
  elsif ($font_num == 1) {
    return 7;
  }
  elsif ($font_num == 2) {
    return 6;
  }
  elsif ($font_num == 3) {
    return 5;
  }
}#get_font_width


######################
# get_text_dimension()

sub get_text_dimension {
  my ($self, $font, $font_face, $font_size, $string) = @_;

  my $gd_text = GD::Text->new(text => $string);
  if (defined $font_face && $font_face ne '' && $font_size > 0) {
    my $font_file = File::Spec->catfile($self->{fontsdir}, $font_face);
    $gd_text->set_font($font_file, $font_size);
  }
  else {
    $gd_text->set_font($font);
  }
  my $str_width = $gd_text->get('width');
  my $str_height = $gd_text->get('height');

  return ($str_width, $str_height);
}# get_text_dimension


###############
# useTrueType()

sub useTrueType {
  my ($self, $opts) = @_;
  
  my $use_ttf = 0;
  if ($opts->{'font_face'} && $opts->{'font_face'} ne '' && $opts->{'font_size'} ne '') {
    $use_ttf = 1;
    my $font_face = $self->find_font_face($opts->{'font_face'});
    if ($font_face eq '') {
      # Can't find font face so fall back to default font
      $use_ttf = 0;
    }
  }
  
  return $use_ttf;
}#useTrueType

1;  # so that the require or use succeeds