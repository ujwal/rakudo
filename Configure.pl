#! perl
# Copyright (C) 2009 The Perl Foundation

use strict;
use warnings;
use 5.008;

MAIN: {
    my %valid_options = (
        'help'          => 'Display configuration help',
        'parrot-config' => 'Use configuration given by parrot_config binary',
        'gen-parrot'    => 'Automatically retrieve and build Parrot',
    );

    # Get any options from the command line
    my %options = get_command_options( \%valid_options );

    # Print help if it's requested
    if ($options{'help'}) {
        print_help();
        exit(0);
    }

    # Update/generate parrot build if needed
    if ($options{'gen-parrot'}) {
        system("$^X build/gen_parrot.pl");
    }

    # Get a list of parrot-configs to invoke.
    my @parrot_config_exe = qw(
        parrot/parrot_config
        ../../parrot_config
        parrot_config
    );

    if ($options{'parrot-config'} && $options{'parrot-config'} ne '1') {
        @parrot_config_exe = ($options{'parrot-config'});
    }

    #  Get configuration information from parrot_config
    my %config = read_parrot_config(@parrot_config_exe);
    unless (%config) {
        die <<'END';
Unable to locate parrot_config.
To automatically checkout (svn) and build a copy of parrot,
try re-running Configure.pl with the '--gen-parrot' option.
Or, use the '--parrot-config' option to explicitly specify
the location of parrot_config.
END
    }

#  Create the Makefile using the information we just got
    create_makefile(%config);

    my $make = $config{'make'};
    print <<"END";

You can now use '$make' to build Rakudo Perl.
After that, you can use '$make test' to run some local tests,
or '$make spectest' to check out (via svn) a copy of the Perl 6
official test suite and run its tests.

END
    exit 0;

}


#  Process command line arguments into a hash.
sub get_command_options {
    my $valid_options = shift;

    my %options = ();
    for my $arg (@ARGV) {
        if ($arg =~ /^--(\w[-\w]*)(?:=(.*))?/ && $valid_options->{$1}) {
            my ($key, $value) = ($1, $2);
            $value = 1 unless defined $value;
            $options{$key} = $value;
            next;
        }
        die qq/Invalid option "$arg".  See "perl Configure.pl --help" for valid options.\n/;
    }
    return %options;
}


sub read_parrot_config {
    my @parrot_config_exe = @_;
    my %config = ();
    for my $exe (@parrot_config_exe) {
        no warnings;
        if (open my $PARROT_CONFIG, '-|', "$exe --dump") {
            print "Reading configuration information from $exe\n";
            while (<$PARROT_CONFIG>) {
                if (/(\w+) => '(.*)'/) { $config{$1} = $2 }
            }
            close $PARROT_CONFIG or die $!;
            last if %config;
        }
    }
    return %config;
}


#  Generate a Makefile from a configuration
sub create_makefile {
    my %config = @_;

    my $maketext = slurp( 'build/Makefile.in' );

    $config{'win32_libparrot_copy'} = $^O eq 'MSWin32' ? 'copy $(BUILD_DIR)\libparrot.dll .' : '';
    $maketext =~ s/@(\w+)@/$config{$1}/g;
    if ($^O eq 'MSWin32') {
        $maketext =~ s{/}{\\}g;
        $maketext =~ s{http:\S+}{ do {my $t = $&; $t =~ s'\\'/'g; $t} }eg;
    }

    my $outfile = 'Makefile';
    print "Creating $outfile\n";
    open(my $MAKEOUT, '>', $outfile) ||
        die "Unable to write $outfile\n";
    print {$MAKEOUT} $maketext;
    close $MAKEOUT or die $!;

    return;
}

sub slurp {
    my $filename = shift;

    open my $fh, '<', $filename or die "Unable to read $filename\n";
    local $/ = undef;
    my $maketext = <$fh>;
    close $fh or die $!;

    return $maketext;
}


#  Print some help text.
sub print_help {
    print <<'END';
Configure.pl - Rakudo Configure

General Options:
    --help             Show this text
    --gen-parrot       Download and build a copy of Parrot to use
    --parrot-config=(config)
                       Use configuration information from config

END

    return;
}

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
