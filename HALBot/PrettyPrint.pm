package HALBot::PrettyPrint;
# This makes pretty prints 

use POSIX;
use warnings;
use strict;

require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
$VERSION = '0.01';

# Export to the target namespace:
@ISA = qw(Exporter);
@EXPORT = ('halbot_warning', 'halbot_critical', 'halbot_error', 'halbot_debug', 'halbot_info');


sub halbot_warning {
    my $time = strftime("%a %b %e %H:%M:%S", localtime);
    my $caller;
        no warnings;
        $caller = (split("::",(caller(1))[3]))[-1];
        use warnings;
    if ($caller) { if ($caller eq '__ANON__') { $caller = '' } } 
    print STDERR ("WARNING ($time)" .
            ($caller ?  ': '.$caller.': ' : ': '));
    foreach (@_) {print STDERR};
    print("\n");
}


sub halbot_critical {
    my $time = strftime("%a %b %e %H:%M:%S", localtime);
    my $caller;
        no warnings;
        $caller = (split("::",(caller(1))[3]))[-1];
        use warnings;
    if ($caller) { if ($caller eq '__ANON__') { $caller = '' } } 
    print STDERR ("CRITICAL ($time)" .
            ($caller ?  ': '.$caller.': ' : ': '));
    foreach (@_) {print STDERR};
    print("\n");
}

sub halbot_error {
    my $time = strftime("%a %b %e %H:%M:%S", localtime);
    my $caller;
        no warnings;
        $caller = (split("::",(caller(1))[3]))[-1];
        use warnings;
    if ($caller) { if ($caller eq '__ANON__') { $caller = '' } } 
    print STDERR ("ERROR ($time)" . ($caller ?  ': '.$caller.': ' : ': '));
    foreach (@_) {print STDERR};
    print STDERR ("\n");
}

sub halbot_debug {
    my $time = strftime("%a %b %e %H:%M:%S", localtime);
    my $caller;
        no warnings;
        $caller = (split("::",(caller(1))[3]))[-1];
        use warnings;
    if ($caller) { if ($caller eq '__ANON__') { $caller = '' } }
    print("DEBUG ($time)" . ($caller ?  ': '.$caller.': ' : ': '));
    foreach (@_) {print};
    print("\n");
}

sub halbot_info {
    my $time = strftime("%a %b %e %H:%M:%S", localtime);
    print("INFO  ($time): ");
    foreach (@_) {print};
    print("\n");
}

1;
