package Graphics::Object::Yaxis;

use strict;
use Core::Utils;
use Core::Mathematics qw(:all);
use POSIX;

use base qw(Graphics::Object);

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ values          => [],
                   stdev           => [],
                   labels          => [],
                   ticksby         => undef,
                   yrange          => [undef, undef],
                   forceyrange     => 0,
                   axisstroke      => "black",
                   plotstdev       => "both",
                   opacity         => 1,
                   plotyaxis       => 1,
                   plotyvalues     => 1,
                   labelrotate     => 90,
                   yname           => undef,
                   xname           => undef,
                   plotticks       => 1,
                   _values         => [[], []],
                   _yrepresent     => "%d",
                   _xpadding       => 0,
                   _tickwidth      => 5,
                   _labelspace     => 2.5,
                   _namespace      => undef,
                   _maxylabelwidth => 0,
                   _baseline       => 0,
                   _yarea          => [0, 0],
                   _ticks          => [] }, \%parameters);

    $self->throw("Can't call method from a generic Graphics::Object::Yaxis object") if ($class eq "Graphics::Object::Yaxis");

    return($self);

}

sub _validate {

    my $self = shift;

    $self->SUPER::_validate();

    $self->throw("Values must be provided as an ARRAY reference") if (ref($self->{values}) ne "ARRAY");
    $self->throw("Standard deviations must be provided as an ARRAY reference") if (ref($self->{stdev}) ne "ARRAY");
    $self->throw("Labels must be provided as an ARRAY reference") if (ref($self->{labels}) ne "ARRAY");
    $self->throw("Values array is empty") if (!@{$self->{values}});
    $self->throw("Invalid standard deviation plot mode") if ($self->{plotstdev} !~ m/^up|down|both$/i);
    $self->throw("Labels and values arrays have different lengths") if (@{$self->{labels}} &&
                                                                        @{$self->{labels}} != @{$self->{values}});
    $self->throw("Y axis ticks step must be > 0") if (defined $self->{ticksby} &&
                                                      $self->{ticksby} <= 0);
    $self->throw("Y axis range must be an ARRAY reference of 2 values") if (ref($self->{yrange}) ne "ARRAY" ||
                                                                            @{$self->{yrange}} != 2);
    $self->throw("Plot Y axis parameter must be bool") if (!isbool($self->{plotyaxis}));
    $self->throw("Force Y range parameter must be bool") if (!isbool($self->{forceyrange}));
    $self->throw("Plot Y axis values parameter must be bool") if (!isbool($self->{plotyvalues}));
    $self->throw("Plot Y axis ticks parameter must be bool") if (!isbool($self->{plotticks}));
    $self->throw("Label rotation angle must be numeric ") if (!isnumeric($self->{labelrotate}));
    $self->throw("Label rotation angle must be comprised between 0 and 90") if (!inrange($self->{labelrotate}, [0, 90]));
    $self->throw("Opacity must be an integer comprised between 0 and 1") if (!ispositive($self->{opacity}) ||
                                                                             $self->{opacity} > 1);

}

sub _nvalues { return(scalar(@{$_[0]->{values}})); }

sub _fixproperties {

    my $self = shift;

    @{$self->{values}} = map { isnumeric($_) ? $_ : 0 } @{$self->{values}};
    @{$self->{stdev}} = map { isnumeric($_) ? $_ : 0 } @{$self->{stdev}};

    $self->{_values} = [[@{$self->{values}}], [@{$self->{values}}]];
    @{$self->{yrange}} = sort {$a <=> $b} @{$self->{yrange}} if (defined $self->{yrange}->[0] &&
                                                                 defined $self->{yrange}->[1]);

    if (@{$self->{stdev}}) {

        $self->throw("Standard deviation values must be >= 0") if (!ispositive(@{$self->{stdev}}));
        $self->throw("Standard deviations array and values array have different lengths") if (@{$self->{stdev}} != @{$self->{values}});

        push(@{$self->{stdev}}, 0) while (@{$self->{stdev}} < @{$self->{values}}); # Fill missing values with zeros

        @{$self->{_values}->[0]} = map { $self->{values}->[$_] - $self->{stdev}->[$_] } 0 .. $#{$self->{values}} if ($self->{plotstdev} =~ m/^down|both$/i);
        @{$self->{_values}->[1]} = map { $self->{values}->[$_] + $self->{stdev}->[$_] } 0 .. $#{$self->{values}} if ($self->{plotstdev} =~ m/^up|both$/i);

    }

    if (!defined $self->{yrange}->[0]) { $self->{yrange}->[0] = min(0, @{$self->{_values}->[0]}); }
    else {

        my $min = min(@{$self->{_values}->[0]});
        $self->{yrange}->[0] = $min if ($self->{yrange}->[0] < $min &&
                                        !$self->{forceyrange});

    }

    if (!defined $self->{yrange}->[1]) { $self->{yrange}->[1] = max(0, @{$self->{_values}->[1]}); }
    else {

        my $max = max(@{$self->{_values}->[1]});
        $self->{yrange}->[1] = $max if ($self->{yrange}->[1] > $max &&
                                        !$self->{forceyrange});

    }

    @{$self->{yrange}} = sort {$a <=> $b} @{$self->{yrange}};

    $self->{_yrepresent} = "%.2e" if (max(map { abs($_) } @{$self->{yrange}}) >= 1e5);

    @{$self->{values}} = map { $_ > $self->{yrange}->[1] ? $self->{yrange}->[1] :
                                                           ($_ < $self->{yrange}->[0] ? $self->{yrange}->[0] : $_) } @{$self->{values}};
    @{$self->{_values}->[0]} = map { $_ > $self->{yrange}->[1] ? $self->{yrange}->[1] :
                                                                 ($_ < $self->{yrange}->[0] ? $self->{yrange}->[0] : $_) } @{$self->{_values}->[0]};
    @{$self->{_values}->[1]} = map { $_ > $self->{yrange}->[1] ? $self->{yrange}->[1] :
                                                                 ($_ < $self->{yrange}->[0] ? $self->{yrange}->[0] : $_) } @{$self->{_values}->[1]};

    $self->{_baseline} = abs($self->{yrange}->[0]) < abs($self->{yrange}->[1]) ? $self->{yrange}->[0] : $self->{yrange}->[1] if (!inrange(0, $self->{yrange}));
    $self->{_namespace} = $self->{fontsize} < 10 ? 10 : $self->{fontsize};
    $self->{_tickwidth} = $self->{fontsize} < 10 ? 5 : $self->{fontsize} / 2;
    $self->{_labelspace} = $self->{_tickwidth} / 2;

    # Uncomment this after tests
    #$self->throw("Nothing to plot (all data points are equal to baseline value)") unless (sum(map { $_ - $self->{_baseline} } @{$self->{values}}));

    $self->{_yarea}->[0] = $self->{_starty} + 1/2 * $self->{fontsize};
    $self->{_yarea}->[1] = $self->{_starty} + $self->{_height} - 1/2 * $self->{fontsize};

    if (@{$self->{labels}}) {

        my $maxwidth = max(map { $self->_textwidth($_) } @{$self->{labels}}) || 0;
        $self->{_yarea}->[1] -= $self->{_labelspace} + sqrt($maxwidth ** 2 + $self->{fontsize} ** 2) * sin(atan2($self->{fontsize}, $maxwidth) + $self->{labelrotate} / 180 * 3.14159265359) - 1/2 * $self->{fontsize};

    }

    $self->{_yarea}->[1] -= $self->{_namespace} + $self->{fontsize} if ($self->{xname});

}

# This sub tries to automagically define the best step for y axis values.
# It's a raw attempt to do this, probably it could be written much better,
# but for now it works... I'll fix it in the future.
sub _calcticksby {

    my $self = shift;

    my ($n, $multi10, $divfactor);
    $n = abs(diff(@{$self->{yrange}}));

    $self->throw("Y-range start value must differ from end value") unless($n);

    while($n < 10) { $n *= 10; $multi10++; }
    while(abs(int($n) - $n) > 1e-6) { $n *= 10; $multi10++; }

    $n = int($n);

    while (!$divfactor) {

        for (4,5,6,7) {

            if ($n % $_ == 0 &&
                $n % 10 == 0) {

                $divfactor = $_;

                last;

            }

        }

        $n -= 1;

    }

    $n += 1;

    $n = $n / (10 ** $multi10) if ($multi10);
    $n /= $divfactor;

    if ($n =~ m/^\d+\.(0*)[1-9]/) {

        $self->{_yrepresent} = "%." . (length($1) + 1) . "f";
        $n = sprintf($self->{_yrepresent}, $n);

    }

    $n = int($n) if ($n >= 1);

    $self->{ticksby} = $n;

}

sub _calcxpadding { # Calculates the required space for y axis labels

    my $self = shift;

    $self->{_xpadding} = $self->{_margin} * $self->{_width};

    if ($self->{plotyvalues}) {

        my (@values);

        if (inrange(0, $self->{yrange})) { # 0 is the baseline

            push(@values, sprintf($self->{_yrepresent}, 0));

            if (haspositive(@{$self->{yrange}})) { push(@values, sprintf($self->{_yrepresent}, $_ * $self->{ticksby})) for (1 .. floor($self->{yrange}->[1] / $self->{ticksby})); }
            if (hasnegative(@{$self->{yrange}})) { push(@values, sprintf($self->{_yrepresent}, -$_ * $self->{ticksby})) for (1 .. floor(abs($self->{yrange}->[0]) / $self->{ticksby})); }

        }
        else {

            push(@values, sprintf($self->{_yrepresent}, (isnegative(@{$self->{yrange}}) ? $_ : -$_) * $self->{ticksby} + $self->{yrange}->[0])) for (0 .. floor(abs(diff(@{$self->{yrange}}))) / $self->{ticksby});

        }

        $self->{_ticks} = [sort {$a <=> $b} @values];
        $self->{_maxylabelwidth} = max(map { $self->_textwidth($_) } @values);
        $self->{_xpadding} += $self->{_maxylabelwidth} + $self->{_labelspace};

    }

    $self->{_xpadding} += $self->{_tickwidth} if ($self->{plotticks});
    $self->{_xpadding} += $self->{fontsize} + $self->{_namespace} if ($self->{yname});
    $self->{_xpadding}++ if ($self->{plotyaxis});

}

sub _preplotcalc { # This is called by the Graphics::Container object to rescale figure

    my $self = shift;

    $self->_fixproperties();
    $self->_calcticksby() if (!$self->{ticksby} ||
                              !isnumeric($self->{ticksby}) ||
                              $self->{ticksby} > $self->{yrange}->[1]);
    $self->_calcxpadding();

}

sub xml {

    my $self = shift;

    $self->_calcplotwidth();
    $self->_plotdata();
    $self->_plotyaxis() if ($self->{plotyaxis} ||
                            $self->{plotticks} ||
                            $self->{plotyvalues});
    $self->_plotstdev() if (@{$self->{stdev}});
    $self->_plotxaxis() if ($self->{xname} ||
                            @{$self->{labels}});
    $self->SUPER::xml();

}

sub _plotyaxis {

    my $self = shift;

    # First calculates the ticks position, then uses the first and last one as y axis boundaries
    my ($x, @ticks);
    $x = $self->{_xpadding} - $self->{_margin} * $self->{_width};
    $x -= 1 if ($self->{plotyaxis});
    $x -= $self->{_tickwidth} if ($self->{plotticks});
    @ticks = map { $self->_vertalign($_) } @{$self->{_ticks}};

    if ($self->{plotticks}) {

        for (0 .. $#ticks) {

            $self->emptytag("line", { x1     => $x,
                                      x2     => $x + $self->{_tickwidth},
                                      y1     => $ticks[$_],
                                      y2     => $ticks[$_],
                                      stroke => $self->{axisstroke} });

        }

    }

    if ($self->{plotyvalues}) {

        for (0 .. $#ticks) {

            $self->tagline("text", $self->{_ticks}->[$_], { style                => "font-size: " . $self->{fontsize} . "px; font-family: Helvetica;",
                                                            "text-anchor"        => "end",
                                                            "alignment-baseline" => "middle",
                                                            "dominant-baseline"  => "mathematical",
                                                            x                    => $x - $self->{_labelspace},
                                                            y                    => $ticks[$_] });

        }

    }

    if ($self->{plotyaxis}) {

        $x += $self->{_tickwidth};

        $self->emptytag("line", { x1     => $x,
                                  x2     => $x,
                                  y1     => $ticks[-1],
                                  y2     => $ticks[0],
                                  stroke => $self->{axisstroke} }); # y-axis

        if ($self->{yname}) {

            $self->tagline("text", $self->{yname}, { transform     => "translate(" . join(",", $self->{fontsize}, mean($ticks[0], $ticks[-1])) . ") rotate(-90)",
                                                     "text-anchor" => "middle",
                                                     style         => "font-size: " . $self->{fontsize} . "px; font-family: Helvetica;" });

        }

    }

}

sub _vertalign {

    my $self = shift;
    my $y = shift if (@_);

    my $zero = maprange(@{$self->{yrange}}, @{$self->{_yarea}}, 0);

    return(maprange(@{$self->{yrange}}, @{$self->{_yarea}}, $self->{yrange}->[1] - $y) - $zero + $self->{_yarea}->[0]);

}

sub _plotxaxis { $_[0]->throw("Can't call method from a generic Graphics::Object::Yaxis object"); }

sub _calcplotwidth { $_[0]->throw("Can't call method from a generic Graphics::Object::Yaxis object"); }

sub _plotdata { $_[0]->throw("Can't call method from a generic Graphics::Object::Yaxis object"); }

1;
