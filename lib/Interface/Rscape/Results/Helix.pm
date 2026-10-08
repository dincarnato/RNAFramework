package Interface::Rscape::Results::Helix;

use strict;
use Core::Mathematics;

use base qw(Data::Sequence::Structure::Helix);

sub new {
    
    my $class = shift;
    my %parameters = @_;
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ evalue  => undef,
                   pvalues => [] }, \%parameters);
    
    $self->_validate();
    
    return($self);
    
}

sub _validate {
    
    my $self = shift;

    $self->SUPER::_validate();

    $self->throw("E-value must be a value >= 0") if (defined $self->{evalue} && !ispositive($self->{evalue}));
    $self->throw("Number of p-values differs from number of pairs") if (@{$self->{pvalues}} && @{$self->{pvalues}} != @{$self->{h5bases}});

    for (@{$self->{pvalues}}) { $self->throw("P-values must be comprised between 0 and 1") if (!inrange($_, [0, 1])); }

}

sub evalue { return($_[0]->{evalue}); }

sub pvalues { return(wantarray() ? @{$_[0]->{pvalues}} : $_[0]->{pvalues}); }

1;