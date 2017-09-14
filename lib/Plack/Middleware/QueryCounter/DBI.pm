package Plack::Middleware::QueryCounter::DBI;
use strict;
use warnings;
use utf8;

use parent 'Plack::Middleware';
use DBIx::Tracer;

use Plack::Util::Accessor qw/prefix/;

sub prepare_app {
    my $self = shift;

    $self->{__prefix} = $self->prefix || 'X-QueryCounter-DBI';
}

sub call {
    my ($self, $env) = @_;

    my $stats = {
        total => 0,
        read  => 0,
        write => 0,
        other => 0,
    };

    my $tracer = DBIx::Tracer->new(
        sub{
            my %args = @_;
            _callback(\%args, $stats);
        }
    );
    my $res = $self->app->($env);

    # add header to response
    return Plack::Util::response_cb($res, sub {
        my $res = shift;
        Plack::Util::header_set($res->[1], $self->{__prefix} . '-Total', $stats->{total});
        Plack::Util::header_set($res->[1], $self->{__prefix} . '-Read',  $stats->{read});
        Plack::Util::header_set($res->[1], $self->{__prefix} . '-Write', $stats->{write});
        Plack::Util::header_set($res->[1], $self->{__prefix} . '-Other', $stats->{other});
    });
}

sub _callback {
    my ($args, $stats) = @_;
    my $inputs = $args->{sql};
    $inputs =~ s{/\*(.*)\*/}{}g;

    my @sqls = split /;/, $inputs;

    for my $sql (@sqls) {
        $sql =~ s/^\s*(.*?)\s*$/$1/;
        $stats->{total}++;

        if ($sql =~ /^SELECT/i) {
            $stats->{read}++;
        } elsif ($sql =~ /^(INSERT|UPDATE|DELETE)/i) {
            $stats->{write}++;
        } else {
            $stats->{other}++;
        }
    }
}

1;

__END__

=head1 NAME

Plack::Middleware::QueryCounter::DBI - DBI query counter per request middleware

=head1 SYNOPSIS

Enable this middleware using Plack::Builder.

    use Plack::Builder;

    my $app = MyApp->psgi_app;

    builder {
        enable 'QueryCounter::DBI';
        $app;
    };


=head1 DESCRIPTION

=cut

