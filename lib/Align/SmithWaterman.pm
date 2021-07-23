package Align::SmithWaterman;

use strict;
use Align::Alignment;
use Core::Mathematics qw(:all);
use Core::Utils;
use Data::Sequence::Utils;

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ reference   => undef,
                   query       => undef,
                   match       => 1,
                   mismatch    => 0.33,
                   gOpen       => -1.33,
                   gExt        => -1.33,
                   scoring     => {},
                   _matrix     => [],
                   _best       => [],
                   _index      => 0 }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("Reference sequence contains invalid characters") if (defined $self->{reference} && !isseq($self->{reference}));
    $self->throw("Query sequence contains invalid characters") if (defined $self->{query} && !isseq($self->{query}));
    $self->throw("Match value must be numeric") if (!isnumeric($self->{match}));
    $self->throw("Mismatch value must be numeric") if (!isnumeric($self->{mismatch}));
    $self->throw("Gap open value must be numeric") if (!isnumeric($self->{gOpen}));
    $self->throw("Gap extension value must be numeric") if (!isnumeric($self->{gExt}));

    $self->{scoring} = { map { $_ . $_ => 1 } ("A" .. "Z") } if (!keys %{$self->{scoring}});

}

sub align {

    my $self = shift;

    my ($gOpen, $gExt, $matrix, $reference,
        $query, $aligned, $best);

    $self->{_matrix} = [];
    $self->{_best} = [];

    $gOpen = $self->{gOpen};
    $gExt = $self->{gExt};
    $reference = uc($self->{reference});
    $query = uc($self->{query});

    for my $i (1 .. length($reference)) {

        for my $j (1 .. length($query)) {

            my ($score, $max, $ptr, $match,
                $dinucl, %scoring);
            %scoring = %{$self->{scoring}};
            $dinucl = join("", sort(substr($reference, $i - 1, 1), substr($query, $j - 1, 1)));
            $match = exists $scoring{$dinucl} ? $scoring{$dinucl} : $self->{mismatch};
            $max = $matrix->[$i - 1]->[$j - 1]->{score} + $match;
            $ptr = "diag";

            if (($matrix->[$i - 1]->[$j]->{ptr} eq "diag" &&
                 ($score = $matrix->[$i - 1]->[$j]->{score} + $gOpen) > $max) ||
                ($matrix->[$i - 1]->[$j]->{ptr} eq "left" &&
                 ($score = $matrix->[$i - 1]->[$j]->{score} + $gExt) > $max)) {

                $max = $score;
                $ptr = "up";

            }

            if (($matrix->[$i]->[$j - 1]->{ptr} eq "diag" &&
                 ($score = $matrix->[$i]->[$j - 1]->{score} + $gOpen) > $max) ||
                ($matrix->[$i]->[$j-1]->{ptr} eq "up" &&
                 ($score = $matrix->[$i]->[$j-1]->{score} + $gExt) > $max)) {

                $max = $score;
                $ptr = "left";

            }

            if ($max < 0) {

                $matrix->[$i + 1]->[$j + 1]->{score} = 0;

                next;

            }

            $matrix->[$i]->[$j]->{score} = $max;
            $best = $max if ($max > $best);
            $matrix->[$i]->[$j]->{ptr} = $ptr;

        }

    }

    for(my $i = 1; $i <= length($reference); $i++) {

        for(my $j = 1; $j <= length($query); $j++) {

            push(@{$self->{_best}}, { column => $i,
                                      row    => $j }) if ($matrix->{$i}->{$j}->{score} == $best);

        }

    }

    $self->{_matrix} = $matrix;

    return(scalar(@{$self->{_best}}));

}

sub read {

    my $self = shift;

    if (@{$self->{_best}} != 0 && $self->{_index} < @{$self->{_best}}) {

        my ($reference, $query, $matrix, $best,
            $i, $j, $aligned, $score,
            $alignment, $starti, $startj, $endi, $endj);

        $reference = uc($self->{reference});
        $query = uc($self->{query});
        $matrix = $self->{_matrix};
        $best = $self->{_best}->[$self->{_index}];
        ($i, $j) = ($best->{column}, $best->{row});
        ($endi, $endj) = ($i, $j);
        $score = $matrix->[$i]->[$j]->{score};
        $self->{_index}++;

        while($matrix->[$i]->[$j]->{score} != 0) {

            ($starti, $startj) = ($i, $j);

            if ($matrix->[$i]->[$j]->{ptr} eq "diag") {

                $i--;
                $j--;

                unshift(@{$aligned->{reference}}, substr($reference, $i, 1));
                unshift(@{$aligned->{query}}, substr($query, $j, 1));

            }
            elsif ($matrix->[$i]->[$j]->{ptr} eq "left") {

                $j--;

                unshift(@{$aligned->{reference}}, isseq($self->{reference}) ? "-" : "_");
                unshift(@{$aligned->{query}}, substr($query, $j, 1));

            }
            elsif ($matrix->[$i]->[$j]->{ptr} eq "up") {

                $i--;

                unshift(@{$aligned->{reference}}, substr($reference, $i, 1));
                unshift(@{$aligned->{query}}, isseq($self->{query}) ? "-" : "_");

            }

            if (exists $self->{scoring}->{join("", sort($aligned->{reference}->[0], $aligned->{query}->[0]))}) { unshift(@{$aligned->{alignment}}, "|"); }
            elsif ($aligned->{reference}->[0] !~ m/^[_-]$/ && $aligned->{query}->[0] !~ m/^[_-]$/) { unshift(@{$aligned->{alignment}}, "."); }
            else { unshift(@{$aligned->{alignment}}, " "); }

        }

        $alignment = Align::Alignment -> new( reference  => join("", @{$aligned->{reference}}),
                                              query      => join("", @{$aligned->{query}}),
                                              alignment  => join("", @{$aligned->{alignment}}),
                                              score      => $score,
                                              refStart   => $starti - 1,
                                              refEnd     => $endi - 1,
                                              queryStart => $startj - 1,
                                              queryEnd   => $endj - 1 );

        return($alignment);

    }
    else { $self->{_index} = 0; }

    return;

}

sub DESTROY {

    my $self = shift;

    undef(%{$self->{_matrix}});
    undef(@{$self->{_best}});

}

1;
