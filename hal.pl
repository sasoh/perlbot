#!/usr/bin/perl

# HAL irc bot
# 21.01.2010        - more spice by yours trully, alex
# 29.12.2009        - first release by sasoh 

use warnings;
use strict;
use POE;
use POE::Component::IRC;
use POE::Component::SSLify;

use YAML qw 'LoadFile DumpFile';
use Data::Dumper;

use Switch;
use LWP::Simple;
use IPC::System::Simple qw(capturex system $EXITVAL EXIT_ANY);

use File::Basename;
use DBI;
use DBD::SQLite;

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

my $usrsubs = {};

sub load_config () {
    halbot_info("Loading configuration...");
    eval {
        $config = LoadFile('.botconfig'); 
    } or do {
        halbot_error("Config file not found or broken."); 
        exit(1);
    };

    if (defined $ARGV[0]) {
        if ($ARGV[0] eq "-d") {
            print Dumper $config;
            exit(1);
        }
    }
}

my $dbh;
sub init_db () { 
    $dbh = DBI->connect("dbi:SQLite:dbname=". $config->{botdb},"","");

    unless ($dbh) {
        halbot_critical("Cannot open database at $config->{botdb}.");
        exit(1);
    }

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
        my $filetype = capturex(EXIT_ANY, "file", ('-b', $saved_file));
        my $fileinfo = '';
        if ( $EXITVAL == 0 ) {
            chomp($filetype) foreach (1..2);
            $fileinfo = "Its a $filetype.";
        }

        $irc->yield(privmsg => $chan, "Got the file, Dave. $fileinfo");

        # Stuff it into the DB
        my $sth = $dbh->prepare('INSERT INTO urls (nick, filename, filetype, source) VALUES (?,?,?,?)'); 
        $sth->execute($usrNick, basename($url), $filetype, $url);
    
        if ($dbh->err()) { 
            halbot_critical("Error inserting data into the database: $DBI::errstr"); 
            $irc->yield(shutdown => "SIGBUS");
        }

        halbot_info("Got file \"$url\" for $usrNick. $fileinfo");
    } else {
        $irc->yield(privmsg => $chan, "Something's wrong, Dave.");
        halbot_error("Error snatching \"$url\" for $usrNick - HTTP Response $download");
    }
} 

sub lastnlines ($$) {
    my ($chan, $lines) = @_;

    my $sth = $dbh->prepare('SELECT * FROM urls ORDER BY url_id DESC LIMIT ?;');
    
    $sth->execute($lines);

    if ($dbh->err()) { 
        halbot_critical("Error querying data from the database: $DBI::errstr"); 
        $irc->yield(shutdown => "SIGBUS");
    }

    while (my $url = $sth->fetchrow_hashref) {
        my $picname = basename($url->{source});
        $irc->yield(privmsg => $chan, "Got $config->{picurl}/$picname at $url->{timestamp}");
    }

}

sub PrintHelp ($) {
    my $chan = shift;
    my $helpstr = "Hello Dave, here's my interface:\n" .
                  "- \"<remote image path>\" makes me download a file and store it.\n" .
                  "- \"Open the pod bay doors, HAL\" makes me go to sleep.\n" .
                  "- \"Last n files, HAL\" makes me give you links to the last n downloaded files.\n" .
                  "- \"Help me, HAL\" makes me print these lines";
    $irc->yield(privmsg => $chan, $helpstr);
}

sub evalreq ($$$) {
    my ($chan, $nick, $expr) = @_;
    my $resp = eval($expr);
    if (!$resp) {
        $resp = $@ if !$resp;
        my $rowcount = scalar split /\n/, $resp;
        if ($rowcount > 2) {
            $irc->yield(privmsg => $nick => $resp);
        } else {
            $irc->yield(privmsg => $chan, $resp);
        }
    } else {
        my $rowcount = scalar split /\n/, $resp;
        if ($rowcount > 3) {
            $irc->yield(privmsg => $nick => $resp);
        } else {
            $irc->yield(privmsg => $chan, $resp);
        }
    }
}

sub intsig {
    $irc->yield(shutdown => "Just what do you think you're doing, Dave?");
}

sub addsub ($$$$) {
    my ($chan, $nick, $subname, $subval) = @_;
    $usrsubs->{$subname} = eval $subval;
}

sub execsub ($$$) {
    my ($chan, $nick, $subname) = @_;
    my $subval = $usrsubs->{$subname};
    if ($subval) {
        $irc->yield(privmsg => $chan, $subval->());
    }
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
    #eval func
    if ($msg =~ /^$config->{nick}, eval (.+)/i) {
        evalreq($chan, $usrNick, $1);
    }
    #addsub
    if ($msg =~ /^$config->{nick}, addsub (.+), (.+)/i) {
        addsub($chan, $usrNick, $1, $2);
    }
    #exec sub
    if ($msg =~ /^$config->{nick}, (.+)/i) {
        execsub($chan, $usrNick, $1);
    }
    #madurgi!
    #kill code
    if ($msg =~ /^Open the pod bay doors, HAL/i) {
        halbot_info("Remote shutdown by $usrNick");
        $irc->yield(shutdown => "Just what do you think you're doing, Dave?");
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

init_db();

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
$SIG{INT} = \&intsig;
$SIG{TERM} = \&intsig;
$poe_kernel->run();
exit 0;
