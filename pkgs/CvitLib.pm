#!/usr/bin/perl

# File: CvitLib.pm
# Author: Ethalinda Cannon (ethy@a415software.com)

# Use: Common library of functions for CViT.

package CvitLib;
use strict;
use warnings;

use base 'Exporter';
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

package CvitLib;

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT      = (
                    qw(add_commas),
                    qw(convert_score_to_value), 
                    qw(get_value),
                    qw(make_float),
                    qw(make_int),
                    qw(trim),
                   );


##############
# add_commas() [to long numbers]

sub add_commas {
   my $input = shift;
   $input = reverse $input;
   $input =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
   return reverse $input;
}#add_commas


###########################
# convert_score_to_value()

sub convert_score_to_value {
  my ($score) = @_;

  # nothing can score better than this (flattens the steep end of the curve): 
  my $best = 1e-70;
  my $a = log($best)/log(10);
  my $value = ($score < $best) ? $best : $score;
  return (($a - log($value)) / $a);
}#convert_score_to_value


###############
# get_value()

sub get_value {
  my ($min, $max, $score, $attr_ref, $opts_ref, $dbg) = @_;

  my $value;
  if ($opts_ref->{'value_type'} eq 'score_col') {
    $value = convert_score_to_value($score);
    $value = $value - $min;
    # need to flip values around since 0 = best
    $value = ($max - $min) - $value;
  }
  elsif ($opts_ref->{'value_type'} eq 'value_attr') {
    if (!(defined($attr_ref->{'value'}))) {
      $dbg->set_error("No 'value=' given in attributes. Value will be set to 0.");
    }
    $value = ($attr_ref->{'value'}) ? $attr_ref->{'value'} : 0;
  }
  
  return $value;
}#get_value


##############
# make_float()

sub make_float {
  my $str = $_[0];
  $str = trim($str);
  if ($str && $str ne '') {
    return ($str =~ m/^\d*\.{0,1}\d*?$/) ? ($str*1) : 0;
  }
  else {
    return 0;
  }
}#make_float


############
# make_int()

sub make_int {
  my $str = $_[0];
  $str = trim($str);
  if ($str && $str ne '') {
    $str =~ s/[^\d-]//;
  }
  if ($str && $str ne '') {
    return ($str =~ m/^-*\d+$/) ? ($str*1) : 0;
  }
  else {
    return 0;
  }
}#make_int


##################
# show_call_stack

sub show_call_stack {
	my($path, $line, $subr);
	my $max_depth = 30;
	my $i = 1;
	print "\n--- Begin stack trace ---\n";
	while ( (my @call_details = (caller($i++))) && ($i<$max_depth) )
	{
		print "$call_details[1] line $call_details[2] in function $call_details[3]\n";
	}
	print "--- End stack trace ---\n\n";
}#show_call_stack


########
# trim
# trim whitespace off beginning and end of a string

sub trim {
  my $str = shift;
  return if (!$str);
  $str =~ s/^\s+//;
  $str =~ s/\s+$//;
  return $str;
}#trim



1;  # so that the require or use succeeds