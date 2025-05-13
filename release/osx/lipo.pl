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

sub setDir ($)
{
    my ($dir) = @_;
    print "> cd ${dir}\n";
    chdir $dir;
}

my @libs = `cd x64/lib; ls *.a`;

execute ("rm -rf universal");
execute ("mkdir -p universal/lib");
execute ("mkdir -p universal/lib/debug");
execute ("mkdir -p universal/lib/release");
execute ("cp -r arm64/include universal");
execute ("cp -r arm64/share universal");
execute ("cp -r arm64/cmake_platforms universal");
execute ("echo avoid missing path warning >universal/lib/debug/dummy.txt");
execute ("echo avoid missing path warning >universal/lib/release/dummy.txt");

foreach my $lib (@libs)
{
    chomp ($lib);
    execute ("lipo -create x64/lib/${lib} arm64/lib/${lib} -output universal/lib/${lib}");
}
