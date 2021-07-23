package Align::Alignment;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;
use Data::Sequence::Utils;

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ reference  => undef,
                   query      => undef,
                   alignment  => undef,
                   score      => undef,
                   refStart   => undef,
                   refEnd     => undef,
                   queryStart => undef,
                   queryEnd   => undef }, \%parameters);

    return($self);

}

sub reference {

    my $self = shift;
    my $reference = shift if (@_);

    $self->{reference} = uc($reference) if (isseq($reference, "-"));

    return($self->{reference});

}

sub query {

    my $self = shift;
    my $query = shift if (@_);

    $self->{query} = uc($query) if (isseq($query, "-"));

    return($self->{query});

}

sub alignment {

    my $self = shift;
    my $alignment = shift if (@_);

    $self->{alignment} = uc($alignment) if (isseq($alignment, "-"));

    return($self->{alignment});

}

sub score {

    my $self = shift;
    my $score = shift if (@_);

    $self->{score} = $score if (isnumeric($score));

    return($self->{score});

}

sub refStart { return($_[0]->{refStart}); }

sub refEnd { return($_[0]->{refEnd}); }

sub queryStart { return($_[0]->{queryStart}); }

sub queryEnd { return($_[0]->{queryEnd}); }

1;
