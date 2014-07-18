#!/usr/bin/perl -w
#
#1111111112222222222333333333344444444445555555555666666666677777777778888888888
#
# This perl script downloads all files within domain $url_root to local machine,
# starting from the page $url_start.
#
# Tested on:
# - Windows, Perl version 5.8.8.
# - Linux
#
# Short introduction to crawling in Perl:
# http://www.cs.utk.edu/cs594ipm/perl/crawltut.html
#
# LWP: http://search.cpan.org/~gaas/libwww-perl-5.805/lib/LWP.pm
# HTML parser: http://search.cpan.org/dist/HTML-Parser/
# POSIX: http://search.cpan.org/~rgarcia/perl-5.10.0/ext/POSIX/POSIX.pod
# POSIX math functions, e.g., floor(), ceil():
#     http://www.perl.com/doc/FAQs/FAQ/oldfaq-html/Q4.13.html
# Progress bar: http://oreilly.com/pub/h/943
# Perldoc: http://juerd.nl/site.plp/perlpodtut
#          http://www.perlmonks.org/?node_id=252477
#
# @author: Xin Chen
# @created on: 12/22/2007
# @last modified: 7/17/2014
#


######################################################
# Perldoc 
######################################################

=head1 NAME 

XC_Crawler. Script name is pcraw.pl

=head1 DESCRIPTION

XC_Crawler is a perl script to crawl the web.

When used for the first time, it creates a local repository 
./download/ under the same directory. 
For each download task, a sub directory derived from the url_root 
(see below) will be created, and all downloads are stored there. 
A log file pcraw.log will be created under the same directory.

For each download task, at least 2 parameters are needed:

1) url_root. Only files under this url will be downloaded.
The avoids crawling through the entire web. The user must provide this.
This can be provided using the -r switch.

2) url_start. This is the url where the crawling starts from. 
If its value is not provided, it uses url_root as its value.
This can be provided using the -u switch.

=head1 SYNOPSIS

Usage: perl pcraw [-dhiprstuv]

For more help on usage, type: perl pcraw -h 

=head1 LICENSE

APACHE/MIT/BSD/GPL 2.0

=head1 AUTHOR

=over 

=item 
X. Chen <chenx@hawaii.edu>

=item 
Copyrighted (c) since July, 2014

=back

=cut


######################################################
# Package name.
######################################################

package XC_Crawler;


######################################################
# Include packages.
######################################################

use strict; 
use LWP::Simple;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use HTML::LinkExtor;
use Time::Local;
use POSIX;      # for floor(), ceil(): 
use Encode;     # For decode_utf8, in parseLinks().
use IO::Handle; # For flushing log file.
use Data::Dumper;
$|++;           # For printing progress bar in getUrl().


######################################################
# Definition of global variables.
######################################################

my $DEBUG = 0;          # Print debug information.
my $local_repos = "./download/"; # Local storage repository directory.
my $local_root = "";    # Local root directory for a download task.
my $url_root = "";      # Only files under this root will be downloaded.
my $url_start = "";     # Where the crawling starts from.
my $url = "";           # File url.
my $contents;           # File contents
my @link_queue;         # Store links already crawled.
my @type_queue;         # Store content type of the files.
my $content_type;       # Content type of a file.
my @size_queue;         # Store content size of the files.
my $content_size;       # Content size of a file.
my $plain_txt_only = 0; # Download text files (html, php, etc.) only.
my $test_crawl = 0;     # Set to 0 to download $url_start page only.
my $verbose = 0;        # If 1, print more details to screen and log.

#
# Some images are not in the directory of $url_root. 
# E.g., we want to download files in http://site/people/, 
# but the displayed images are stored in http://site/images/, 
# then set this to 1 if those should be downloaded also.
#
my $get_outside_image = 0;

#
# Dynamic pages are like: http://site/page.asp?a=b
# The feature is a "?" followed by parameters.
# If this is 1, only download static pages, and do not download dynamic pages.
#
my $static_page_only = 0;


#
# For command line options.
#
my $OPT_URL_ROOT_S = "-r";
my $OPT_URL_ROOT_L = "--url-root";
my $OPT_URL_START_S = "-u";
my $OPT_START_URL_L = "--url-start";
my $OPT_HELP_S = "-h";
my $OPT_HELP_L = "--help";
my $OPT_TEST_S = "-t";
my $OPT_TEST_L = "--test";
my $OPT_PLAIN_TXT_ONLY_S = "-p";
my $OPT_PLAIN_TXT_ONLY_L = "--plain-txt-only";
my $OPT_STATIC_ONLY_S = "-s";
my $OPT_STATIC_ONLY_L = "--static-only";
my $OPT_OUTSIDE_IMAGE_S = "-i";
my $OPT_OUTSIDE_IMAGE_L = "--include-image-outside";
my $OPT_DEBUG_S = "-d";
my $OPT_DEBUG_L = "--debug";
my $OPT_VERSION_S = "-v";
my $OPT_VERSION_L = "--version";
my $OPT_VERBOSE_S = "-V";
my $OPT_VERBOSE_L = "--verbose";

#
# Use by getUrl() function that prints a progress bar.
#
my $total_size; # Total size of a file to download.
my $final_data; # The content of a downloaded file.


######################################################
# Entry point of the program
######################################################

MAIN: if (1) {
  &getOptions();

  #
  # In case you want to hard-code the urls, un-comment lines below.
  #
  #$url_root = "http://";
  #$url_start = "http://";
  
  if ($url_root eq "") {
    print ("\nError: url_root is not provided. exit.\n");
    &show_usage();
    exit(0);
  }
  
  # url_root should ends with "/".
  if (! ($url_root =~ /\/$/)) { $url_root .= "/"; }
  if ($url_start eq "") { $url_start = $url_root; }

  my $log = get_log_name();
  open LOGFILE, ">> $log";

  output ("");
  output ("===== Perl Web Crawler started =====");
  output ("url_root:  $url_root");
  output ("url_start: $url_start");
  output ("");
  &get_site();

  close LOGFILE;
}


1;


######################################################
# Definition of functions.
######################################################


sub getOptions() {
  my $ARGV_LEN = @ARGV;
  my $state = "";

  for (my $i = 0; $i < $ARGV_LEN; ++ $i) {
    if ($DEBUG) { 
      print "argv[$i]. " . $ARGV[$i] . "\n";
    }

    my $a = $ARGV[$i];

    if ($a eq $OPT_URL_ROOT_S || $a eq $OPT_URL_ROOT_L) { $state = $OPT_URL_ROOT_S; }
    elsif ($a eq $OPT_URL_START_S || $a eq $OPT_START_URL_L) { $state = $OPT_URL_START_S; }

    elsif ($a eq $OPT_TEST_S || $a eq $OPT_TEST_L) { $test_crawl = 1; $state = ""; }
    elsif ($a eq $OPT_PLAIN_TXT_ONLY_S || $a eq $OPT_PLAIN_TXT_ONLY_L) { $plain_txt_only = 1; $state = ""; }
    elsif ($a eq $OPT_STATIC_ONLY_S || $a eq $OPT_STATIC_ONLY_L) { $static_page_only = 1; $state = ""; }
    elsif ($a eq $OPT_OUTSIDE_IMAGE_S || $a eq $OPT_OUTSIDE_IMAGE_L) { $get_outside_image = 1; $state = ""; }
    elsif ($a eq $OPT_DEBUG_S || $a eq $OPT_DEBUG_L) { $DEBUG = 1; $state = ""; }
    elsif ($a eq $OPT_VERBOSE_S || $a eq $OPT_VERBOSE_L) { $verbose = 1; $state = ""; }

    elsif ($a eq $OPT_VERSION_S || $a eq $OPT_VERSION_L) { &show_version(); exit(0); }
    elsif ($a eq $OPT_HELP_S || $a eq $OPT_HELP_L) { &show_usage(); exit(0); }

    elsif ($state eq $OPT_URL_ROOT_S) { $url_root = $a; $state = ""; }
    elsif ($state eq $OPT_URL_START_S) { $url_start = $a; $state = ""; }

    else { 
      print "Warning: unknown option $a\n";
      $state = ""; 
    }
  }
}


sub show_usage() {
  my $usage = <<"END_USAGE"; 

Usage: perl $0 $OPT_URL_ROOT_S [-dhiprstuv]

  Options (short format):
    -d: debug, print debug information.
    -h: print this help message.
    -i: download images outside the url_root.
        Used when images are stored outside the url_root.
    -p: only download plain text files: html, txt, asp, etc. 
        Binary files are ignored.
    -r: url_root, need to follow with url_root value. 
        Only files under this path are downloaded. Except when -i is used.
    -s: only download static pages. 
        Pages with url parameters like http://a.php?a=b are ignored.
    -t: test, only download the start_url page.
    -u: url_start, need to follow with url_start value.
        This is where a crawling task starts from.
    -v: show version information.

  Options (long format):
    --debug: same as -d
    --help: same as -h
    --include-image-outside: same as -i
    --plain-txt-only: same as -p
    --static-only: same as -s
    --test: same as -t
    --url-root: same as -r
    --url_start: same as -u
    --version: same as -v

  The most important options are:
  -r or --url-root : url_root is needed, and must be provided.
  -u or --url-start: url_start, when not provided, use url_root as default.

  Examples:
    perl $0 -r http://g.com 
    perl $0 -r http://g.com -u http://g.com/about.html
    perl $0 --url-root http://g.com 
    perl $0 --url-root http://g.com --url-start http://g.com/
    perl $0 -h
    
  Type "Perldoc $0" to see perldoc message.
END_USAGE

  print $usage;
}


sub show_version() {
  print "\n$0 version 1.0\n";
}

#
# Log file name is obtained by
# replacing the ".pl" suffix with ".log".
#
sub get_log_name() {
  my $log = $0;
  if ($log =~ /\.pl/i) {
    $log =~ s/\.pl/\.log/i;
  }
  print "---------$log\n";
  return $log;
}


#
# Create local repository.
#
sub create_local_repos() {
  if (! (-d $local_repos)) { 
    &exec_cmd("mkdir \"$local_repos\"");
    if (! (-d $local_repos)) { 
      output("Cannot create local repository: $local_repos");
      die(); 
    }
    output ("Local repository $local_repos is created");
  }
}


#
# Local_root derives from url_root.
#
sub get_local_root() {
  my ($root) = @_;
  if ($DEBUG) { output ("get_local_root(): root = $root" ); }
  
  if ($root =~ /^http:\/\//i) { $root =~ s/^http:\/\///i; }
  if ($root =~ /\/$/) { $root =~ s/\/$//; } # remove trailing "/" if any.
  
  $root =~ s/\//_/g; # replace all "/" with "_".

  $local_root = $local_repos . $root;
  if ($DEBUG) 
  { 
	output ("get_local_root(): local_root = $root" ); 
  }
}


sub get_site() {
  my ($ss_s, $mm_s, $hh_s) = localtime(time);

  &create_local_repos(); # create local repository, if not exist.
  &get_local_root($url_root); # create local root for this task.

  if (! (-d $local_root)) { 
    &exec_cmd("mkdir \"$local_root\"");
    if (! (-d $local_root)) { 
      output("Abort. Cannot create local root: $local_root");
      return; # return instead of die(), to close LOGFILE handle.
    }
    output ("Local root $local_root is created");
    output ("");
  }

  if (! isWantedFile($url_start) ) {
    $url_start .= "/"; # url_start is a directory, not a file.
    if (! isWantedFile($url_start) ) { 
      print "Abort. Invalid url_start: $url_start\n";
      return;
    }
  }
  
  #print "::$url_start, $content_type, $content_size\n";
  @link_queue = (@link_queue, $url_start);
  @type_queue = (@type_queue, $content_type);
  @size_queue = (@size_queue, $content_size);
  
  &go_get_site();
  
  my ($ss_t, $mm_t, $hh_t) = localtime(time);
  my $sec = ($hh_t - $hh_s) * 3600 + ($mm_t - $mm_s) * 60 + ($ss_t - $ss_s);
  output ("Total time spent: " . &writeTime($sec) );
}


#
# Crawl the site, using BFS with a queue.
#
sub go_get_site() {
  my $link_queue_len = @link_queue;
  my $link_queue_pt = 0;
  my @new_urls;
  my $msg;
  my $type;
  my $size;
  my $content_len;

  my $browser = LWP::UserAgent->new();
  $browser->timeout(10);

  while ($link_queue_pt < $link_queue_len) {
    $url = $link_queue[$link_queue_pt];
    $type = $type_queue[$link_queue_pt];
    $size = $size_queue[$link_queue_pt];

    # clear left over chars of current row from prevous progress bar.
    print progress_bar(-1, 0, 0, ''); 
    output( "link #" . (1 + $link_queue_pt) . ": $url" );

    $contents = &getUrl($url, $browser);
    $content_len = length($contents);
    
    if ($content_len > 0) { # if == 0, then may be "403 Access Forbidden".
      if ($verbose) {
        output( "   Type: $type, Size: " . ($size // $content_len) );
      }
    
      &save_content($url, $contents, $type);
      
      print progress_bar(-1, 0, 0, ''); 
      print "parsing links, please wait..\r";
      @new_urls = &parseLinks($url, $contents, $type);
      
      if (! $test_crawl) { &add_new_links($url, @new_urls); } 
      if ($get_outside_image) { &add_image_links($url, @new_urls); } 
    }

    $link_queue_len = @link_queue;
    $link_queue_pt ++;
  }
  
  # clear left over chars of current row from prevous progress bar.
  print progress_bar(-1, 0, 0, ''); 

  output ("");
  output ("Total links crawled: $link_queue_len");
}


sub writeTime() {
  my ($sec) = @_;
  my ($h, $m, $s);
  $h = floor($sec / 3600);
  $m = floor(($sec - ($h * 3600)) / 60);
  $s = $sec - ($h * 3600) - ($m * 60);
  return "$h:$m:$s";
}


#
# Get html content of an url.
# This works, but does not use a call_back to draw progress bar.
#
# To call, first initiate the $browser variable:
#   my $browser = LWP::UserAgent->new();
#   $browser->timeout(10);
# Then call this function with: getUrl($url, $browser).
#
# $response->content_type() can be:
# text/html, image/jpeg, image/gif, application/msword etc.
#
sub getUrl_deprecated() {
  my ($url, $browser) = @_;
  my $request = HTTP::Request->new(GET => $url);
  my $response = $browser->request($request);
  if ($response->is_error()) {
    output( "getUrl error: " . $response->status_line . " -> URL: " . $url);
    return "";
  }
  #print "$url: content type: " . $response->content_type() . "\n";
  return $response->content();
}


#
# Get html content of an url.
#
sub getUrl() {
  my ($url, $browser) = @_;
  $final_data = "";
   
  my $result = $browser->head($url);
  my $remote_headers = $result->headers;
  if ($DEBUG) { print "getUrl(): " . Dumper($remote_headers); }
  
  # Most servers return content-length, but not always.
  $total_size = $remote_headers->content_length;
  
  # now do the downloading.
  my $response = $browser->get($url, ':content_cb' => \&callback );
  
  # Don't clear row here, it's too soon. Clear in function go_get_site().
  #print progress_bar(-1,01,25,'='); 
  
  if ($verbose) { print "\n"; } # Keep the progress bar, if desired.
  return $final_data; # File content.
}


# per chunk.
sub callback {
   my ($data, $response, $protocol) = @_;
   $final_data .= $data;
   #print "callback: len = " . length($final_data) . "\n";
   print progress_bar( length($final_data), $total_size, 25, '=' ); 
}


#
# Print progress bar.
# Each time sprintf is printing to the same address, so same location on screen.
# $got - bytes received so far.
# $total - total bytes of the file.
# $width - size of the progress bar: "==..==>"
# $char  - the '=' char used by the progress bar.
#
# Code is modified from: http://oreilly.com/pub/h/943
#
# wget-style. routine by tachyon
# at http://tachyon.perlmonk.org/
#
sub progress_bar {
    my ( $got, $total, $width, $char ) = @_;
    $width ||= 25; $char ||= '-'; # "||=": default to if not defined.
    my $num_width = length ($total // "");
    
    # Some web servers don't give "content-length" field.
    # In such case don't print progress bar.
    if ($num_width == 0) { return; }
    
    #print "got = $got, total = $total\n";    
    if ($got == -1) { 
      # removes the previous print out. 
      # 79 is used since in standard console, 1 line has 80 chars.
      # 79 spaces plus a "\r" is 80 chars.
      # Besides, this should be enough to cover reasonable file sizes.
      # e.g. the progress bar below has 64 chars, when file size is 6-digit.
      # |========================>| Got 100592 bytes of 100592 (100.00%)
      # So 12 chars are used for file size, 52 chars for the rest bytes.
      # This gives 79 - 52 = 27 bytes for file size, so file size
      # can be up to 13 digits without interrupting the format.
      sprintf (' ' x 79) . "\r";  
    }
    else {
      sprintf "|%-${width}s| Got %${num_width}s bytes of %s (%.2f%%)\r", 
        $char x (($width-1)*$got/$total). '>', 
        $got, $total, 100*$got/+$total;
    }
}


#
# $$link[i]: valid values for i: 0 (tag name), 1(attribute name), 2(link value)
# e.g.: <img src='http://127.0.0.1/index.html'>
# Here $$link[0] = img, $$link[1] = src, $$link[2] = http://127.0.0.1/index.html
#
sub parseLinks() {
  my ($url, $contents, $type) = @_;
  my ($page_parser) = HTML::LinkExtor->new(undef, $url);

  # This would have the warning:
  # "Parsing of undecoded UTF-8 will give garbage when decoding entities".
  # So use the one with decode_utf8, about same speed.
  #$page_parser->parse($contents)->eof; 
  $page_parser->parse(decode_utf8 $contents)->eof;   
  
  my @links = $page_parser->links;
  my @urls;

  foreach my $link (@links) {
    #print "$$link[0]\t $$link[1]\t $$link[2]\t \r";
    #print substr($$link[2], 0, 50) . " ...\r";
    @urls = (@urls, $$link[2]);
  }
  return @urls;
}


sub add_new_links() {
  my ($url, @new_links) = @_;
  my $len = @new_links;
  my $new_link;
  #print "add_new_links(): total = $len\n";

  for (my $i = 0; $i < $len; $i ++) {
    $new_link = $new_links[$i];
    
    # Remove links like "http://a.com/a.html#section_1".
    if ($new_link =~ /#[a-z0-9\-\_\%]*$/i) { 
      $new_link =~ s/#[a-z0-9\-\_\%]*$//i;
    }

	if ( isWantedFile($new_link) ) {
      #print "::$new_link, $content_type, $content_size\n";
      @link_queue = (@link_queue, $new_link);
      @type_queue = (@type_queue, $content_type);
      @size_queue = (@size_queue, $content_size);

      if ($DEBUG) { output( "add new link: $new_link" ); }
    }
  }
}


#
# get those files that are wanted but NOT in the $url_root folder.
#
sub add_image_links() {
  my ($url, @new_links) = @_;
  my $len = @new_links;
  my $new_link;
  #print "add_new_links(): total = $len\n";
  
  for (my $i = 0; $i < $len; $i ++) {
    $new_link = $new_links[$i];

    if ( isWantedImage($new_link) &&
         (! link_exists($new_link)) ) {
      @link_queue = (@link_queue, $new_link);
      if ($DEBUG) { output( "add new link: $new_link" ); }
    }
  }
}


sub link_crawled() {
  my ($new_link) = @_;
  my $len = @link_queue;
  my $i;
  for ($i = 0; $i < $len; $i ++) {
    if ($new_link eq $link_queue[$i]) { return 1; }
  }
  #print "link NOT exist: $new_link\n";
  return 0;
}


sub insideDomain() {
  my ($link) = @_;
  if ($link =~ /^$url_root/i) { return 1; }
  return 0;
}


sub getFileHeader() {
  my ($link) = @_;
  ($content_type, $content_size) = head($link); 
  if ($DEBUG) {
    output ("getFileHeader(): $link type: $content_type, size: $content_size");
  }
}


#
# Generally there are txt/html files, image files,
# and other multimedia files.
# Here we basically only want txt/html and image files.
#
# The list obiously is incomplete.
#
sub isWantedFile() {
  my ($link) = @_;
  if (! &insideDomain($link)) { return 0; } 
  if (&link_crawled($link)) { return 0; }
  if ($static_page_only && $link =~ /\?(\S+=\S*)+$/i) { return 0; }

  &getFileHeader($link);

  # content_size is null for dynamic pages.
  # content_type may be null, "//" operator is "defined or".
  # both of these 2 may be undefined, but the file still can be downloaded,
  # e.g., for case when ".." is involved, like http://abc.com/../xyz.html
  #if ( ($content_type // "") eq "") { # || $content_size eq "") { 
  #  output("$link: Empty file. Do not download.");
  #  return 0; 
  #}

  # Must use () around the regex expression to get correct precedence.
  if ($plain_txt_only && ! (($content_type // "") =~ /^text\//)) { return 0; }

  return 1;
}


sub get_mime_type() {
  my ($type) = @_;
  if (($type // "") ne "") {
    my @tmp = split(';', $type); # for cases like: "text/html; charset=utf-8"
    my @tmp2 = split('/', $tmp[0]);
    #print "mime type: $tmp2[1]\n";
    if (length(@tmp2 >= 2) && $tmp2[1] ne "") {
      return $tmp2[1];	  
    }
  }
  return "";
}


sub save_content() {
  my ($url, $content, $type) = @_;
  my $outfile;
  
  my $filename = get_filename($url);
  #print "save_content(). filename = $filename\n"  ;
  my $localpath = get_local_path($url, $filename);
  #print "save_content(). url=$url, localpath = $localpath\n";
  
  # This happens for default page under a directory.
  if ($filename eq "") { $filename = "index_"; }
  
  if ($filename =~ /\?/) {
    $filename =~ s/\?/-/g; # replace "?" with "-", for dynamic page.
    
    # A dynamic page may be like a.php?x=1&y=2, and has no suffix when save.
    # In this case, get file suffix from content-type. E.g, save as:
    # This will be saved as a.php-x=1&y=2.html
    #print "type: $type\n";
    my $t = &get_mime_type($type);
    if ($t ne "") { $filename .= ".$t"; }
  }
  elsif (! ($filename =~ /\./)) { 
    # this happens when the file does not have a suffix, 
    # e.g., when this is the index file under a directory.
    # then the directory name is used as a file name,
    # and no directory is created locally.
    my $t = &get_mime_type($type);
    if ($t ne "") { $filename .= ".$t"; }
  }

  if ($localpath =~ /\/$/) { $outfile = "$localpath$filename"; }
  else { $outfile = "$localpath/$filename"; }  
  
  if ($DEBUG) { output ("save content to: $outfile"); }

  # this happens when the url ends with "/", 
  # and the file to save is the default under this.
  # for example, index.html or default.html.
  if ($outfile =~ /\/$/) {
      $outfile = $outfile . "index_.html";
  }
  
  if (open OUTFILE, "> $outfile") {
    binmode(OUTFILE);
    print OUTFILE $content;
    close OUTFILE;
  } else {
    output ("save_content() error: cannot open file to save to: $outfile");
  }
}


sub exec_cmd() {
  my $cmd = shift;
  output($cmd);
  `$cmd`;
}


#
# Obtain local path from the remote url path.
# Created needed local directory if needed.
#
sub get_local_path() {
  my ($path, $filename) = @_;
  my $pattern = "$url_root";
  if ($DEBUG) { 
    print "get_local_path(): remote path=$path, filename=$filename\n"; 
  }
  if ($path =~ /^$pattern/i) {
    $path =~ s/^$pattern//i;
  } else { # not under the same $url_root.
    if ($path =~ /^http:\/\//) { $path =~ s/^http:\/\///; } 
  }

  # Remove filename from path.
  $path = substr($path, 0, length($path) - length($filename));
  #print "after remove filename: $path\n";
  if ($path =~ /^\//) { $path =~ s/^\///; }
    
  if ($local_root =~ /\/$/) { $path = "$local_root$path"; }
  else {$path = "$local_root/$path"; }
    
  if($DEBUG) { print "get_local_path(): local dir=$path\n"; }
  if (! (-d $path)) {
    #mkdir ($path, 0700);
    &exec_cmd("mkdir \"$path\"");
    #if ($DEBUG) { print "create local directory: $path\n"; }
  }

  return $path;
}


#
# extract filename from the url.
# Need to remove suffix including "?.." and "#..".
#
sub get_filename() {
  my ($path) = @_;
  my $filename;
  my $i = rindex($path, "/");
  $filename = substr($path, $i + 1);
  #if ($DEBUG) { print "get_filename(): url=$path filename=$filename\n"; }
  return $filename;
}


sub output {
  my ($msg) = @_;

  print "$msg\n";
  
  # Log for every change by flush log file handle.
  # If log in batch mode, may lose intermediate 
  # information when the program process is killed.
  print LOGFILE (localtime(time) . " $msg\n");
  LOGFILE->autoflush;
}

