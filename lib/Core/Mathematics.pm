#!/usr/bin/perl

##
# Chimaera Framework
# Epigenetics Unit @ HuGeF [Human Genetics Foundation]
#
# Author:  Danny Incarnato (danny.incarnato[at]hugef-torino.org)
#
# This program is free software, and can be redistribute  and/or modified
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# Please see <http://www.gnu.org/licenses/> for more informations.
##

package Core::Mathematics;

use strict;
use POSIX;
use Scalar::Util qw(looks_like_number);
use Core::Utils;

use constant e    => exp(1);
use constant pi   => 4 * atan2(1, 1);
use constant inf  => 0 + q{Inf};
use constant pinf => inf;
use constant ninf => -(inf);
use constant nan  => 0 + q{NaN};

use base qw(Exporter);

our @EXPORT = qw(isint isfloat isexp isinf
                 isnan isnumeric ispositive isnegative
                 isreal isbool haspositive hasnegative
                 iseven isodd);

our %EXPORT_TAGS = ( constants => [ qw() ],
                     functions => [ qw(logarithm min max mean
                                       geomean midrange stdev popStdev
                                       mmode median round sum
                                       diff product maprange intersect
                                       variance inrange haspositive hasnegative
                                       hasnan haszero absolute euclideandist
                                       normeuclideandist mround argmax argmin) ] );

{ my (%seen);
  push(@{$EXPORT_TAGS{$_}}, @EXPORT) foreach (keys %EXPORT_TAGS);
  push(@{$EXPORT_TAGS{all}}, grep {!$seen{$_}++} @{$EXPORT_TAGS{$_}}) foreach (keys %EXPORT_TAGS); }

our @EXPORT_OK = ( @{$EXPORT_TAGS{constants}},
                   @{$EXPORT_TAGS{functions}} );

sub isint {

    my @values = @_;

    for (@values) { return if (!isreal($_) ||
                               int($_) != $_); }

    return(1);

}

sub isfloat {

    my @values = @_;

    for (@values) { return if (!isreal($_) ||
                               int($_) == $_); }

    return(1);

}

sub isinf {

    my @values = @_;

    for (@values) { return if ($_ ne "inf" && $_ ne "-inf"); }

    return(1);

}

sub isnan {

    my @values = @_;

    for (@values) { return if ($_ == $_); }

    return(1);

}

sub isreal {

    my @values = @_;

    for (@values) { return if (!looks_like_number($_) || isinf($_) || isnan($_)); }

    return(1);

}

sub isnumeric {

    my @values = @_;

    for (@values) { return if (!isreal($_) &&
                               !isinf($_)); }

    return(1);

}

sub ispositive {

    my @values = @_;

    for (@values) { return if (!isnumeric($_) ||
                               $_ < 0); }

    return(1);

}

sub isnegative {

    my @values = @_;

    for (@values) { return if (!isnumeric($_) ||
                               $_ >= 0); }

    return(1);

}

sub ispercentage {

    my @values = @_;

    for (@values) {

        return unless ($_ =~ m/\%$/);

        $_ =~ s/\%$//;

        return if (!isreal($_) ||
                   isnegative($_) ||
                   $_ > 100);


    }

    return(1);

}

sub isbool {

    my @values = @_;

    for (@values) { return if ($_ !~ m/^[01]$/); }

    return(1);

}

sub iseven {

    my @values = @_;

    for (@values) { return if (!isnumeric($_) || $_ % 2); }

    return(1);

}

sub isodd { return(1) if (!iseven(@_)); }

sub hasnegative {

    my @values = @_;

    return unless(isnumeric(@values));

    return(scalar(grep { $_ < 0 } @values));

}

sub haszero {

    my @values = @_;

    return unless(isnumeric(@values));

    return(scalar(grep { $_ == 0 } @values));

}

sub haspositive {

    my @values = @_;

    return unless(isnumeric(@values));

    return(scalar(grep { $_ > 0 } @values));

}

sub hasnan {

    my @values = @_;

    return if (isnumeric(@values));

    return(scalar(grep { isnan($_) } @values));

}

sub percentage2frequency {

    my @values = @_;

    for (@values) {

        return unless (ispercentage($_));

        $_ =~ s/\%$//;
        $_ /= 100;

    }

    return(@values);

}

sub logarithm {

    my $argument = shift;
    my $base = shift // e;

    Core::Utils::throw("Logarithm argument is not numeric") if (!isnumeric($argument));
    Core::Utils::throw("Invalid logarithm base") if (!isnumeric($base));

    return(inf) if ($base == 1);
    return(inf) if ($argument == 0);
    return(nan) if (isnegative($argument) ||
                    isnegative($base));

    return(log($argument) / ($base ? log($base) : ninf));

}

sub min {

    my @values = @_;

#    Core::Utils::throw("Values array is empty") if (!@values);
#    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));

    @values = sort {$a <=> $b} @values;

    return(shift(@values));


}

sub max {

    my @values = @_;

 #   Core::Utils::throw("Values array is empty") if (!@values);
 #   Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));

    @values = sort {$a <=> $b} @values;

    return(pop(@values));

}

sub argmax {

    my @values = @_;

    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));

    my ($max, @maxi);
    $max = max(@values);
    @maxi = grep { $values[$_] == $max } 0 .. $#values;

    return(wantarray() ? @maxi : $maxi[0]);

}

sub argmin {

    my @values = @_;

    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));

    my ($min, @mini);
    $min = min(@values);
    @mini = grep { $values[$_] == $min } 0 .. $#values;

    return(wantarray() ? @mini : $mini[0]);

}

sub mean {

    my @values = @_;

    my ($avg);

#    Core::Utils::throw("Values array is empty") if (!@values);
#    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));

    return($values[0]) if (@values == 1);

    $avg += $_ for (@values);
    $avg /= @values;

    return($avg);

}

sub geomean {

    my @values = @_;

    my ($avg);

    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be positive numbers") if (!ispositive(@values));

    return(0) if (haszero(@values));
    return($values[0]) if (@values == 1);

    $_ = logarithm($_) for (@values);
    $avg  = exp(mean(@values));

    return($avg);

}

sub midrange {

    my @values = @_;

    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));

    return((max(@values) + min(@values)) / 2);

}

sub variance {

    my @values = @{$_[0]};
    my $ddof = $_[1] || 0;

    my ($avg, $sq, $variance);
    $sq = 0;

    #Core::Utils::throw("Values array is empty") if (!@values);
    #Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));

    return(0) if (@values == 1);

    $avg = mean(@values);
    $sq += ($avg - $_) ** 2 for (@values);
    $variance = $sq / (@values - $ddof);

    return($variance);

}

sub stdev { return(sqrt(variance(\@_, 1))); }

sub popStdev { return(sqrt(variance(\@_, 0))); }

sub mmode {

    my @values = @_;

    my (%counts);

    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));

    return($values[0]) if (@values == 1);

    $counts{$_}++ for (@values);
    @values = sort {$counts{$b} <=> $counts{$a}} keys %counts;

    return(shift(@values));

}

sub median {

    my @values = @_;

    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));

    return $values[0] if (@values == 1);

    @values = sort {$a <=> $b} @values;

    if (@values % 2) { return($values[int(@values / 2)]); }
    else { return(mean($values[(@values / 2) - 1], $values[(@values / 2)])); }

}

sub round {

    my $value = shift;

    Core::Utils::throw("No value has been provided") if (!defined $value);
    Core::Utils::throw("Value must be a real number") if (!isreal($value));

    my $int = floor($value);

    if ($value >= ($int + 0.5)) { return(ceil($value)); }
    else { return($int); }

}

sub mround {

  my $value = shift;
  my $multiple = shift || 0.5;

  Core::Utils::throw("No value has been provided") if (!defined $value);
  Core::Utils::throw("Value must be a real number") if (!isreal($value));
  Core::Utils::throw("Multiple value must be a real number") if (!isreal($multiple));

  $multiple = abs($multiple);

  return($value >= 0 ? $multiple * int(($value + 0.5 * $multiple) / $multiple) :
                       $multiple * ceil(($value - 0.5 * $multiple) / $multiple));


}

sub sum {

    my @values = @_;

    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));

    my ($sum);

    $sum += $_ for (@values);

    return($sum);

}

sub diff {

    my @values = @_;

    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));

    my $diff = shift(@values);

    $diff -= $_ for (@values);

    return($diff);

}

sub product {

    my @values = @_;

    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));

    my $product = shift(@values);

    $product *= $_ for (@values);

    return($product);

}

sub absolute {

    my @values = @_;

    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));

    return(map { abs($_) } @values);

}

sub maprange {

    my ($oldmin, $oldmax, $newmin, $newmax, $value) = @_;

    Core::Utils::throw("Invalid old range boundaries (old minimum is equal to old maximum)") if ($oldmin == $oldmax);
    Core::Utils::throw("Invalid new range boundaries (new minimum is equal to new maximum)") if ($newmin == $newmax);

    return(((($value - $oldmin) * ($newmax - $newmin)) / ($oldmax - $oldmin)) + $newmin);

}

sub intersect {

    my @intervals = @_ if (@_);

    Core::Utils::throw("Intervals array is empty") if (!@intervals);

    for (@intervals) {

        Core::Utils::throw("Intervals must be provided as ARRAY references") if (ref($_) ne "ARRAY");
        Core::Utils::throw("Intervals must be numeric") if (!isnumeric(@{$_}));
        Core::Utils::throw("Intervals must have 2 values (start, end)") if (@{$_} < 2);

    };

    my ($start, $end, @start, @end);
    @start = map({ $_->[0] } @intervals);
    @end = map({ $_->[1] } @intervals);
    $start = max(@start);
    $end = min(@end);

    return() if ($start > $end);

    return([$start, $end]);

}

sub inrange {

    my ($value, $range) = @_ if (@_);

    return(1) if (intersect($range, [$value, $value]));

}

sub euclideandist {

    my @data = @_[0..1];
    my $rmnan = $_[2] if (@_ == 3);

    if ($rmnan) {

        my @indices = grep {isnumeric($data[0]->[$_]) && isnumeric($data[1]->[$_])} 0 .. $#{$data[0]};
        @{$data[0]} = @{$data[0]}[@indices];
        @{$data[1]} = @{$data[1]}[@indices];

    }

    for (@data) { Core::Utils::throw("Values must be provided as ARRAY references") if (ref($_) ne "ARRAY"); }

    Core::Utils::throw("Insufficient parameters") if (@data < 2);
    Core::Utils::throw("Euclidean distance calculation needs 2 ARRAY references of the same length") if (@{$data[0]} != @{$data[1]});
    Core::Utils::throw("Values ARRAY references are empty") unless (@{$data[0]});

    my @dists = map { ($data[0]->[$_] - $data[1]->[$_]) ** 2 } 0 .. $#{$data[0]};

    return(sqrt(sum(@dists)));

}

sub normeuclideandist {

    my @data = @_[0..1];
    my $rmnan = $_[2] if (@_ == 3);

    if ($rmnan) {

        my @indices = grep {isnumeric($data[0]->[$_]) && isnumeric($data[1]->[$_])} 0 .. $#{$data[0]};
        @{$data[0]} = @{$data[0]}[@indices];
        @{$data[1]} = @{$data[1]}[@indices];

    }

    for (@data) { Core::Utils::throw("Values must be provided as ARRAY references") if (ref($_) ne "ARRAY"); }

    Core::Utils::throw("Insufficient parameters") if (@data < 2);
    Core::Utils::throw("Euclidean distance calculation needs 2 ARRAY references of the same length") if (@{$data[0]} != @{$data[1]});
    Core::Utils::throw("Values ARRAY references are empty") unless (@{$data[0]});

    return("NaN") if (uniq(@{$data[0]}) == 1 &&
                      uniq(@{$data[1]}) == 1);

    return(0.5 * (stdev(map { $data[0]->[$_] - $data[1]->[$_] } 0 .. $#{$data[0]}) ** 2) / (stdev(@{$data[0]}) ** 2 + stdev(@{$data[1]}) ** 2));

}

1;
