#!/usr/bin/perl

# File: ColorManager.pm
# Author: Ethalinda Cannon (ethy@a415software.com) 

# Use: Manages color arrays and function for CViT

package ColorManager;
use strict;
use warnings;
use CvitLib;

use Data::Dumper;  # for debugging

#######
# new()
# Create a new ColorManager with empty arrays and hashes

sub new {
  my ($self, $image_format, $colorfile) = @_;
  
  $self = {};
  
  # Load image library
  if ($image_format eq 'png') {
    use GD;
  }
  else {
    use GD::SVG;
  }
  $self->{'image_format'} = $image_format;

  $self->{colorfile} = $colorfile;
  $self->{colors} = {};
  $self->{color_codes} = {};
  $self->{heat_colors} = [];
  
  bless $self;
  return $self;
}

#################
# assign_colors()
# Create colors corresponding to the standard colors available for X11.

sub assign_colors {
  my ($self, $im) = @_;

  my (%colors, %color_codes);
  # order matters; start with these two:
  $colors{'white'} = $im->colorAllocate(255, 255, 255);
  $colors{'black'} = $im->colorAllocate(0, 0, 0);
  
  my $colorfile = $self->{colorfile};
  open COLORS, "<$colorfile" or die "\nUnable to open color file rgb.txt";
  while (<COLORS>) {
    next if (/^!/); # skip comment line(s)
    
    chomp;
    $_ =~ /(\d+)\s+(\d+)\s+(\d+)\s+(\w+)/;
    my $red   = $1;
    my $green = $2;
    my $blue  = $3;
    my $name  = lc($4);
    $color_codes{$name} = [$red, $green, $blue];
  }#all lines in color file
  close COLORS;
  
  $self->{colors} = \%colors;
  $self->{color_codes} = \%color_codes;
}#assign_colors


################
# clear_colors()

sub clear_colors {
  my $self = $_[0];
  
  # start over with new color arrays
  $self->{colors} = {};
  $self->{heat_colors} = [];
}#clear_colors


######################
# create_heat_colors()

sub create_heat_colors {
  my ($self, $heat_color_type, $im) = @_;
  
  my @heat_colors;
  
  if ($heat_color_type eq 'grayscale') {
    # gray scale
    for (my $i=0; $i<180; $i+=10) {
      my $new_color = $im->colorAllocate($i, $i, $i);
      push @heat_colors, $new_color;
    }#for each gray color
  }#grayscale
  
  elsif ($heat_color_type eq 'redgreen') {
    # red-green
  
    my $index = 0;  # because loop counter runs backward
    for (my $i=170; $i>=0; $i--) {
      my ($red, $green);
    
      if ($i <= 85) {
        # creates red to yellow colors
        $red = 255;
        $green = (3 * $i);
      } 
      else {
        # creates yellow to green colors
        $red = (255 - (3 * ($i - 85)));
        $green = 255;
      }

      my $new_color = $im->colorAllocate($red, $green, 0);
      if ($new_color == -1) {
        $new_color = $im->colorClosest($red, $green, 0);
      }
      if ($new_color != -1) {
        $heat_colors[$index] = $new_color;
        $index++;
      }
    }#for each color
  }
  
  $self->{heat_colors} = [@heat_colors];
  
  return $im;
}#create_heat_colors


#############
# get_color()
# Return index for requested color name. If it doesn't exist, create it.

sub get_color {
  my ($self, $im, $name, $blend) = @_;
  
  if (!(defined $name) || !$name) {
    print "\nError: no color name was passed into function get_color().\n";
    print "This is a code bug. Please notify author.\n";
    &show_call_stack;
    print "\n\n";
  }
  
  $name = lc($name);

  my $colors = $self->{colors};
  my $color_codes = $self->{color_codes};
  if ($colors->{$name}) {
    return $colors->{$name};
  }
  else {
    if ($color_codes->{$name}) {
      my ($red, $green, $blue) = @{$color_codes->{$name}};
      
      my $new_color;
      if (!$blend || $blend == 0) {
         $new_color = $im->colorAllocate($red, $green, $blue);
      }
      else {
         $im->alphaBlending(1);
         # alpha: 0 (opaque) to 127 (transparent)
         $new_color = $im->colorAllocateAlpha($red, $green, $blue, 50);#100);
      }
      
      if ($new_color == -1) {
        $new_color = $im->colorClosest($red, $green, $blue);
      }
      if ($new_color != -1) {
        $colors->{$name} = $new_color;
        return $new_color;
      }
    }#color appears in table
  }#color doesn't already exist

  return $colors->{'black'}; # guaranteed to exist
}#get_color


###################
# num_heat_colors()

sub num_heat_colors {
  my $self = $_[0];
  my $array_ref = $self->{heat_colors};
  return scalar @$array_ref;
}#num_heat_colors



1;  # so that the require or use succeeds