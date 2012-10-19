#!/usr/bin/env perl
use Mojolicious::Lite;
use File::Slurp;
use URI;
use Digest::SHA1 qw/sha1_hex/;
use File::Path qw/make_path rmtree/;
use Cwd;

# Documentation browser under "/perldoc"
plugin 'PODRenderer';

# my $SERVICE_HOME = '/home/hshong/Desktop'; # will be changed
my $SERVICE_HOME = '/home/p5/site/micro.jjang.info';
my $DOMAIN = 'http://%s.micro.jjang.info';
my %HOOK;

sub on {
    my ($name, $callback) = @_;
    push @{ $HOOK{$name} ||= [] }, $callback;
}

sub emit {
    my ($name, @args) = @_;
    if ($HOOK{$name}) {
        for my $hook (@{ $HOOK{$name} }) {
            $hook->(@args);
        }
    }
}

sub del_service {
    my $digest = shift;
    my $dir = getcwd;
    chdir "$SERVICE_HOME";
    unlink "conf/$digest.ini", "root/$digest";
    rmtree("logs/$digest");
    rmtree("gits/$digest");
    chdir $dir;
}

on(
    'on_pull',
    sub {
        my ($uri, $digest) = @_;
    }
);

on(
    'on_clone',
    sub {
        my ($uri, $digest) = @_;
        make_path("../logs/$digest");
        symlink '../master.ini', "../conf/$digest.ini";
        symlink "../gits/$digest/public", "../root/$digest";
    }
);

sub check_uri {
    my $repo = shift;
    my $uri = URI->new($repo);    # git://github.com/aanoaa/Hubot-Scripts-standup.git
    if ($uri->scheme ne 'git') {
        print STDERR "only permit git scheme: $uri\n";
        return;
    }

    if ($uri->opaque !~ m/github\.com/) {
        print STDERR "only permit github domain: $uri\n";
        return;
    }

    return 1;
}

get '/' => sub {
    my $self = shift;
    my @files = grep { -d "$SERVICE_HOME/gits/$_" } read_dir("$SERVICE_HOME/gits");
    @files = map { { digest => $_, url => sprintf($DOMAIN, $_) } } @files;
    $self->stash(list => \@files);
    $self->render('index');
};

post '/' => sub {
    my $self = shift;
    my $repo = $self->param('repo');
    if (check_uri($repo)) {
        my $digest = substr(sha1_hex($repo), 0, 7);
        my $dir = getcwd;
        chdir "$SERVICE_HOME/gits";
        if (-d $digest) {
            if (!system("git pull")) {
                emit('on_pull', $repo, $digest);
            }
        } else {
            if (!system("git clone $repo $digest")) {
                emit('on_clone', $repo, $digest);
            }
        }
        chdir $dir;
    }

    $self->redirect_to('/');
};

del '/services/:digest' => sub {
    my $self = shift;
    my $digest = $self->param('digest');
    del_service($digest);
    $self->render_json({});
};

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
<h1>uroku</h1>
<p>yuni roku</p>

<form method="post" enctype="application/x-www-form-urlencoded">
  <input type="text" name="repo"/>
  <input type="submit" value="create"/>
</form>

<ul>
  % for my $item (@$list) {
  <li>
    <a href="<%= $item->{url} %>"><%= $item->{url} %></a>
    <a href="/services/<%= $item->{digest} %>" class="button delete">delete</a>
  </li>
  % }
</ul>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= title %></title>
    <script src="//cdnjs.cloudflare.com/ajax/libs/jquery/1.8.2/jquery.min.js"></script>
    <script src="app.js"></script>
  </head>
  <body>
    <%= content %>
  </body>
</html>
