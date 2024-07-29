#! /usr/bin/perl

use strict;

sub execute ($)
{
    my ($command) = @_;
    print "> $command\n";
    if (system ($command) != 0)
    {
        die "command failed";
    }
}

execute ("rm -rf x64/lib-static");
execute ("rm -rf x64/lib-static-debug");
execute ("mv ../win-static/x64/lib x64/lib-static");
execute ("mv ../win-static-debug/x64/lib x64/lib-static-debug");
