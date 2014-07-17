#
# This script demonstrates a functional HTTP web server in Perl:
# 1) running the Perl HTTP web server as a daemon in background.
# 2) only one copy of the server can run by checking "Proc::PID::File->running()".
# 3) implementation of daemon commands: start, stop, status.
#    e.g. start the web server by: sudo perl dmon_server.pl start.
#
# Note: 
# 1) to run as daemon, "sudo" should be used for non-admin user.
# 2) parameters that can change: $LOG_FILE, $WWWROOT, $USE_OPT,
#     and $localport in functoin do_start().
#
# @By: X.C.
# @Created on: 6/28/2014
# @Last modified: 7/2/2014
#

#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Proc::Daemon;
use Proc::PID::File;
use IO::Select;
use IO::Socket;
use URI::Escape;

#
# Location of log file.
#
my $LOG_FILE = "/Users/chenx/tmp/dmon.log";
#
# Location of web root.
#
my $WWWROOT = "/Users/chenx/tmp/wwwroot";

#
# If $USE_OPT = 1, use GetOptions. 
# 0 is better here because if an arg does not start with "--",
# it will be ignored and no usage information is printed.
#
my $USE_OPT = 0; 


my $len = @ARGV;
if ($len == 0) {
    show_usage();
} else {
    if ($USE_OPT) {
        GetOptions(
            "start" => \&do_start,
            "status" => \&show_status,
            "stop" => \&do_stop,
            "help" => \&show_usage
        ) or show_usage();
    } else {
        my $cmd = $ARGV[0];
        if ($cmd eq "start") { do_start(); }
        elsif ($cmd eq "stop") { do_stop(); }
        elsif ($cmd eq "status") { show_status(); }
        else { show_usage(); }
    }
}


#
# 1 at the end of a module means that the module returns true to use/require statements. 
# It can be used to tell if module initialization is successful. 
# Otherwise, use/require will fail.
#
# 1;


sub show_usage {
    if ($USE_OPT) {
        print "Usage: sudo perl $0 --[start|stop|status|help]\n";
    } else {
        print "Usage: sudo $0 [start|stop|status]\n";
    }
    exit(0);
}


sub show_status {
    if (Proc::PID::File->running()) {
        print "daemon is running..\n";
    } else {
        print "daemon is stopped\n";
    }
}


sub do_stop {
    my $pid = Proc::PID::File->running();
    if ($pid == 0) {
        print "daemon is not running\n";
    } else {
        #print "stop daemon now ..\n";
        kill(9, $pid);
        print "daemon is stopped\n";
    }
    do_log("server is stopped");
}


sub do_start {
    print "start daemon now\n";

    Proc::Daemon::Init();

    if (Proc::PID::File->running()) {
        do_log( "A copy of this daemon is already running, exit" );
        exit(0);
    }

    do_log("server is started");

    my ($data, $fh, $data_len); 
    my $localhost = "0.0.0.0";
    my $localport = 9000;
    my $ipc_select = IO::Select->new();
    my $IPC_SOCKET = new IO::Socket::INET(
             Listen  => 5, LocalAddr => $localhost, LocalPort => $localport, Proto => "tcp" );

    $ipc_select->add($IPC_SOCKET);
    do_log( "Listening on [$IPC_SOCKET] $localhost:$localport ..." );
    while (1) {
      if (my @ready = $ipc_select->can_read(.01)) {
        foreach $fh (@ready) {
            if($fh == $IPC_SOCKET) {
                my $new = $IPC_SOCKET->accept;
                $ipc_select->add($new);
                do_log( "== incoming connection from [$fh] " . 
                        $new->peerhost() . ":" . $new->peerport() . " ...");
            } else {
                recv($fh, $data, 1024, 0);
                my $data_len = length($data);
                if ($data_len > 0) { # feedback to client.
                    print $fh http_response($data);
                }
                $ipc_select->remove($fh);
                $fh->close;
            }
        }
      }
    }
}



#
# Implements part of the HTTP protocal:
# - GET command
# - Status code: 200, 400, 404, 500
# - Customized command TEST, with status code -1.
#
# Reference: http://www.w3.org/Protocols/rfc2616/rfc2616.html
#
sub http_response {
    my ($request) = @_;

    my $status = 0;
    my $data = "";
    if ($request =~ m/^GET\s(\S+)\s/) {
        do_log("request file: $1");
        my $file = ($1 eq "/") ? "/index.html" : $1;  # default file under a directory.
        $file = uri_unescape($file); # url_decode() function. E.g. change %20 back to space.

        my $path = "$WWWROOT$file";
        if (-e $path) {
           my $open_ok = 1;
           open my $fh, '<', $path or $open_ok = 0; # die "error opening $path: $!";
           if ($open_ok == 1) {
               $data = do { local $/ = undef; <$fh> };
               $status = 200;
           } else {
               $data = "Internal Server Error";
               $status = 500;
           }
        }
        else { # file not found.
           $data = "Not Found";
           $status = 404;
        }
    } elsif ($request =~ m/^TEST\s/) {
        $status = -1; # for testing purpose of the Perl Web Server.
    } else { # bad request: unknown command.
        $data = "Bad Request";
        $status = 400;
    }


    my $response = "";
    if ($status == 200) {
        my $data_len = length($data);
        $response = "HTTP/1.1 200 OK\nContent-Type:text\nContent-Length:$data_len\n\n$data";
    }
    elsif ($status == 400 || $status == 404 || $status == 500) {
        my $body = "";
        my $data_len = length($body);
        $response = "HTTP/1.1 $status $data\nContent-Type:text\nContent-Length:$data_len\n\n$body";
    }
    else { # status == -1
        my $hdr = "PERL Web Server Received:\n";
        my $data_len = length($hdr) + length($request);
        $response = "HTTP/1.1 200 OK\nContent-Type:text\nContent-Length:$data_len\n\n$hdr$request";
    }

    return $response;
}


sub do_log {
    my ($msg) = @_;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    $year += 1900;
    $mon += 1;

    open FILE, ">>$LOG_FILE" or die "cannot open log file $!\n";
    print FILE "$year-$mon-$mday $hour:$min:$sec  $msg\n";
    close FILE;
}