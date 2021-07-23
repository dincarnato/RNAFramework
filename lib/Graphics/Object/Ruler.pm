package Graphics::Object::Ruler;

use strict;
use Core::Utils;
use Core::Mathematics qw(:all);
use POSIX;

use base qw(Graphics::Object);

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ range       => [undef, undef],
                   ticksby     => undef,
                   stroke      => "black",
                   plotaxis    => 1,
                   plotvalues  => 1,
                   labelrotate => 90,
                   name        => undef,
                   plotticks   => 1,
                   toend       => 0,
                   labelMap    => {},
                   _represent  => "%d",
                   _xpadding   => 0,
                   _tickwidth  => 5,
                   _labelspace => 2.5,
                   _namespace  => undef,
                   _ticks      => [] }, \%parameters);

    $self->_validate();
    $self->_calcticksby();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->SUPER::_validate();

    $self->throw("Range must be an ARRAY reference") if (ref($self->{range}) ne "ARRAY");
    $self->throw("Range values must be numeric") if (!isnumeric(@{$self->{range}}));

    @{$self->{range}} = sort {$a <=> $b} @{$self->{range}};

    $self->throw("Range boudaries must have different values") if (!diff(@{$self->{range}}));
    $self->throw("Ticks step must be > 0") if (defined $self->{ticksby} &&
                                               (!isnumeric($self->{ticksby}) ||
                                                $self->{ticksby} <= 0));
    $self->throw("Plot axis parameter must be bool") if (!isbool($self->{plotaxis}));
    $self->throw("Plot values parameter must be bool") if (!isbool($self->{plotvalues}));
    $self->throw("Plot ticks parameter must be bool") if (!isbool($self->{plotticks}));
    $self->throw("Label rotation angle must be numeric ") if (!isnumeric($self->{labelrotate}));
    $self->throw("Label rotation angle must be comprised between 0 and 90") if (!inrange($self->{labelrotate}, [0, 90]));

    for (keys %{$self->{labelMap}}) {

        $self->throw("Labels must map to numeric values") if (!isnumeric($_));
        $self->throw("Labels mapping values must be included within range boundaries") if (!inrange($_, $self->{range}));

    }

    $self->{_represent} = "%.2e" if (max(map { abs($_) } @{$self->{range}}) >= 1e5);

}

sub _calcticksby {

    my $self = shift;

    my (@values);

    if (keys %{$self->{labelMap}}) { @values = keys %{$self->{labelMap}}; }
    else {

        if (!defined $self->{ticksby}) {

            my ($n, $multi10, $divfactor);
            $n = abs(diff(@{$self->{range}}));

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

                $self->{_represent} = "%." . (length($1) + 1) . "f";
                $n = sprintf($self->{_represent}, $n);

            }

            $n = int($n) if ($n >= 1);

            $self->{ticksby} = $n;

        }

        if (inrange(0, $self->{range})) { # 0 is the baseline

            push(@values, sprintf($self->{_represent}, 0));

            if (haspositive(@{$self->{range}})) { push(@values, sprintf($self->{_represent}, $_ * $self->{ticksby})) for (1 .. floor($self->{range}->[1] / $self->{ticksby})); }
            if (hasnegative(@{$self->{range}})) { push(@values, sprintf($self->{_represent}, -$_ * $self->{ticksby})) for (1 .. floor(abs($self->{range}->[0]) / $self->{ticksby})); }

        }
        else {

            push(@values, sprintf($self->{_represent}, (isnegative(@{$self->{range}}) ? -$_ : $_) * $self->{ticksby} + $self->{range}->[0])) for (0 .. floor(abs(diff(@{$self->{range}}))) / $self->{ticksby});

        }

        push(@values, sprintf($self->{_represent}, $self->{range}->[0]), sprintf($self->{_represent}, $self->{range}->[1])) if ($self->{toend});

    }

    $self->{_ticks} = [sort {$a <=> $b} uniq(@values)];

}

sub _preplotcalc {

    my $self = shift;

    if ($self->{plotvalues}) {

        my ($maxheight, $height, $fontsize, @ticks);
        @ticks = keys %{$self->{labelMap}} ? map { $self->{labelMap}->{$_} } @{$self->{_ticks}} : @{$self->{_ticks}};
        $height = 0;
        $maxheight = max(map { $self->_textwidth($_, 10) } @ticks) || 0;
        $maxheight = sqrt($maxheight ** 2 + 10 ** 2) * sin(atan2(10, $maxheight) + $self->{labelrotate} / 180 * 3.14159265359);
        #$height = $self->{_height};
        $height += 20 if ($self->{name});
        $height += 5 if ($self->{plotticks});
        $height += $maxheight + 2.5 + 5;
        $fontsize = 10 * $self->{_height} / $height;
        $self->{fontsize} = $fontsize if (!$fontsize ||
                                          $self->{fontsize} > $fontsize);
        $self->{_namespace} = $self->{fontsize} < 10 ? 10 : $self->{fontsize};
        $self->{_tickwidth} = $self->{fontsize} < 10 ? 5 : $self->{fontsize} / 2;
        $self->{_labelspace} = $self->{_tickwidth} / 2;

    }

}

sub xml {

    my $self = shift;

    my ($end, $tstart, $tend);
    $end = $self->{_width} - $self->{_margin} * $self->{_width};
    $tstart = $self->{toend} ? $self->{_xpadding} : maprange(@{$self->{range}}, $self->{_xpadding}, $end, $self->{_ticks}->[0]);
    $tend = $self->{toend} ? $end : maprange(@{$self->{range}}, $self->{_xpadding}, $end, $self->{_ticks}->[-1]);

    if ($self->{plotaxis}) {

        $self->emptytag("line", { x1     => $tstart,
                                  x2     => $tend,
                                  y1     => $self->{_starty},
                                  y2     => $self->{_starty},
                                  stroke => $self->{stroke} });

    }

    if ($self->{plotticks} ||
        $self->{plotvalues}) {

        for (@{$self->{_ticks}}) {

            my ($truex, $label);
            $truex = maprange(@{$self->{range}}, $self->{_xpadding}, $end, $_);
            $label = keys %{$self->{labelMap}} ? $self->{labelMap}->{$_} : $_;
            $self->emptytag("line", { x1     => $truex,
                                      x2     => $truex,
                                      y1     => $self->{_starty},
                                      y2     => $self->{_starty} + $self->{_tickwidth},
                                      stroke => $self->{stroke} }) if ($self->{plotticks});

            $self->tagline("text", $label, { style                => "font-size: " . $self->{fontsize} . "px; font-family: Helvetica;",
                                             "text-anchor"        => $self->{labelrotate} ? "end" : "middle",
                                             "alignment-baseline" => "middle",
                                             "dominant-baseline"  => "mathematical",
                                             transform            => "translate(" . join(",", $truex, ($self->{plotticks} ? $self->{_starty} + $self->{_tickwidth} : $self->{_starty}) + $self->{_labelspace} + $self->{fontsize} / 2) . ") rotate(" . -abs($self->{labelrotate}) . ")" }) if ($self->{plotvalues});

        }

            if ($self->{name}) {

                my $truey = $self->{_starty} + $self->{fontsize};
                $truey += $self->{_tickwidth} if ($self->{plotticks});
                $truey += $self->{_labelspace} + (max(map { $self->_textwidth($_) } @{$self->{_ticks}}) || 0) if ($self->{plotvalues});
                $truey += $self->{_namespace};

                $self->tagline("text", $self->{name}, { "text-anchor" => "middle",
                                                        style         => "font-size: " . $self->{fontsize} . "px; font-family: Helvetica;",
                                                        x             => mean($tstart, $tend),
                                                        y             => $truey });

            }

    }



    $self->SUPER::xml();

}

1;
