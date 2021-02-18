package Term::Table;

use strict;
use Core::Mathematics qw(:functions);
use Term::Constants qw(:colors);
use Term::Utils;

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ indent   => 0,
                   spacer   => 4,
                   _columns => (termsize())[1],
                   _table   => [],
                   _lengths => [] }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("Indentation value must be a positive integer") if (!ispositive($self->{indent}) ||
                                                                     !isint($self->{indent}));
    $self->throw("Spacer value must be a positive integer") if (!ispositive($self->{spacer}) ||
                                                                !isint($self->{spacer}));

}

sub blank {

    my $self = shift;

    push(@{$self->{_table}}, ["Row", "", ""]);

}

sub head {

    my $self = shift;
    my @data = @_;

    for (0 .. $#data) {

        $self->{_lengths}->[$_+1] = max(length($data[$_]), $self->{_lengths}->[$_+1] || 0);
        $data[$_] = UNDERLINE . BOLD . $data[$_] . RESET;
        $data[$_] .= "\n" if ($_ == $#data);

    }

    push(@{$self->{_table}}, ["Head", @data]);

}

sub row {

    my $self = shift;
    my @data = @_;

    $self->{_lengths}->[$_+1] = max(length($data[$_]) || 0, $self->{_lengths}->[$_+1] || 0) for (0 .. $#data);

    push(@{$self->{_table}}, ["Row", @data]);

}

sub append {

    my $self = shift;
    my $text = shift;

    $self->{append} = $text if ($text);

}

sub print {

    my $self = shift;

    print $self->_table;
    print "\n" . $self->{append} if ($self->{append});

}

sub _table {

    my $self = shift;

    my ($table);

    foreach my $data (@{$self->{_table}}) {

        for (my $i = 1; $i < @{$data}; $i++) {

            $table .= " " x $self->{indent} if ($i == 1);
            $table .= $data->[$i];

            if ($i < $#{$data}) {

                my $escape = ($data->[$i] =~ tr/\e//);

                if ($data->[0] eq "Head") { $table .= " " x ($self->{_lengths}->[$i] - length($data->[$i]) + $self->{spacer} + 12); }
                else { $table .= " " x ($self->{_lengths}->[$i] - length($data->[$i]) + $self->{spacer} + $escape); }

            }

        }

        $table .= "\n";

    }

    chomp($table); # Removes the last newline

    return($table);

}

1;
