#!/usr/bin/perl -w
#
# This perl script downloads all files within domain $url_root to local machine,
# starting from the page $url_start.
#
# Tested in DOS on windows XP, Perl version 5.8.8.
#
# Short introduction to crawling in Perl:
# http://www.cs.utk.edu/cs594ipm/perl/crawltut.html
#
# LWP: http://search.cpan.org/~gaas/libwww-perl-5.805/lib/LWP.pm
# HTML parser: http://search.cpan.org/dist/HTML-Parser/
# POSIX: http://search.cpan.org/~rgarcia/perl-5.10.0/ext/POSIX/POSIX.pod
#
# @author: Xin Chen
# @created on: 12/22/2007
# @last modified: 7/16/2014
#

use strict;
use Time::Local;
use POSIX; # for floor(), ceil(): http://www.perl.com/doc/FAQs/FAQ/oldfaq-html/Q4.13.html
use LWP::Simple;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use HTML::LinkExtor;


#
# Print debug information.
#
my $DEBUG = 0;

#
# Local storage repository directory.
#
my $local_repos = "./download/"; 

#
# Local root directory for a download task.
# This is obtained from start_url.
#
my $local_root = ""; 

#
# Only files under this root will be downloaded.
#
my $url_root = "";

#
# Where the crawling starts from.
#
my $url_start = "";

#
# File url.
#
my $url = ""; 

#
# File contents
#
my $contents;

#
# Store links already crawled.
#
my @link_queue;

#
# Store type of the files.
#
my @type_queue;
my $content_type;

#
# Store size of the files.
#
my @size_queue;
my $content_size;

#
# Download plain text files (html, txt, asp, etc.) only.
#
my $plain_txt_only = 0;

#
# Set this to 0 if only download the $url_start page.
#
my $test_crawl = 0;

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
# If 1, print more details to screen and log.
#
my $verbose = 0;

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
# Entry point of this program.
#
MAIN: {
  if (1) {
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

    if ($url_start eq "") {
      $url_start = $url_root;
    }

    open LOGFILE, ">> $0.log";

    output ("");
    output ("===== Perl Web Crawler started =====");
    output ("url_root:  $url_root");
    output ("url_start: $url_start");
    output ("");

    &create_local_repos();
    &get_local_root($url_start);
    &get_site();

    close LOGFILE;
  }
}


1;


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

Usage: perl $0 $OPT_URL_ROOT_S [-shtpyidv]

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
END_USAGE

  print $usage;
}


sub show_version() {
  print "\n$0 version 1.0\n";
}


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
# This derives from start_url.
# Even under the same url_root, starting from different start_url,
# result file set may be different.
#
sub get_local_root() {
  my ($root) = @_;
  if ($DEBUG) { output ("get_local_root(): root = $root" ); }
  
  if ($root =~ /^http:\/\//i) { $root =~ s/^http:\/\///i; }
  if ($root =~ /\/$/) { $root =~ s/\/$//; }

  $root =~ s/\//_/g; # replace all "/" with "_".
  $root =~ s/\./-/g; # replace all "." with "-".
  $root =~ s/\?/-/g; # replace all "?" with "-". For dynamic page.

  $local_root = $local_repos . $root;
  if ($DEBUG) 
  { 
	output ("get_local_root(): local_root = $root" ); 
  }
}


sub get_site() {
  my ($ss_s, $mm_s, $hh_s) = localtime(time);
  
  if ($local_root eq "" || $url_root eq "" || $url_start eq "") {
    output ("params NOT initialized.");
    exit;
  }

  if (! (-d $local_root)) { 
    #mkdir("$local_root", 0700) || die "cannot create $local_root"; 
    &exec_cmd("mkdir \"$local_root\"");
    if (! (-d $local_root)) { 
      output("Cannot create local root: $local_root");
      die(); 
    }
    output ("Local root $local_root is created");
    output ("");
  }

  if ( isWantedFile($url_start) ) {
    #print "::$url_start, $content_type, $content_size\n";
    @link_queue = (@link_queue, $url_start);
    @type_queue = (@type_queue, $content_type);
    @size_queue = (@size_queue, $content_size);

    if ($DEBUG) { output( "add new link: $url_start" ); }
  }
  
  my $link_queue_len = @link_queue;
  my $link_queue_pt = 0;
  my @new_urls;
  my $msg;
  my $type;
  my $size;

  my $browser = LWP::UserAgent->new();
  $browser->timeout(10);

  while ($link_queue_pt < $link_queue_len) {
    $url = $link_queue[$link_queue_pt];
    $type = $type_queue[$link_queue_pt];
    $size = $size_queue[$link_queue_pt];

    output( "link #" . (1 + $link_queue_pt) . ": $url" );
    if ($verbose) {
      output( "   Type: $type, Size: $size" );
    }

    $contents = &getUrl($url, $browser);
    
    if (length($contents) > 0) { # if == 0, then may be "403 Access Forbidden".
      &save_content($url, $contents);
      
      @new_urls = &parseLinks($url, $contents);
      if (! $test_crawl) { &add_new_links($url, @new_urls); } # add links within $url_root only.
      if ($get_outside_image) { &add_image_links($url, @new_urls); } # get all images.
    }

    $link_queue_len = @link_queue;
    $link_queue_pt ++;
  }
  
  output ("");
  output ("Total links crawled: $link_queue_len");
  my ($ss_t, $mm_t, $hh_t) = localtime(time);
  my $sec = ($hh_t - $hh_s) * 3600 + ($mm_t - $mm_s) * 60 + ($ss_t - $ss_s);
  output ("Total time spent: " . &writeTime($sec) );
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
#
# To call, first initiate the $browser variable:
#   my $browser = LWP::UserAgent->new();
#   $browser->timeout(10);
# Then call this function with: getUrl($url, $browser).
#
# $response->content_type() can be:
# text/html, image/jpeg, image/gif, application/msword etc.
#
sub getUrl() {
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
# $$link[i]: valid values for i: 0 (tag name), 1(attribute name), 2(link value)
# e.g.: <img src='http://127.0.0.1/index.html'>
# Here $$link[0] = img, $$link[1] = src, $$link[2] = http://127.0.0.1/index.html
#
sub parseLinks() {
  my ($url, $contents) = @_;
  my ($page_parser) = HTML::LinkExtor->new(undef, $url);
  $page_parser->parse($contents)->eof;
  my @links = $page_parser->links;
  my @urls;

  foreach my $link (@links) {
    #print "$$link[0]\t $$link[1]\t $$link[2]\t \n";   
    @urls = (@urls, $$link[2]);
  }
  return @urls;
}


sub add_new_links() {
  my ($url, @new_links) = @_;
  my $len = @new_links;
  my $i;
  my $new_link;

  #print "add_new_links(): total = $len\n";

  for ($i = 0; $i < $len; $i ++) {
    $new_link = $new_links[$i];
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
  my $i;
  my $new_link;
  #print "add_new_links(): total = $len\n";
  for ($i = 0; $i < $len; $i ++) {
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
  ($content_type, $content_size) = head($link); # or die "isPlainTxtFile() ERROR $link: $!";
  if ($DEBUG) {
    #output ("getFileHeader(): Link: $link type: $content_type, size: $content_size");
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

  if ($content_type eq "") { # || $content_size eq "") { # content_size is null for dynamic pages.
    output("$link: Empty file. Do not download.");
    return 0; 
  }

  # Must use () around the regex expression to get correct precedence.
  if ($plain_txt_only && ! ($content_type =~ /^text\//)) { return 0; }

  #if ($plain_txt_only) {
    # A third possibility is to test $response->content_type for txt/html
    # in getURL, but that needs to download the file first.
    # The best way may be to get the header of a file only and 
    # check it for content_type.
  #  if ($link =~ /\.jpg$/i) { return 1; }
  #  if ($link =~ /\.gif$/i) { return 1; }
  #  if ($link =~ /\.png$/i) { return 1; }
  #  if ($link =~ /\.bmp$/i) { return 1; }
  #  if ($link =~ /\.tiff$/i) { return 1; }
  #  if ($link =~ /\.doc$/i) { return 1; }
  #  if ($link =~ /\.pdf$/i) { return 1; }
  #  if ($link =~ /\.ps$/i) { return 1; }

  #  if ($link =~ /\.wav$/i) { return 1; }
  #  if ($link =~ /\.mp3$/i) { return 1; }
  #  if ($link =~ /\.midi$/i) { return 1; }
  #}

  return 1;
}


# deprecated.
#sub print_content() {
#  my ($url, $content) = @_;
#  print "\n--$url--\n$content\n";
#  print "HTML length: " . length($content) . "\n\n";
#}


sub save_content() {
  my ($url, $content) = @_;
  my $outfile;
  
  my $filename = get_filename($url);
  my $localpath = get_local_path($url, $filename);

  
  if ($localpath =~ /\/$/) { $outfile = "$localpath$filename"; }
  else { $outfile = "$localpath/$filename"; }  
  
  if ($DEBUG) { output ("save content to: $outfile"); }

  # this happens when the url ends with "/", and the file to save is the default under this.
  # for example, index.html or default.html.
  if ($outfile =~ /\/$/) {
      $outfile = $outfile . "index_.html";
  }
  
  if (open OUTFILE, "> $outfile") {
    binmode(OUTFILE);
    print OUTFILE $content;
    close OUTFILE;
  } else {
    output ("save_content() error: cannot open local file to save to: $outfile");
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
  #if ($DEBUG) { print "get_local_path(): remote path=$path, filename=$filename\n"; }
  if ($path =~ /^$pattern/i) {
    $path =~ s/^$pattern//i;
  } else { # not under the same $url_root.
    if ($path =~ /^http:\/\//) { $path =~ s/^http:\/\///; } 
  }

  #print "after remove root: $path\n";
  $path =~ s/$filename$//i;
  #print "after remove filename: $path\n";
  if ($path =~ /^\//) { $path =~ s/^\///; }
    
  if ($local_root =~ /\/$/) { $path = "$local_root$path"; }
  else {$path = "$local_root/$path"; }
    
  #if($DEBUG) { print "get_local_path(): local dir=$path\n"; }
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
  #$filename =~ s/\?/-/g; # replace all "?" with "-". For dynamic page.
  #if ($DEBUG) { print "get_filename(): url=$path filename=$filename\n"; }
  return $filename;
}


sub output {
  my ($msg) = @_;

  print "$msg\n";
  print LOGFILE (localtime(time) . " $msg\n");
}

