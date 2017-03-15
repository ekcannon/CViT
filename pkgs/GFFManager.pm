#!/usr/bin/perl

# File: GFFManager.pm
# Authors: Ethalinda Cannon (ethy@a415software.com), Steven Cannon (scannon@iastate.edu)

# Use: Read and manipulate GFF files and records.

# read_gff()
# get_attributes()
# get_record_hash()
# sortGFF()

package GFFManager;
use strict;
use warnings;

use Data::Dumper;      # for debugging

#######
# new()

sub new {
  my ($self, $ini, $dbg) = @_;
  
  $self  = {};
  
  # Config
  $self->{ini} = $ini;
  
  # For debugging
  $self->{dbg} = $dbg;
  
  bless($self);
  return $self;
}#new


sub read_gff {
  my ($self, $GFF, $filename) = @_;
  
  my $dbg = $self->{dbg};
  my $ini = $self->{ini};
  my $reverse_ruler = $ini->val('general', 'reverse_ruler', 0);
  
#TODO: candidate job for config object
  # Get custom types
  my %custom_types;
  foreach my $section ($ini->Sections()) {
    if ($ini->val($section, 'feature')) {
      my $feature_name = $ini->val($section, 'feature');
      $custom_types{$feature_name} = $section;
    }
  }#each section

  my $error;
  open GFF, "<$filename" or $error = "\nUnable to open $filename because: $!\n)";
  if ($error) {
    $dbg->reportError("$error");
    $error = "";
  }
  
  else {
    my $marker_count = 0;
    my $line_count   = 0;
    
    while (<GFF>) {
      $line_count++;
      chomp;chomp; # get rid of line ending
      s/\s+$//;
      
      # The ##FASTA directive indicates the remainder of the file contains
      #   fasta data, per the GFF3 specification
      last if (/^>/ or /##FASTA/); # finished if we've reached fasta data
      
      next if (/^#/);              # skip comment lines 
      next if ((length) == 0);     # skip blank lines
      my $line = $_;

      # NOTE: GFF3 specification does not allow use of spaces to separate 
      #   columns, but CViT does.
      my @record = split /\s+/, $line, 9; # permit more than one space char
      
      # do a spot of error checking and reporting
      if ( (scalar @record) != 9) {
        # make sure this isn't really just a blank record
        $line =~ s/\s//g;
        next if ((length $line) == 0);
        my $msg = "Incorrect number of fields in file $filename, "
                . "record $line_count [$_]\n    " 
                . scalar @record . " fields found, 9 expected.";
        $dbg->reportError($msg);
        print "$msg\n";
        next;
      }
      
      my ($seqname, $source, $type, $start, $end, $score, $strand, $frame, 
          $attributes) = @record;

      if (lc($type) eq 'chromosome') {        # defines a chromosome
         push @{$GFF->{'chromosome'}}, [@record];
      }
      elsif (lc($type) eq 'border') {         # defines a border
         push @{$GFF->{'border'}}, [@record];
      }
      elsif (lc($type) eq 'centromere') {     # defines a centromere
         push @{$GFF->{'centromere'}}, [@record];
      }
      elsif (lc($type) eq 'marker') {      # defines a marker location
         push @{$GFF->{'marker'}}, [@record];
      }
      elsif (lc($type) eq 'measure') {     # defines a measure of importance
         push @{$GFF->{'measure'}}, [@record];
      }
      elsif (defined $custom_types{"$source:$type"}) {
         my $section = $custom_types{"$source:$type"};
         my $glyph = $ini->val($section, 'glyph');
         eval "push \@{\$GFF->{'" . $glyph . "'}}, [\@record]";
      }
      elsif ($start == $end) {             # assume a generic position
         push @{$GFF->{'position'}}, [@record];
      }
      else {                               # assume a generic range
         push @{$GFF->{'range'}}, [@record];
      }

    }#each line
    close(GFF);
  }#GFF file exists
}#read_gff


sub get_attributes {
   my ($self, $attr_str) = @_;
   my @attribute_list = split /;\s*/, $attr_str;
   return map { lc($self->_attr_key($_)) => $self->_attr_val($_) } @attribute_list;
}#get_attributes
sub _attr_key {
  my ($self, $keystr) = @_;
  my @parts = split(/=/, $keystr, 2);
  return $parts[0];
}
sub _attr_val {
  my ($self, $valstr) = @_;
  my @parts = split(/=/, $valstr, 2);
  return $parts[1];
}

sub get_name {
   my ($self, $attributes) = @_;
   if ($attributes->{'name'}) {
      return $attributes->{'name'};
   }
   elsif ($attributes->{'id'}) {
      return $attributes->{'id'};
   }
   elsif ($attributes->{'clone'}) {
      return $attributes->{'clone'};
   }
   else {
      return '';
   }
}#get_name


sub get_record_hash {
  my ($self, $record) = @_;

  my %record_hash;
  $record_hash{'chromosome'} = lc($record->[0]);
  $record_hash{'source'}     = $record->[1];
  $record_hash{'type'}       = $record->[2];
  $record_hash{'start'}      = $record->[3];
  $record_hash{'end'}        = $record->[4];
  $record_hash{'score'}      = $record->[5];
  $record_hash{'strand'}     = $record->[6];
  $record_hash{'frame'}      = $record->[7];
  $record_hash{'attrstr'}    = $record->[8];
  $record_hash{'attrs'}      = {$self->get_attributes($record->[8])};
  
  return %record_hash;
}#get_record_hash


sub sortGFF {
  my ($self, $GFF, $ruler_max) = @_;
  
  my $reverse_ruler = $self->{ini}->val('general', 'reverse_ruler', 0);
  
  foreach my $glyph (keys %$GFF) {
    next if ($glyph eq 'chromosome'); # don't sort chromosome; file order matters
    
    my $GFF_ref = $GFF->{$glyph};
    next if (scalar @$GFF_ref == 0);
    
    my @GFF_recs;
    
    # Check if ruler will run backwards (e.g. north arm of cytogenetic chromosome)
    if ($reverse_ruler == 1) {
      @GFF_recs = reverse_coords($ruler_max, $GFF_ref);
    }
    else {
      @GFF_recs = @$GFF_ref;
    }

    # order records by chromosome and start position
    my @unsorted = @GFF_recs;
    @GFF_recs = sort {
                   if ($a->[0] gt $b->[0]) { return 1; }
                   elsif ($a->[0] lt $b->[0]) { return -1; }
                   else {
                     if ($a->[3] > $b->[3]) { return 1; }
                     elsif ($a->[3] < $b->[3]) { return -1; }
                     else { return 0; }
                   }
                 } @unsorted;
    $GFF->{$glyph} = \@GFF_recs;
  }#each GFF set
}#sortGFF

1;  # so that the require or use succeeds