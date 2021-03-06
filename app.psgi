#!/usr/bin/env perl
use Mojolicious::Lite;
use File::Slurp;
use URI;
use Digest::SHA1 qw/sha1_hex/;
use File::Path qw/make_path rmtree/;
use Cwd;
use Directory::Queue::Simple;

# Documentation browser under "/perldoc"
plugin 'PODRenderer';

my $SERVICE_HOME = '/home/hshong/Desktop'; # will be changed
# my $SERVICE_HOME = '/home/apps/apps';
my $DOMAIN = 'http://%s.micro.jjang.info';
my %HOOK;

sub enqueue {
    my $message = shift;
    my $dirq = Directory::Queue::Simple->new(path => "/tmp/yourock/installdeps");
    my $name = $dirq->add($message);
}

sub installdeps {
    # producer
    my $dir = getcwd;
    enqueue($dir);
}

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
    'pull',
    sub {
        my ($uri, $digest) = @_;
        my $dir = getcwd;
        chdir "$SERVICE_HOME/gits/$digest";
        installdeps() if -f 'Makefile.PL';
        chdir $dir;
    }
);

on(
    'clone',
    sub {
        my ($uri, $digest) = @_;
        make_path("../logs/$digest");
        symlink '../master.ini', "../conf/$digest.ini";
        symlink "../gits/$digest/public", "../root/$digest";
        emit('pull', $uri, $digest);
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
    @files = grep { $_ !~ m/27d5f7c/ } @files;
    @files = map { {
        digest => $_,
        url => sprintf($DOMAIN, $_), 
        giturl => giturl($_),
    } } @files;
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
                emit('pull', $repo, $digest);
            }
        } else {
            if (!system("git clone $repo $digest")) {
                if (-d "$digest/public" && -f "$digest/app.psgi") {
                    emit('clone', $repo, $digest);
                } else {
                    rmtree("$digest");
                    $self->render('error');
                    return;
                }
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

sub giturl {
    my $c = read_file("$SERVICE_HOME/gits/$_[0]/.git/config");
    $c =~ m/url = (.+?)\n/s;
    return $1;
}

__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome uroku';
<h1>uroku</h1>

<form method="post" enctype="application/x-www-form-urlencoded" class="form-inline">
  <input type="text" name="repo" placeholder="git://github.com/<user>/<repo>.git"/>
  <input type="submit" class="btn btn-primary" value="create"/>
</form>

<ul>
  % for my $item (@$list) {
  <li>
    <a href="<%= $item->{url} %>"><%= $item->{url} %> - <%= $item->{giturl} %></a>
    <a href="/services/<%= $item->{digest} %>" class="btn btn-small delete">delete</a>
  </li>
  % }
</ul>

@@ error.html.ep
% layout 'default';
% title 'something wrong';

<h1>error occured</h1>
<div class="alert alert-error">failed to deploy testing</div>
<a href="/" class="btn">go back</a>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= title %></title>
    <link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.1.1/css/bootstrap-combined.min.css" rel="stylesheet">
    <script src="//cdnjs.cloudflare.com/ajax/libs/jquery/1.8.2/jquery.min.js"></script>
    <script src="//netdna.bootstrapcdn.com/twitter-bootstrap/2.1.1/js/bootstrap.min.js"></script>
    <script src="app.js"></script>
  </head>
  <body>
    <div class="container">
      <div class="row">
        <%= content %>
      </div>
    </div>
  </body>
</html>
