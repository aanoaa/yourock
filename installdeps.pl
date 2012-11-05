#!/usr/bin/env perl
use strict;
use Net::RabbitMQ;

## RabbitMQ configuration
my $CHANNEL     = 1;
my $QUEUE       = 'yourock.installdeps.q';
my $EXCHANGE    = 'yourock.installdeps.x';
my $ROUTING_KEY = 'foobar'; # What?

my $mq = Net::RabbitMQ->new();
$mq->connect("localhost", { user => "guest", password => "guest" });
$mq->channel_open($CHANNEL);
$mq->exchange_declare($CHANNEL, $EXCHANGE, { auto_delete => 0 });
$mq->queue_declare($CHANNEL, $QUEUE, { auto_delete => 0 });
$mq->queue_bind($CHANNEL, $QUEUE, $EXCHANGE, $ROUTING_KEY);

while (1) {
    sleep(1);
    my $msg = $mq->get($CHANNEL, $QUEUE) or next;
    my $dir = $msg->{body};
    next unless -f "$dir/Makefile.PL";
    install_modules($dir);
}

sub install_modules {
    my $dir = shift;
    chdir $dir;
    my $makepl = "$dir/Makefile.PL";

    # app.status
    open my $status, '>', 'app.status';
    print $status 1;
    close $status;

    system "cpanm -L extlib -n --installdeps .";

    # app.status
    unlink 'app.status';
}
