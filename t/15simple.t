# Test our Log::Dispatch/Log::Dispatch::Config testing infrastructure
# Author: Olivier Mengué <dolmen@cpan.org>

use strict;
use warnings;
use Test::NoWarnings;
use Test::More tests => 20;

# Declare explicitely $TODO
# We won't be able to use $TODO in the usual style
# du to POE distribution of the code
our $TODO;

my @tests;

BEGIN {
    @tests = (
        { level => warning => message => '1. Warning' },
        { level => error => message => '2. Error' },
        { level => warning => message => '3. Warning' },
        { level => error => message => '4. Error', TODO => 'Fix this race case' },
        { level => critical => message => '5. Critical', TODO => 'Fix this race case' },
        { level => warning => message => '6. Warning' },
    );
}

use t::lib::Log::Dispatch::Config::Test \@tests;

use POE;
use POE::Component::Logger;

is $POE::Component::Logger::DefaultLevel, 'warning', 'DefaultLevel';

POE::Component::Logger->spawn(
    ConfigFile => t::lib::Log::Dispatch::Config::Test->configurator);

is $POE::Component::Logger::DefaultLevel, 'warning', 'DefaultLevel';

POE::Session->create(
    inline_states => {
        _start => sub {
            pass "_start";
            $poe_kernel->yield('evt1');
        },
        evt1 => sub {
            Logger->log({ level => warning => message => '1. Warning'});
            $poe_kernel->yield('evt2');
        },
        evt2 => sub {
            Logger->log({ level => error => message => '2. Error'});

            is $POE::Component::Logger::DefaultLevel, 'warning', 'DefaultLevel';
            # Log at default level
            Logger->log('3. Warning');
            $poe_kernel->yield('evt3');
        },
        evt3 => sub {
            # Set TODO "globally" until the next event
            # (where we explicitely undef it)
            $TODO = "Fix this race case";
            # The problem is that the DefaultLevel should be retrieved
            # synchronously at the Logger->log call instead of in the POE
            # event handler
            {
                local $POE::Component::Logger::DefaultLevel = 'error';
                Logger->log('4. Error');
                local $POE::Component::Logger::DefaultLevel = 'critical';
                Logger->log('5. Critical');
            }
            $poe_kernel->yield('evt4');
        },
        evt4 => sub {
            $TODO = undef;
            # We should be back at DefaultLevel
            is $POE::Component::Logger::DefaultLevel, 'warning', 'DefaultLevel';
            Logger->log('6. Warning');
        },
        _stop => sub {
            pass "_stop";
        },
    },
);

POE::Kernel->run;

pass "POE kernel shutdown";

# vim: set et ts=4 sw=4 sts=4 :
