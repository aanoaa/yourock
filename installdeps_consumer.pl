#!/usr/bin/env perl
use strict;
use warnings;
use Directory::Queue::Simple;
my $dirq = Directory::Queue::Simple->new(path => "/tmp/yourock/installdeps");
while (1) {
    for (my $name = $dirq->first(); $name; $name = $dirq->next()) {
        next unless $dirq->lock($name);
        my $dir = $dirq->get($name);
        next unless -f "$dir/Makefile.PL";
        install_modules($dir);
        $dirq->remove($name);
    }

    sleep(1);
}

sub install_modules {
    my $dir = shift;
    chdir $dir;
    my $makepl = "$dir/Makefile.PL";

    # app.status
    open my $status, '>', 'app.status';
    print $status 1;
    close $status;

    system "cpanm -L lib -n --installdeps .";

    # app.status
    unlink 'app.status';
}
