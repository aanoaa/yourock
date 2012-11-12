#!/usr/bin/env perl
use strict;
use warnings;
use Directory::Queue::Simple;
my $dirq = Directory::Queue::Simple->new(path => "/tmp/yourock/installdeps");
while (1) {
    for (my $name = $dirq->first(); $name; $name = $dirq->next()) {
        next unless $dirq->lock($name);
        my $dir = $dirq->get($name);
        print "get [$dir]\n";
        next unless -f "$dir/Makefile.PL";
        print "found Makefile.PL install_modules\n";
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
    print "made [app.status]\n";
    print $status 1;
    close $status;

    print "fetching [cpanm -L lib -n --installdeps .]\n";
    system "cpanm -L lib -n --installdeps .";

    # app.status
    unlink 'app.status';
    print "unlink [app.status]\n";
}
