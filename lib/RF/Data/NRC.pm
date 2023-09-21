package RF::Data::NRC;

use strict;
use Core::Mathematics qw(:all);
use Data::Sequence::Utils;

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ id         => undef,
                   sequence   => undef,
                   reactivity => [] }, \%parameters);

    if (defined $self->{sequence}) {

        # Fix sequence and remove degeneracy
        $self->{sequence} = uc(rna2dna($self->{sequence}));
        $self->{sequence} =~ s/[BDHKMRSVWY-]/N/gi;

    }

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("Sequence contains invalid characters") if (defined $self->{sequence} &&
                                                             !isna($self->{sequence}));
    $self->throw("Reactivity must be provided as an ARRAY reference") if (ref($self->{reactivity}) ne "ARRAY");

}

sub id { return($_[0]->{id}); }

sub sequence { return($_[0]->{sequence}); }

sub reactivity { return(wantarray() ? @{$_[0]->{reactivity}} : $_[0]->{reactivity}); }

sub length { return(length($_[0]->{sequence})); }

sub DESTROY {

    my $self = shift;

    delete($self->{sequence});
    delete($self->{reactivity});

}

1;
