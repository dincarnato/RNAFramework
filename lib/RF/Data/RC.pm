package RF::Data::RC;

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
                   counts     => [],
                   coverage   => [],
                   readscount => 0 }, \%parameters);
    
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
    $self->throw("Base counts must be provided as an ARRAY reference") if (ref($self->{counts}) ne "ARRAY");
    $self->throw("Coverage must be provided as an ARRAY reference") if (ref($self->{coverage}) ne "ARRAY");
    $self->throw("Different number of elements for RT-stops and coverage arrays") if (@{$self->{counts}} != @{$self->{coverage}});
    $self->throw("Number of elements for RT-stops and coverage arrays differs from sequence length") if (@{$self->{counts}} != length($self->{sequence}));
    $self->throw("Transcript's mapped reads must be a positive integer") if (!isint($self->{readscount}));
    
}

sub id { return($_[0]->{id}); }

sub sequence { return($_[0]->{sequence}); }

sub counts { return(wantarray() ? @{$_[0]->{counts}} : $_[0]->{counts}); }

sub coverage { return(wantarray() ? @{$_[0]->{coverage}} : $_[0]->{coverage}); }

sub readscount { return($_[0]->{readscount}); }

sub meancoverage { return(mean(@{$_[0]->{coverage}})); }

sub mediancoverage { return(median(@{$_[0]->{coverage}})); }

sub length { return(length($_[0]->{sequence})); }

sub DESTROY {
    
    my $self = shift;
    
    delete($self->{sequence});
    delete($self->{counts});
    delete($self->{coverage});
    
}

1;
