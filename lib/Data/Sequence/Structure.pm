package Data::Sequence::Structure;

use strict;
use Core::Mathematics;
use Core::Utils;
use Data::Sequence::Structure::Helix;
use Data::Sequence::Utils;
use RNA::Utils;

use base qw(Data::Sequence);

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    $parameters{type} = "RNA";

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ structure         => undef,
                   mea               => undef,
                   energy            => 0,
                   pseudoknots       => 0,
                   noncanonical      => 0,
                   lonelypairs       => 0,
                   sci               => undef,
                   ensembleDiversity => undef,
                   bpprobabilities   => {},
                   basepairs         => [],
                   _ncpairs          => [],
                   _pkpairs          => [],
                   _lonelypairs      => [],
                   _helices          => [],
                   _pkhelices        => [] }, \%parameters);

    $self->_validate();
    $self->_fixproperties();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->SUPER::_validate();

    $self->throw("Energy value must be REAL") if (!isreal($self->{energy}));
    $self->throw("Pseudoknots parameter must be BOOL") if (!isbool($self->{pseudoknots}));
    $self->throw("Non canonical parameter must be BOOL") if (!isbool($self->{noncanonical}));
    $self->throw("Lonely pairs parameter must be BOOL") if (!isbool($self->{lonelypairs}));
    $self->throw("Sequence and structure have different lengths") if (defined $self->{sequence} &&
                                                                      defined $self->{structure} &&
                                                                      length($self->{sequence}) != length($self->{structure}));
    $self->throw("Sequence and MEA structure have different lengths") if (defined $self->{sequence} &&
                                                                          defined $self->{mea} &&
                                                                          length($self->{sequence}) != length($self->{mea}));
    $self->throw("Invalid dot-bracket structure") if (defined $self->{structure} &&
                                                      !isdotbracket($self->{structure}));
    $self->throw("Invalid dot-bracket MEA structure") if (defined $self->{mea} &&
                                                          !isdotbracket($self->{mea}));
    $self->throw("Base pairs must be a bidimensional ARRAY reference") if (ref($self->{basepairs}) ne "ARRAY");

    my $length = length($self->{sequence});

    for (@{$self->{basepairs}}) {

        $self->throw("Base pair is not an ARRAY reference") if (ref($_) ne "ARRAY");
        $self->throw("Base pair ARRAY reference must contain 2 elements") if (@{$_} != 2);

        foreach my $i (@{$_}) {

            $self->throw("Base index must be a positive integer") if (!isint($i) ||
                                                                      !ispositive($i));
            $self->throw("Base index cannot exceed sequence's length") if ($i + 1 > $length);

        }

    }

    for (@{$self->{_pkpairs}}) {

        $self->throw("Pseudoknotted pair is not an ARRAY reference") if (ref($_) ne "ARRAY");
        $self->throw("Pseudoknotted pair ARRAY reference must contain 2 elements") if (@{$_} != 2);

        foreach my $i (@{$_}) {

            $self->throw("Pseudoknotted base index must be a positive integer") if (!isint($i) ||
                                                                                    !ispositive($i));
            $self->throw("Pseudoknotted base index cannot exceed sequence's length") if ($i + 1 > $length);

        }

    }

}

sub _fixproperties {

    my $self = shift;

    $self->{sequence} = dna2rna($self->{sequence}) if (isna($self->{sequence}));
    $self->{type} = "RNA";

    $self->SUPER::_fixproperties();

    if (@{$self->{basepairs}} ||
        defined $self->{structure}) {

        ($self->{basepairs}, $self->{_ncpairs}) = rmnoncanonical($self->{sequence}, (@{$self->{basepairs}} ? $self->{basepairs} : $self->{structure}));

        if ($self->{noncanonical}) { @{$self->{basepairs}} = (@{$self->{basepairs}}, @{$self->{_ncpairs}}); }
        else {

            # This part speeds-up things with very long structures
            # for which a dot-bracket structure has been provided
            if (defined $self->{structure}) {

                my @structure = split(//, $self->{structure});
                @structure[map { @{$_} } @{$self->{_ncpairs}}] = (".") x (2 * @{$self->{_ncpairs}});
                $self->{structure} = join("", @structure);

            }

        }

        ($self->{structure}, $self->{_pkpairs}) = rmpseudoknots($self->{sequence}, defined $self->{structure} ? $self->{structure} : $self->{basepairs});

        if ($self->{pseudoknots}) { # Pseudoknots allowed

            my (@pkchars, @structure);
            @structure = split(//, $self->{structure});
            @pkchars = (([qw({ })], [qw(< >)]), (map { [uc($_), $_] } ("a" .. "z")));

            # This step recursively calls the rmpseudoknots routine while incompatible pseudoknot helices are detected
            my $pkpairs = (rmpseudoknots($self->{sequence}, $self->{_pkpairs}))[1];

            while (@{$pkpairs}) {

                if (!@pkchars) {

                    $self->warn("Structure topology is too complex, unable to add all pseudoknots");

                    last;

                }

                my $chars = shift(@pkchars);

                for (@{$pkpairs}) {

                    $structure[$_->[0]] = $chars->[0];
                    $structure[$_->[1]] = $chars->[1];

                }

                $pkpairs = (rmpseudoknots($self->{sequence}, $pkpairs))[1];

            }

            for (@{$self->{_pkpairs}}) {

                $structure[$_->[0]] = "[" if ($structure[$_->[0]] eq ".");
                $structure[$_->[1]] = "]" if ($structure[$_->[1]] eq ".");

            }

            $self->{structure} = join("", @structure);

        }

        $self->throw("Unbalanced base-pairs in structure") if (!isdbbalanced($self->{structure}));

        $self->{basepairs} = [ listpairs($self->{structure}) ] if (defined $self->{structure} &&
                                                                   !@{$self->{basepairs}});

        if (!$self->{lonelypairs}) { # Lonely basepairs not allowed

            my ($helices, $pkhelices, @db, @basepairs, @pkpairs);
            ($helices, $pkhelices) = listhelices($self->{structure}, 1);
            @db = split(//, $self->{structure});

            for (@{$helices}) {

                if (@{$_->{h5bases}} == 1) {

                    $db[$_->{h5bases}->[0]] = ".";
                    $db[$_->{h3bases}->[0]] = ".";
                    push(@{$self->{_lonelypairs}}, [$_->{h5bases}->[0], $_->{h3bases}->[0]]);

                }
                else {

                    push(@{$self->{_helices}}, Data::Sequence::Structure::Helix->new(%{$_}));
                    @basepairs = (@basepairs, $self->{_helices}->[-1]->basepairs());

                }

            }

            for (@{$pkhelices}) {

                if (@{$_->{h5bases}} == 1) {

                    $db[$_->{h5bases}->[0]] = ".";
                    $db[$_->{h3bases}->[0]] = ".";
                    push(@{$self->{_lonelypairs}}, [$_->{h5bases}->[0], $_->{h3bases}->[0]]);

                }
                else {

                    push(@{$self->{_pkhelices}}, Data::Sequence::Structure::Helix->new(%{$_}));
                    @pkpairs = (@pkpairs, $self->{_pkhelices}->[-1]->basepairs());

                }

            }

            $self->{structure} = join("", @db);
            $self->{basepairs} = \@basepairs;
            $self->{_pkpairs} = \@pkpairs;

        }

    }
    else { $self->{structure} = "." x length($self->{sequence}); }

}

sub structure {

    my $self = shift;

    return($self->{structure});

}

sub ensembleDiversity {

    my $self = shift;

    return($self->{ensembleDiversity});

}

sub mea {

    my $self = shift;

    return($self->{mea});

}

sub basepairs {

    my $self = shift;

    return(wantarray() ? @{$self->{basepairs}} : $self->{basepairs});

}

sub bpprobability {

    my $self = shift;
    my ($base1, $base2) = sort {$a <=> $b} @_ if (@_);

    if (defined $base1) {

        $self->throw("Start base must be numeric") if (!isnumeric($base1));

        if (defined $base2) {

            $self->throw("End base must be numeric") if (!isnumeric($base2));

            if (exists $self->{bpprobabilities}->{$base1}->{$base2}) { return($self->{bpprobabilities}->{$base1}->{$base2}); }
            else { return(0); }

        }
        else {

            my @probs = map { [$_, $self->{bpprobabilities}->{$base1}->{$_}] } keys %{$self->{bpprobabilities}->{$base1}};

            return(wantarray() ? @probs : \@probs);

        }

    }
    else { return(wantarray() ? %{$self->{bpprobabilities}} : $self->{bpprobabilities}); }

}

sub pkpairs {

    my $self = shift;

    return(wantarray() ? @{$self->{_pkpairs}} : $self->{_pkpairs});

}

sub energy {

    my $self = shift;
    my $energy = shift if (@_);

    $self->{energy} = $energy if (isreal($energy));

    return($self->{energy});

}

sub sci {

    my $self = shift;
    my $sci = shift if (@_);

    $self->{sci} = $sci if (isreal($sci));

    return($self->{sci});

}

sub helices {

    my $self = shift;
    my $split = shift if (@_);

    if (!@{$self->{_helices}}) {

        if (@{$self->{basepairs}}) {

            my ($helices, $pkhelices) = listhelices($self->{structure}, $self->{lonelypairs});

            push(@{$self->{_helices}}, Data::Sequence::Structure::Helix->new(%{$_})) for (@{$helices});
            push(@{$self->{_pkhelices}}, Data::Sequence::Structure::Helix->new(%{$_})) for (@{$pkhelices});

        }


    }

    return(wantarray() ? @{$self->{_helices}} : $self->{_helices});

}

sub pkhelices {

    my $self = shift;

    if (!@{$self->{_pkhelices}}) {

        if (@{$self->{basepairs}}) {

            my ($helices, $pkhelices) = listhelices($self->{structure}, $self->{lonelypairs});

            push(@{$self->{_helices}}, Data::Sequence::Structure::Helix->new(%{$_})) for (@{$helices});
            push(@{$self->{_pkhelices}}, Data::Sequence::Structure::Helix->new(%{$_})) for (@{$pkhelices});

        }


    }

    return(wantarray() ? @{$self->{_pkhelices}} : $self->{_pkhelices});

}

sub DESTROY {

    my $self = shift;

    delete($self->{structure});

    $self->SUPER::DESTROY();

}

1;
