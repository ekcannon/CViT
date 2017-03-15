#!/usr/bin/perl

# File: errorlog.pm
# Author: Ethalinda Cannon (ethy@a415software.com) 

# Use: report messages and errors to a log file

# new()
# startLogging()
# stopLogging()
# createLog()
# logMessage()
# reportError()
# getError()
# setError()

package ErrorLog;
use strict;
use warnings;
use Time::Local;
use File::Copy;
 
# General Purpose Error Logging Module
 
##################################################
## the object constructor (simplistic version)  ##
##################################################
sub new {
   my $self  = {};
   $self->{log_errors}  = undef;
   $self->{log_file}    = undef;
   $self->{loghandle}   = undef;
   $self->{error_file}  = undef;
   $self->{errorhandle} = undef;
   $self->{std_out}     = undef;
   $self->{browser_out} = undef;
   $self->{file_out}    = undef;
   $self->{backupage}   = 1;
   $self->{maxageinseconds} = 604800;
   
   # a place to store errors for later display 
   #   (e.g. to add information to identify record containing the error)
   $self->{error} = undef;
   
   bless($self);
   return $self;
}

sub startLogging {
  my $self = shift;
  $self->{log_errors} = 1;
}

sub stopLogging {
  my $self = shift;
  $self->{log_errors} = 0;
}

sub createLog {
  # get parameters
  my $self = shift;
  my $enable = $_[0];
  my $logfile = $_[1];
  my $errorfile = $_[2];
  my $outputtypes = $_[3];
  
  # init error log values
  $self->{log_errors} = $enable;
  $self->{log_file} = $logfile;
  $self->{error_file} = $errorfile;
  if ($outputtypes =~ /s/) { $self->{std_out} = 1; } else {$self->{std_out} = 0; }
  if ($outputtypes =~ /b/) { $self->{browser_out} = 1; } else {$self->{browser_out} = 0; }
  if ($outputtypes =~ /f/) { $self->{file_out} = 1; } else {$self->{file_out} = 0; }

  my $error;
  
  # does log already exist?
  my $exists = 0;
  if ( (-e $logfile) ) { $exists = 1; }
    
  # if using a log file, open/create it and write out the time
  if ($self->{file_out} == 1 && $enable == 1) {
  # get the current time
  my ($sec, $min, $hours, $mday, $month, $year) = localtime;
  # open/create log file and print the date and time
  open $self->{loghandle}, ">>$logfile" or $error = "couldn't open $logfile: $!";
    if ($error && length($error) > 0) {
      # can't use log file; shut it down to prevent error messages
      $self->{file_out} = 0;
    } else {
      my $fh = $self->{loghandle};
      if ($exists) {
        print $fh "\n\n$mday-".($month+1)."-".($year+1900)." $hours:$min:$sec\n";
      } else {
        # timestamp should be the first line of a new logfile.
        print $fh "$mday-".($month+1)."-".($year+1900)." $hours:$min:$sec\n";
      }
    }
  }
  if ($self->{browser_out} == 1) {
    print "Content-Type: text/html\n\n";
  }
}

sub logMessage {
  my $self = shift;
  if ($self->{log_errors} == 1) {
    my ($sec, $min, $hrs, $day, $mon, $yr) = localtime;
    my $message = "$day " . ($mon+1) . " " . (1900+$yr) . " $hrs:$min:$sec: ";
    $message .= $_[0] . "\n";
    my $logfile = $self->{log_file};
    if ($self->{file_out} == 1) {
      my $fh = $self->{loghandle};
      print $fh $message;
    }
    if ($self->{browser_out} == 1) {
      $message =~ s/\n/<br>/g;
      print $message;
    }
    if ($self->{std_out} == 1) {
      print $message;
    }
  }
}

sub reportError {
  my $self = shift;
  my $message = $_[0];

  if (!$self->{errorhandle}) {
    # get the current time
    my ($sec, $min, $hours, $mday, $month, $year) = localtime;
    # open/create error log file and print the date and time
    my $error;
    open $self->{errorhandle}, ">>$self->{error_file}" 
          or $error = "couldn't open $self->{error_file}: $!";
    my $fh = $self->{errorhandle};
    print $fh "\n\n$mday-".($month+1)."-".($year+1900)." $hours:$min:$sec\n";
  }
  
  my $fh = $self->{errorhandle};
  print $fh "ERROR: $message\n";
}


sub clear_error {
  my $self = $_[0];
  undef $self->{error};
}#clear_error


sub get_error {
  my $self = $_[0];
  if (defined $self->{error}) {
    return $self->{error};
  }
  else {
    return undef;
  }
}#get_error


sub handle_error {
  my ($self, $info, $echo) = @_;
  if (defined $self->{error}) {
    $self->reportError($self->{error});
    if ($echo) {
      print "  ERROR: $info: " . $self->{error} . "\n";
    }
    $self->clear_error;
  }
}#handle_error


sub set_error {
  my ($self, $msg) = @_;
  $self->{error} = $msg;
}#set_error


1;  # so that the require or use succeeds