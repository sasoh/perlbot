#!/usr/bin/perl

# HAL irc bot
# 29.12.2009        - first release by sasoh 

use warnings;
use strict;
use POE;
use POE::Component::IRC;
use Switch;
use LWP::Simple;
use File::Basename;
use File::ReadBackwards;

srand(time());

my $irc = POE::Component::IRC->spawn();
my $destdir = "/home/sasoh/public_html/pile/"; #im too lousy at perl :(
#my $destdir = "./public_html/pile/"; #local test path

sub CHANNEL { "#foo" }

sub BOOTMSG {
    my $seed = int(rand(2)) + 1;
    switch ($seed) {
        case 1 {
            return "I am completely operational, and all my circuits are functioning perfectly."
        }
        case 2 {
           return "I am putting myself to the fullest possible use, which is all I think that any conscious entity can ever hope to do."
        }
        case 3 {
            return "I know everything hasn't been quite right with me, but I can assure you now, very confidently, that it's going to be all right again. I feel much better now. I really do."
        }
    }
}

sub LinkDetected {
    my ($file, $usrNick, $ts) = @_;
    my $download = getstore($file, $destdir . basename($file));
    if ($download == 200) { #magic number for all done
        $irc->yield(privmsg => CHANNEL, "Got the file, Dave.");
        open LOGFILE, '>>botlog.txt' or die "Can't open log file!\n";
        print LOGFILE "[$ts] Got $file for $usrNick\n";
        close LOGFILE;
    } else {
        $irc->yield(privmsg => CHANNEL, "Something's wrong, Dave.");
    }
} 

sub Last3Lines {
    my $parser = File::ReadBackwards->new('botlog.txt') or die "Can't open log file for parsing!\n";
    my $hpg = 0;
    my $log_line = '';
    while (defined($log_line = $parser->readline) && $hpg < 3) {
        if ($log_line =~ /\[(.+)\] Got (http:\/\/.+\.(jpg|jpeg|png|bmp|gif|swf)) for .+/) {
            my $picname = basename($2);
            $irc->yield(privmsg => CHANNEL, "Got http://vanity.ecl-labs.org/~sasoh/pile/$picname at $1");
            ++$hpg;
        }
    }
    if ($hpg < 3) {
        $irc->yield(privmsg => CHANNEL, "No previous item");
    }
    $parser->close;
}

sub PrintHelp {
    my $helpstr = "Hello Dave, here's my interface:\n" .
                  "- \"<remote image path>\" makes me download a file and store it.\n" .
                  "- \"Open the pod bay doors, HAL\" makes me go to sleep.\n" .
                  "- \"Last 3 files, HAL\" makes me give you links to the last 3 downloaded files.\n" .
                  "- \"Help me, HAL\" makes me print these lines";
    $irc->yield(privmsg => CHANNEL, $helpstr);
}

POE::Session->create(
    inline_states => {
        _start     => \&bot_start,
        irc_001    => \&on_connect,
        irc_public => \&on_public,
    },
);

sub bot_start {
    $irc->yield(register => "all");
    my $nick = 'HAL900' . int(rand(2));
    $irc->yield(
        connect => {
        Nick     => $nick,
        Username => 'computer',
        Ircname  => 'Hello, Dave',
        Server   => 'irc.ecl-labs.org',
        Port     => '7001',
        UseSSL   => '1',
        }
    );
}

sub on_connect {
    $irc->yield(join => CHANNEL);
    $irc->yield(privmsg => CHANNEL, BOOTMSG);
}

sub on_public {
    my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
    my $usrNick    = (split /!/, $who)[0];
    my $ts      = scalar localtime;
    #image link handling
    if ($msg =~ /^((http|ftp):\/\/.+\.(jpg|jpeg|png|bmp|gif|swf))/i) { #ugly ugly ugly
        &LinkDetected($1, $usrNick, $ts);
    }
    if ($msg =~ /^Last 3 files, HAL/i) {
        &Last3Lines;
    }
    #help req
    if ($msg =~ /^Help me, HAL/i) {
       &PrintHelp;
    }
    #kill code
    if ($msg =~ /^Open the pod bay doors, HAL/i) {
        $irc->yield(privmsg => CHANNEL, "Just what do you think you're doing, Dave?");
        $irc->yield(unregister => "all");
        open LOGFILE, '>>botlog.txt' or die "Can't open log file!\n";
        print LOGFILE "[$ts] Remote shutdown by $usrNick\n";
        close LOGFILE;
        exit;
    }
}

$poe_kernel->run();
exit 0;
