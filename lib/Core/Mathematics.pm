#!/usr/bin/perl

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

our $NOVALIDATE = $ENV{"RF_NOVALIDATE"};
our @EXPORT = qw(isint isfloat isexp isinf
                 isnan isnumeric ispositive isnegative
                 isreal isbool haspositive hasnegative
                 iseven isodd logarithm min max mean
                 geomean midrange stdev popStdev
                 mmode median round sum percent2freq
                 diff product maprange intersect
                 variance inrange haspositive hasnegative
                 hasnan haszero absolute euclideandist
                 normeuclideandist mround argmax argmin);

sub isint {

    for (@_) {

        return if (!looks_like_number($_) || lc($_) eq "inf" || 
                   lc($_) eq "-inf" || $_ != $_ || int($_) != $_);

    }

    return(1);

}

sub isfloat {

    for (@_) {

        return if (!looks_like_number($_) || lc($_) eq "inf" || 
                   lc($_) eq "-inf" || $_ != $_ || int($_) == $_);

    }

    return(1);

}

sub isinf {

    for (@_) { return if (lc($_) ne "inf" && lc($_) ne "-inf"); }

    return(1);

}

sub isnan {

    for (@_) { return if ($_ == $_); }

    return(1);

}

sub isreal {

    for (@_) {

        return if (!looks_like_number($_) || lc($_) eq "inf" || 
                   lc($_) eq "-inf" || $_ != $_);          

    }

    return(1);

}

sub isnumeric {

    for (@_) {

        next if (lc($_) eq "inf" || lc($_) eq "-inf");     # isinf() -> accepted
        return if (!looks_like_number($_) || $_ != $_);

    }

    return(1);

}

sub ispositive {

    for (@_) {

        if (lc($_) eq "inf") { next; }
        elsif (lc($_) eq "-inf") { return; }

        return if (!looks_like_number($_) || $_ != $_ || $_ < 0);

    }

    return(1);

}

sub isnegative {

    for (@_) {

        if (lc($_) eq "-inf") { next; }
        elsif (lc($_) eq "inf") { return; }

        return if (!looks_like_number($_) || $_ != $_ || $_ >= 0);

    }

    return(1);

}

sub ispercentage {

    my @values = @_;

    for (@values) {

        return unless (substr($_, -1) eq "%");

        $_ = substr($_, 0, -1);

        return if (!looks_like_number($_) || lc($_) eq "inf" || 
                   lc($_) eq "-inf" || $_ != $_ || $_ < 0 || $_ > 100);


    }

    return(1);

}

sub isbool {

    my @values = @_;

    for (@values) { return if ($_ ne "0" && $_ ne "1"); }

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

    #return unless(isnumeric(@values));

    return(scalar(grep { looks_like_number($_) && $_ < 0 } @values));

}

sub haszero {

    my @values = @_;

    #return unless(isnumeric(@values));

    return(scalar(grep { looks_like_number($_) && $_ == 0 } @values));

}

sub haspositive {

    my @values = @_;

    #return unless(isnumeric(@values));

    return(scalar(grep { looks_like_number($_) && $_ > 0 } @values));

}

sub hasnan {

    my @values = @_;

    return if (isnumeric(@values));

    return(scalar(grep { $_ != $_ } @values));

}

sub percent2freq {

    my @values = @_;

    for (@values) {

        return unless (ispercentage($_));

        $_ = substr($_, 0, -1) / 100;

    }

    return(@values);

}

sub logarithm {

    my $argument = shift;
    my $base = shift // e;

    if (!$NOVALIDATE) {

        Core::Utils::throw("Logarithm argument is not numeric") if (!isnumeric($argument));
        Core::Utils::throw("Invalid logarithm base") if (!isnumeric($base));

    }

    return(inf) if ($base == 1);
    return(inf) if ($argument == 0);
    return(nan) if (hasnegative($argument, $base));

    return(log($argument) / ($base ? log($base) : ninf));

}

sub min {

    Core::Utils::throw("Values array is empty") if (!@_);
    if (!$NOVALIDATE) { Core::Utils::throw("Values must be numeric") if (!isnumeric(@_)); }

    # A single pass replaces sorting the whole list to take one element
    my $min = $_[0];

    for my $i (1 .. $#_) { $min = $_[$i] if ($_[$i] < $min); }

    return($min);

}

sub max {

    Core::Utils::throw("Values array is empty") if (!@_);
    if (!$NOVALIDATE) { Core::Utils::throw("Values must be numeric") if (!isnumeric(@_)); }

    my $max = $_[0];

    for my $i (1 .. $#_) { $max = $_[$i] if ($_[$i] > $max); }

    return($max);

}

sub argmax {

    Core::Utils::throw("Values array is empty") if (!@_);
    if (!$NOVALIDATE) { Core::Utils::throw("Values must be numeric") if (!isnumeric(@_)); }

    # The maximum and the indices holding it are collected together, instead of
    # calling max() (which sorted) and then scanning the list a second time
    my ($max, @maxi);
    $max = $_[0];
    @maxi = (0);

    for my $i (1 .. $#_) {

        if ($_[$i] > $max) { $max = $_[$i]; @maxi = ($i); }
        elsif ($_[$i] == $max) { push(@maxi, $i); }

    }

    return(wantarray() ? @maxi : $maxi[0]);

}

sub argmin {

    Core::Utils::throw("Values array is empty") if (!@_);
    if (!$NOVALIDATE) { Core::Utils::throw("Values must be numeric") if (!isnumeric(@_)); }

    my ($min, @mini);
    $min = $_[0];
    @mini = (0);

    for my $i (1 .. $#_) {

        if ($_[$i] < $min) { $min = $_[$i]; @mini = ($i); }
        elsif ($_[$i] == $min) { push(@mini, $i); }

    }

    return(wantarray() ? @mini : $mini[0]);

}

sub mean {

    my @values = @_;

    my ($avg);

    Core::Utils::throw("Values array is empty") if (!@values);
    if (!$NOVALIDATE) { Core::Utils::throw("Values must be numeric") if (!isnumeric(@values)); }

    return($values[0]) if (@values == 1);

    $avg += $_ for (@values);
    $avg /= @values;

    return($avg);

}

sub geomean {

    my @values = @_;

    my ($avg);

    Core::Utils::throw("Values array is empty") if (!@values);
    if (!$NOVALIDATE) { Core::Utils::throw("Values must be >= 0") if (!ispositive(@values)); }

    return(0) if (haszero(@values));
    return($values[0]) if (@values == 1);

    $_ = logarithm($_) for (@values);
    $avg  = exp(mean(@values));

    return($avg);

}

sub midrange {

    my @values = @_;

    Core::Utils::throw("Values array is empty") if (!@values);
    if (!$NOVALIDATE) { Core::Utils::throw("Values must be numeric") if (!isnumeric(@values)); }

    return((max(@values) + min(@values)) / 2);

}

sub variance {

    my @values = @{$_[0]};
    my $ddof = $_[1] || 0;

    my ($avg, $sq, $variance);
    $sq = 0;

    Core::Utils::throw("Values array is empty") if (!@values);
    if (!$NOVALIDATE) { Core::Utils::throw("Values must be numeric") if (!isnumeric(@values)); }

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

    Core::Utils::throw("Values array is empty") if (!@values);
    if (!$NOVALIDATE) { Core::Utils::throw("Values must be numeric") if (!isnumeric(@values)); }

    return($values[0]) if (@values == 1);

    my (%counts);
    $counts{$_}++ for (@values);
    @values = sort {$counts{$b} <=> $counts{$a}} keys %counts;

    return(shift(@values));

}

sub median {

    my @values = @_;

    Core::Utils::throw("Values array is empty") if (!@values);
    if (!$NOVALIDATE) { Core::Utils::throw("Values must be numeric") if (!isnumeric(@values)); }

    return $values[0] if (@values == 1);

    @values = sort {$a <=> $b} @values;

    if (@values % 2) { return($values[int(@values / 2)]); }
    else { return(mean($values[(@values / 2) - 1], $values[(@values / 2)])); }

}

sub round {

    my $value = shift;

    Core::Utils::throw("No value has been provided") if (!defined $value);
    Core::Utils::throw("Value must be real") if (!isreal($value));

    my $int = floor($value);

    if ($value >= ($int + 0.5)) { return(ceil($value)); }
    else { return($int); }

}

sub mround {

  my $value = shift;
  my $multiple = shift || 0.5;

  Core::Utils::throw("No value has been provided") if (!defined $value);
  Core::Utils::throw("Value must be real") if (!isreal($value));
  Core::Utils::throw("Multiple value must be real") if (!isreal($multiple));

  $multiple = abs($multiple);

  return($value >= 0 ? $multiple * int(($value + 0.5 * $multiple) / $multiple) :
                       $multiple * ceil(($value - 0.5 * $multiple) / $multiple));


}

sub sum {

    my @values = @_;

    Core::Utils::throw("Values array is empty") if (!@values);
    if (!$NOVALIDATE) { Core::Utils::throw("Values must be numeric") if (!isnumeric(@values)); }

    my ($sum);

    $sum += $_ for (@values);

    return($sum);

}

sub diff {

    my @values = @_;

    Core::Utils::throw("Values array is empty") if (!@values);
    if (!$NOVALIDATE) { Core::Utils::throw("Values must be numeric") if (!isnumeric(@values)); }

    my $diff = shift(@values);

    $diff -= $_ for (@values);

    return($diff);

}

sub product {

    my @values = @_;

    Core::Utils::throw("Values array is empty") if (!@values);
    if (!$NOVALIDATE) { Core::Utils::throw("Values must be numeric") if (!isnumeric(@values)); }

    my $product = shift(@values);

    $product *= $_ for (@values);

    return($product);

}

sub absolute {

    my @values = @_;

    Core::Utils::throw("Values array is empty") if (!@values);
    if (!$NOVALIDATE) { Core::Utils::throw("Values must be numeric") if (!isnumeric(@values)); }

    return(map { abs($_) } @values);

}

sub maprange {

    my ($oldmin, $oldmax, $newmin, $newmax, $value) = @_;

    Core::Utils::throw("Invalid old range (old minimum = old maximum)") if ($oldmin == $oldmax);
    Core::Utils::throw("Invalid new range (new minimum = new maximum)") if ($newmin == $newmax);

    return(((($value - $oldmin) * ($newmax - $newmin)) / ($oldmax - $oldmin)) + $newmin);

}

sub intersect {

    my @intervals = @_;

    Core::Utils::throw("Intervals array is empty") if (!@intervals);

    for (@intervals) {

        Core::Utils::throw("Intervals must be provided as ARRAY references") if (ref($_) ne "ARRAY");
        Core::Utils::throw("Intervals must have 2 values (start, end)") if (@{$_} < 2);
        if (!$NOVALIDATE) { Core::Utils::throw("Intervals must be numeric") if (!isnumeric(@{$_})); }

    };

    # The bounds are tracked directly, rather than building two lists and
    # calling max()/min() on them
    my ($start, $end);
    $start = $intervals[0]->[0];
    $end = $intervals[0]->[1];

    for my $i (1 .. $#intervals) {

        $start = $intervals[$i]->[0] if ($intervals[$i]->[0] > $start);
        $end = $intervals[$i]->[1] if ($intervals[$i]->[1] < $end);

    }

    return() if ($start > $end);

    return([$start, $end]);

}

sub inrange {

    my ($value, $range) = @_;

    return(1) if (intersect($range, [$value, $value]));

}

sub euclideandist {

    my @data = @_[0..1];
    my $rmnan = $_[2] || 0;

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
    my $rmnan = $_[2] || 0;

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