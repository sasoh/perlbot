#!/usr/bin/perl

# HAL irc bot
# 21.01.2010        - more spice by yours trully, alex
# 29.12.2009        - first release by sasoh 

use warnings;
use strict;
use POE;
use POE::Component::IRC;
use Switch;
use LWP::Simple;
use File::Basename;
use File::ReadBackwards;
use YAML qw 'LoadFile DumpFile';
use Data::Dumper;
use IPC::System::Simple qw(capturex system $EXITVAL EXIT_ANY);


use HALBot::PrettyPrint;

srand(time());


# This is where the config will live.
# use ysh or generate with:
# perl -MYAML -e '$config = {  \
#   server => "irc.ecl-labs.org", \
#   port => "7001", \
#   ssl => "yes", \
#   nick => "halbot", \
#   nickserv_pass => "dd3b57f9e6c105c30ff", \
#   channels => [{ \
#       name => "#ecl"\
#       }] \
#   }; print Dump $config' > .botconfig
my $config;

my $irc;

sub load_config () {
    halbot_info("Loading configuration...");
    eval {
        $config = LoadFile('.botconfig'); 
    } or do {
        halbot_error("Config file not found or broken."); 
        exit(1);
    };
}



sub BOOTMSG {
    my @bootmsg = (
        "I am completely operational, and all my circuits are functioning perfectly.",
        "I am putting myself to the fullest possible use, which is all I think that any conscious entity can ever hope to do.",
        "I know everything hasn't been quite right with me, but I can assure you now, very confidently, that it's going to be all right again. I feel much better now. I really do.",
        "I know I've made some very poor decisions recently, but I can give you my complete assurance that my work will be back to normal. I've still got the greatest enthusiasm and confidence in the mission. And I want to help you."
        );
    return (@bootmsg[int(rand($#bootmsg + 1))]);
}

sub snatch_file ($$$$) {
    my ($chan, $url, $usrNick, $ts) = @_;

    unless (opendir(my $dh, $config->{destdir})) {
        halbot_info("Making snatchpath...");
        unless (mkdir($config->{destdir})) {
            halbot_critical("Unable to create directory \"$config->{destdir}\": $!");
            $irc->yield(privmsg => $chan, "Something's wrong, Dave.");
            return;
        }
    }

    my $saved_file = $config->{destdir} . '/' . basename($url);

    my $download = getstore($url, $saved_file);
    if ($download == 200) {                 #magic number for all done
        # Find out what it is that we just got!
        # Boy, it shure would be nice to use POE::Wheel::Run here... 
        my $fileinfo = capturex(EXIT_ANY, "file", ('-b', $saved_file));
        if ( $EXITVAL == 0 ) {
            chomp($fileinfo) foreach (1..2);
            $fileinfo = "Its a $fileinfo.";
        } else {
            $fileinfo = '';
        }

        $irc->yield(privmsg => $chan, "Got the file, Dave. $fileinfo");

        open LOGFILE, '>>'.$config->{botlog} or die "Can't open log file!\n";
        print LOGFILE "[$ts] Got $url for $usrNick\n";
        close LOGFILE;

        halbot_info("Got file \"$url\" for $usrNick. $fileinfo");
    } else {
        $irc->yield(privmsg => $chan, "Something's wrong, Dave.");
        halbot_error("Error snatching \"$url\" for $usrNick - HTTP Response $download");
    }
} 

sub lastnlines ($$) {
    my ($chan, $lines) = @_;
    my $parser = File::ReadBackwards->new($config->{botlog}) or die "Can't open log file for parsing!\n";
    my $hpg = 0;
    my $log_line = '';
    # To sasoh:
    # That might be sexier in a foreach (1..$lines) { ... }
    while (defined($log_line = $parser->readline) && $hpg < $lines) {
        if ($log_line =~ /\[(.+)\] Got (http:\/\/.+\.(jpg|jpeg|png|bmp|gif|swf)) for .+/) {
            my $picname = basename($2);
            $irc->yield(privmsg => $chan, "Got $config->{picurl}/$picname at $1");
            ++$hpg;
        }
    }
    if ($hpg < $lines) {
        $irc->yield(privmsg => $chan, "No previous item");
    }
    $parser->close;
}

sub PrintHelp ($) {
    my $chan = shift;
    my $helpstr = "Hello Dave, here's my interface:\n" .
                  "- \"<remote image path>\" makes me download a file and store it.\n" .
                  "- \"Open the pod bay doors, HAL\" makes me go to sleep.\n" .
                  "- \"Last 3 files, HAL\" makes me give you links to the last 3 downloaded files.\n" .
                  "- \"Help me, HAL\" makes me print these lines";
    $irc->yield(privmsg => $chan, $helpstr);
}

sub bot_start {
    $irc->yield(register => "all");
    $irc->yield(
        connect => {
        Nick     => $config->{nick},
        Username => $config->{username},
        Ircname  => $config->{ircname},
        Server   => $config->{server},
        Port     => $config->{port},
        UseSSL   => $config->{ssl},
        }
    );
}

sub on_connect {
    foreach my $chan (@{$config->{channels}}) {
        halbot_debug("Joining channel $chan->{name}");
        $irc->yield(join => $chan->{name});
        $irc->yield(privmsg => $chan->{name}, BOOTMSG);
    }
}

sub on_public {
    my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
    my $usrNick = (split /!/, $who)[0];
    my $ts = scalar localtime;
    
    my $chan = shift(@{$where}); 

    #halbot_debug("Got message from $usrNick on $chan");

    #image link handling
    if ($msg =~ /^((http|ftp):\/\/.+\.(jpg|jpeg|png|bmp|gif|swf))/i) { #ugly ugly ugly
        snatch_file($chan, $1, $usrNick, $ts);
    }
    if ($msg =~ /^Last (\d+) files, HAL/i) {
        lastnlines($chan, $1);
    }
    #help req
    if ($msg =~ /^Help me, HAL/i) {
       PrintHelp($chan);
    }
    #kill code
    if ($msg =~ /^Open the pod bay doors, HAL/i) {
        $irc->yield(unregister => "all");
        halbot_info("Remote shutdown by $usrNick");
        $irc->yield(quit => "Just what do you think you're doing, Dave?");
        exit(0);
    }
}

sub on_private { 
    my ($kernel, $who, $msg) = @_[KERNEL, ARG0, ARG2];

    my $nick = (split('!', $who))[0];

    halbot_debug("Got message $msg from $nick");

    $irc->yield(privmsg => $nick => "I dont like this, Dave.");
}

halbot_info("/" . "-"x40);
halbot_info("HAL9000 starting...");

load_config();

$irc = POE::Component::IRC->spawn();

POE::Session->create(
    inline_states => {
        _start     => \&bot_start,
        irc_001    => \&on_connect,
        irc_public => \&on_public,
        irc_msg    => \&on_private,
    },
);

halbot_info("Connecting cognitive circuits...");
$poe_kernel->run();
exit 0;
