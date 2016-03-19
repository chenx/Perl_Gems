#! /usr/bin/perl

#
# The script deploys a project from svn repository to production site.
# It does this by:
# - enters ./tmp working foler
# - check out project file from repository
# - prepare the project by removing development-specific files (no need for deployment)
# - back up current production site to backup folder
# - copy the checked out and prepared project to the production site location
# - compress the backup into n.tar.gz file.
#
# Note:
# 1) Set parameters in the "Parameter section" below.
# 2) Before using this script the first time, you may need to check out the svn
#    repository manually once and store the svn password.
#
# @Author: X. Chen
# @Created on: 7/19/2013
# @Last modified: 8/11/2014
#
#

use Cwd;
use Getopt::Std;
use vars qw/ %opt /;
use strict;

print "\n== Hello to deployment script ==\n\n";

#
# Parameter section.
#

my $target_path = "/var/www/html/mysite";  # location of production site.
my $local_lib   = getcwd() . "/lib";       # library, contains the production conf file.
my $local_repos = getcwd() . "/tmp";       # work dir, to checkout and prepare project.
my $local_name  = "mysite";                # dir name in work dir. can be any.
my $repos = "https://subversion.assembla.com/svn/mysite/trunk";
my $backup_path = "/var/www/backup/mysite/file_bak";  # dir to place site backup files.

my $DoCheckout = 1;  # if 1, will actually checkout from repos.
my $RmDevFiles = 1;  # if 1, will prepare project by removing dev related files.
my $DoDeploy   = 1;  # if 1, will actually deploy to production site.
my $Verbal     = 1;
my $dir;

init();

showConfig();

print "Continue? [Y/N]: ";
while (<STDIN>) {
    chomp();
    #print "You entered: $_\n";
    if (uc($_) eq "Y") { last; }
    else { exit(0); }
}

print "=> Go to working directory\n";
gotoDir( $local_repos );

if ($DoCheckout) { doCheckout(); }
if ($DoDeploy)   { doDeploy();   }

print "\n==Deployment has successfully finished==\n\n";
0;

#
# Functions.
#

sub init() {
    use Getopt::Std;
    my $opt_string = 'hv';
    getopts( "$opt_string", \%opt ); # or usage();
    usage() if $opt{h};
    $Verbal = 1 if $opt{v};
}

sub usage() {
    print STDERR << "EOF";
usage: $0 [-hv]

    -h show this help message
    -v verbal, show more information

EOF
    exit(0);
}


#
# Note should use absolute path for chdir to work properly.
#
sub gotoDir {
    my ( $d ) = @_;

    $dir = getcwd();
    print "   Current dir: $dir\n";
    chdir "$d";
    $dir = getcwd();
    print "   Go to dir:   $dir\n";
}

sub doCheckout() {
    print "=> Clear tmp/ folder\n";
    run_cmd( "rm -rf $dir/*" );

    print "=> Checkout project\n";

    if ($Verbal == 1) {
        run_cmd( "svn export $repos $local_name" );
    }
    else {
        run_cmd( "svn export $repos $local_name > /dev/null 2>&1" );
    }

    # prepare project: remove dev related files.
    if ($RmDevFiles) {
        print "=> Prepare project (remove development related files)\n";
        run_cmd( "rm -rf $dir/$local_name/.htaccess" );
        run_cmd( "rm -rf $dir/$local_name/DEV_VERSION" );
        run_cmd( "rm -rf $dir/$local_name/deploy" );
        run_cmd( "rm -rf $dir/$local_name/robots.txt" );

        # Replace dev conf.php with the production one.
        run_cmd( "rm -rf $dir/$local_name/conf/conf.php" );
        run_cmd( "cp $local_lib/conf.php $dir/$local_name/conf/." );

        # Replace dev linkedin_conf.php with the production one.
        run_cmd( "rm -rf $dir/$local_name/conf/linkedin_conf.php" );
        run_cmd( "cp $local_lib/linkedin_conf.php $dir/$local_name/conf/." );

        # The font library is large and never changes. No need to check in repos.
        run_cmd( "cp $local_lib/font_cn_song_ti.ttf $dir/$local_name/func/." );
    }
}


sub doDeploy() {
    my $dir_bak = getNextBakDirName();

    print "=> Backup current version\n";
    run_cmd( "mv $target_path/ $backup_path/$dir_bak/" );
    run_cmd( "rm -rf $backup_path/$dir_bak/oj/tmp/*" ); # clear tmp folder.
    run_cmd( "rm -f $backup_path/$dir_bak/func/font_cn_song_ti.ttf" );

    print "=> Deploy new version\n";
    run_cmd( "mv $dir/$local_name/ $target_path/" );

    print "=> Compress backup to $dir_bak.tar.gz\n";
    gotoDir( $backup_path );
    #run_cmd( "tar cvf $dir_bak.tar $dir_bak");# > /dev/null 2>&1" );
    run_cmd( "tar cvf $dir_bak.tar $dir_bak >/dev/null 2>&1" );
    run_cmd( "gzip $dir_bak.tar" );
    run_cmd( "rm -rf $dir_bak" );
}

#
# All the backup files are n.tar.gz. n is the version number from 1, 2, 3...
# This will get the name of the last created file, and strip the ".tar.gz" part,
# get the version number, increment by 1, and use it as the next dir name.
#
sub getNextBakDirName() {
    #print "getNextBakDirName: backup_path = $backup_path\n";
    my $baklist = `ls -t $backup_path`; # use -t to list in create time DESC order.
    my @baks = split('\n', $baklist);
    my $ct = @baks;

    #print $baklist . "\n";
    #print "ct: $ct\n";
    #foreach my $v (@baks) {
    #    print ": $v\n";
    #}

    my $nextDir;
    if ($ct == 0) {
        $nextDir = 1;
    }
    else {
        $nextDir = $baks[0];
        $nextDir =~ s/\.tar\.gz//i;
        if ($nextDir =~ /^[0-9]+$/) {
            $nextDir = $nextDir + 1;
        } else {
            print "\nError: latest backup file name in [$backup_path] is not a number: $baks[0]\n";
            print "It should be a number for the purpose of versioning.\n";
            print "Please fix this before deploy.\n\n";
            exit(0);
        }
    }

    #$nextDir = "$nextDir";
    #print "next dir: $nextDir\n";
    return $nextDir;
}

sub showConfig() {
    print "=> Configuration setting:\n";
    print "   repos: $repos\n";
    print "   local lib: $local_lib\n";
    print "   local repos: $local_repos\n";
    print "   local name: $local_name\n";
    print "   target: $target_path\n";
    print "   backup path: $backup_path\n";

    print "   DoCheckout: $DoCheckout (if 1, will actually checkout from repos)\n";
    print "   RmDevFiles: $RmDevFiles (if 1, will remove dev related files)\n";
    print "   DoDeploy:   $DoDeploy (if 1, will actually deploy to production)\n";
    print "   Verbal:     $Verbal   (if 1, print more information)\n";
}

sub run_cmd() {
    my ($cmd) = @_;
    print "   Command: $cmd\n";
    system ($cmd);
}



