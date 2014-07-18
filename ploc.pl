#!/usr/bin/perl

#
# This script counts number of lines in files of specified type.
# The counting is done recursively into subdirectory.
# @Usage: perl getLOC.pl [dir|file]
#    If no argument is provided, start from current dir ".".
# @By: XC
# @Created on: 11/29/2009
#

print "\n- Line Counter -\n\n";

# specify file type(s) here. Use "[]" to escape ".".
my @types = ("[.]c", "[.]h"); 
#my @types = ("[.]cs"); 
#my @types = ("[.]aspx");
#my @types = ("[.]bat");
#my @types = ("[.]sql");
#my @types = ("[.]asp");
#my @types = ("[.]*");
#my @types = ("[.]php");
#my @types = ("[.]cgi");
#my @types = ("[.]js");
#my @types = ("[.]css");
#my @types = ("[.]dll");
#my @types = ("[.]exe");
#my @types = ("[.]xml");
#my @types = ("[.]pm");
#my @types = ("[.]wsdl");
#my @types = ("[.]vbs");
#my @types = ("[.]bat");

my $dirname = ".";
my $total_loc = 0;

# Get input directory name.
my $argc = $#ARGV + 1;
if ($argc > 0) {
  $dirname = $ARGV[0];
}

# Process the starting directory or file.
if (-d $dirname) { 
  processDIR($dirname); 
} else { 
  if (inTypesArray($dirname)) { countLOC($dirname); }
}

# Output total line count.
print "\n[$dirname] Total Lines: $total_loc\n";

1;


#
# Recursively process directory.
#
sub processDIR() {
  my ($dirname) = @_;
  my $file;

  opendir(DIR, $dirname) or die "can't opendir $dirname: $!";
  # Exclude "." and "..".
  my @files = grep { !/^\.{1,2}$/ } readdir (DIR); 
  closedir(DIR);
  #sort @files;

  foreach (@files) {
    $file = "$dirname/$_"; 

    if (-d $file) {
      if ($file =~ /\.svn/) { } # do nothing for svn folder.
      else {
        processDIR($file); # Is directory. Recursion.
      }
    }
    elsif (inTypesArray($file)) {
      countLOC($file);
    }
  }
}


#
# Determine if this file is of specified type.
#
sub inTypesArray() {
  my ($f) = @_;
  my $t;
  foreach $t (@types) {
if ($t eq "*") { return 1; }
    if ($f =~ /$t$/) { return 1; }
  }
  return 0;
}


#
# Count number of lines in the file.
#
sub countLOC() {
  my ($file) = @_;
  my $loc = 0;
  my @lines;
  my $line_ct;

  open(FILE, "$file");
  while(<FILE>) {
    @lines = split(/\r/, $_);
    $line_ct = @lines;
    #$loc ++;
    $loc += $line_ct;
  }
  close(FILE);
  print "[$file] Lines: $loc\n";

  $total_loc += $loc;
}