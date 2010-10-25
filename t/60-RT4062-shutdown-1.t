# Author: Olivier Mengué <dolmen@cpan.org>

use strict;
use warnings;
use Test::NoWarnings;
use Test::More tests => 16;

my @tests;

BEGIN {
    @tests = (
        { level => warning => message => '1. Warning' },
        { level => warning => message => '2. Warning' },
        { level => warning => message => '3. Warning' },
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
            Logger->log({ level => warning => message => '1. Warning'});
            $poe_kernel->yield('evt1');
        },
        evt1 => sub {
            my ($kernel, $heap) = @_[KERNEL, HEAP];
            Logger->log({ level => warning => message => '2. Warning'});
            $kernel->post('logger', log => { level => warning => message => '3. Warning'});

            # Prepare data for the session end check
            my $s = $kernel->alias_resolve('logger');
            $s = (ref $s) ? $s->ID : $s;
            isnt $s, undef, "Session 'logger' check";
            $heap->{logger} = $s;

            $kernel->post(logger => 'shutdown');

            $kernel->yield('evt2');
            #$kernel->delay('evt2' => 1);
        },
        evt2 => sub {
            my ($kernel, $heap) = @_[KERNEL, HEAP];
            is $kernel->alias_resolve('logger'), undef, "logger session alias is now removed";
            # Session is not immediately stopped, but this should happen soon
            isnt $kernel->alias_resolve($heap->{logger}), undef, "logger session is not yet down";
            $kernel->yield('evt3');
        },
        evt3 => sub {
            my ($kernel, $heap) = @_[KERNEL, HEAP];
            is $kernel->alias_resolve($heap->{logger}), undef, "logger session is now down";
        },
        _stop => sub {
            pass "_stop";
        },
    },
);

POE::Kernel->run;

pass "POE kernel shutdown";

# vim: set et ts=4 sw=4 sts=4 :
