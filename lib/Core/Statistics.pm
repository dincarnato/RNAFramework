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

package Core::Statistics;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;
use List::Util qw(reduce);
use POSIX;

use base qw(Exporter);

our @EXPORT = qw(pearson spearman dhyper phyper
                 fisher percentile quantile padjust
                 pchisq qnorm pnorm pcombine
                 gini ttest chisq fact
                 binomialTest);

use constant EPS   => 3e-7;
use constant FPMIN => 1e-30;
use constant ITMAX => 100;

my $tolerance = 1;
$tolerance /= 2 while ((1 + $tolerance / 2) > 1);

sub pearson {

    my @data = @_[0..1];
    my $rm = checkparameters({ rmNaN      => 0,
                               rmOutliers => 0,
                               cap        => 0 }, $_[2] || {});

    @data = _fixCorrData(@data, $rm);

    my ($avgx, $avgy, $stdevx, $stdevy,
        $n, $r, $t, $p, $size);

    for (@data) { Core::Utils::throw("Values must be provided as ARRAY references") if (ref($_) ne "ARRAY"); }

    Core::Utils::throw("Insufficient parameters") if (@data < 2);
    Core::Utils::throw("Pearson correlation calculation needs 2 ARRAY references of the same length") if (@{$data[0]} != @{$data[1]});
    Core::Utils::throw("Values ARRAY references are empty") if (@{$data[0]} <= 1);

    $size = scalar(@{$data[0]});
    $avgx = mean(@{$data[0]});
    $avgy = mean(@{$data[1]});
    $stdevx = stdev(@{$data[0]});
    $stdevy = stdev(@{$data[1]});

    if (!$stdevx ||
	    !$stdevy) {

		Core::Utils::warn("Standard deviation is 0");

		return("NaN", 1);

    }

    $n += (($data[0]->[$_] - $avgx) * ($data[1]->[$_] - $avgy)) for (0 .. $size - 1);
    $r = $n / (($size - 1) * $stdevx * $stdevy);
    $p = _pcorr($r, $size);

    return(wantarray() ? ($r, $p) : $r);

}

sub spearman {

    my @data = @_[0..1];
    my $rm = checkparameters({ rmNaN      => 0,
                               rmOutliers => 0,
                               cap        => 0 }, $_[2] || {});

    @data = _fixCorrData(@data, $rm);

    my ($squareddiff, $n, $rho, $t,
        $p, @rank1, @rank2);
    $squareddiff = 0;

    for (@data) { Core::Utils::throw("Values must be provided as ARRAY references") if (ref($_) ne "ARRAY"); }

    Core::Utils::throw("Insufficient parameters") if (@data < 2);
    Core::Utils::throw("Spearman correlation calculation needs 2 ARRAY references of the same length") if (@{$data[0]} != @{$data[1]});
    Core::Utils::throw("Values ARRAY references are empty") if (@{$data[0]} <= 1);

    if (!stdev(@{$data[0]}) ||
       	!stdev(@{$data[1]})) {

        Core::Utils::warn("Standard deviation is 0");

        return("NaN", 1);

    }

    @rank1 = _values2ranks(@{$data[0]});
    @rank2 = _values2ranks(@{$data[1]});

    $n = @rank1;
    $squareddiff += ($rank1[$_] - $rank2[$_]) ** 2 for (0 .. $n - 1);
    $rho = 1 - (6 * $squareddiff / ($n * (($n ** 2) - 1)));
    $p = _pcorr($rho, scalar(@{$data[0]}));

    return(wantarray() ? ($rho, $p) : $rho);

}

sub _fixCorrData {

    my @data1 = @{$_[0]};
    my @data2 = @{$_[1]};
    my $rm = $_[2];

    if ($rm->{rmNaN}) {

        my @indices = grep {isnumeric($data1[$_]) && isnumeric($data2[$_])} 0 .. $#data1;
        @data1 = @data1[@indices];
        @data2 = @data2[@indices];

    }

    if ($rm->{cap}) {

        @data1 = map { isnumeric($_) ? min($_, $rm->{cap}) : "NaN" } @data1;
        @data2 = map { isnumeric($_) ? min($_, $rm->{cap}) : "NaN" } @data2;

    }

    if ($rm->{rmOutliers}) {

        my ($min1, $max1, $min2, $max2, @indices);
        $min1 = percentile(\@data1, 0.05);
        $max1 = percentile(\@data1, 0.95);
        $min2 = percentile(\@data2, 0.05);
        $max2 = percentile(\@data2, 0.95);
        @indices = grep { inrange($data1[$_], [$min1, $max1]) && inrange($data2[$_], [$min2, $max2]) } 0 .. $#data1;
        @data1 = @data1[@indices];
        @data2 = @data2[@indices];

    }

    return(\@data1, \@data2);

}

sub _pcorr {

    my ($r, $df) = @_;

    # Calculates the p-value:
    # PFromT(T_Value, DF) = BetaI(DF /2, 1/2, DF / (DF + T_Value^2))
    # PFromR(R_Value) = PFromT(|R_Value| / SQRT((1 - R_Value^2)/DF) , DF)

    my ($p, $t, $denom);
    $df -= 2;
    $denom = sqrt((1 - min(1, $r ** 2)) / $df);

    if ($denom) {

        $t = abs($r) / $denom;
        $p = betai($df / 2, 0.5, $df / ($df + $t ** 2));

    }
    else { $p = 0; }

    return($p);

}

sub _values2ranks {

    my @values = @_;

    my ($i, @ranks, %sorted);
    $i = 0;

    for (sort {$a <=> $b} @values) {

        push(@{$sorted{$_}}, $i);
        $i++;

    }

    push(@ranks, mean(@{$sorted{$_}})) for (@values);

    return(@ranks);

}

sub phyper {   # phyper returns the probability of having $i OR MORE successes

    # Implemented from Welinder and Smith
    # https://stat.ethz.ch/pipermail/r-devel/2004-April/029408.html
    # $i = i; $n = NR; $m = NB; $N = n;

    my ($n, $m, $N, $i, $lowertail) = @_;

    if ($n < 0 ||
        $m < 0 ||
        isinf($n + $m) ||
        $N < 0 ||
        $N > ($n + $m)) {

        Core::Utils::warn("phyper() function returned a NaN");

        return("NaN");

    }

    if ($i * ($n + $m) > $N * $n) {

        my $oldm = $m;
        $m = $n;
        $n = $oldm;
        $i = $N - $i - 1;
        $lowertail = !$lowertail;

    }

    return(0) if ($i < 0);

    my ($p, $t, $d);
    $p = 0;
    $t = 1;
    $d = dhyper($n, $m, $N, $i);

    while ($i > 0 &&
           $t >= DBL_EPSILON * $p) {

        $t *= $i * ($m - $N + $i) / ($N + 1 - $i) / ($n + 1 - $i);
        $p += $t;
        $i--;

    }

    $p++;

    return($lowertail ? $p * $d : 1 - $p * $d);

}

sub dhyper {   # Hypergeometicd returns the probability of having EXACTLY $i successes

    # $n = Successes in population
    # $m = Population size - $n
    # $N = Sample size
    # $i = Successes in sample

    my ($n, $m, $N, $i) = @_;

    my $loghyp1 = logfact($m) + logfact($n) + logfact($N) + logfact($m + $n - $N);
    my $loghyp2 = logfact($i) + logfact($n - $i) + logfact($m + $i - $N) + logfact($N - $i) + logfact($m + $n);

    return(exp($loghyp1 - $loghyp2));

}

sub chisq {

    # Contingency matrix:
    #
    #      n11  n12
    #      n21  n22
    #

	my ($n11, $n12, $n21, $n22, $twosided) = @_;

	if ($n11 * $n12 * $n21 * $n22 == 0) {

        Core::Utils::warn("chisq() function returned a NaN");

        return("NaN", "NaN");

    }

	my ($n, $chisq);
	$n = $n11 + $n12 + $n21 + $n22;
	$chisq = ($n * (abs($n11 * $n22 - $n12 * $n21) - 0.5 * $n) ** 2) / (($n11 + $n12) * ($n21 + $n22) * ($n11 + $n21) * ($n12 + $n22));

	return($chisq, pchisq($chisq));

}

sub fisher {

    # Contingency matrix:
    #
    #      n11  n12
    #      n21  n22
    #
    # n11 = successes in sample
    # n12 = successes in population - 1
    # n21 = fails in sample
    # n22 = fails in population

    my ($n11, $n12, $n21, $n22, $twosided) = @_;

    my ($test, $pvalue);
    $test = ($n11 * $n22) - ($n12 * $n21);

    if ($twosided &&
        $test < 0) {

        ($n11, $n12, $n21, $n22) = ($n12, $n11, $n22, $n21);
        $test = ($n11 * $n22) - ($n12 * $n21);

        if ($test < 0) {

            Core::Utils::warn("fisher() function returned a NaN");

            return("NaN");

        }

    }

    if ($test < 0) {

        if ($n22 < $n11) { $pvalue = _fisher($n22, $n21, $n12, $n11, $twosided, 1); }
        else { $pvalue = _fisher($n11, $n12, $n21, $n22, $twosided, 1); }

    }
    else {

        if ($n12 < $n21) { $pvalue = _fisher($n12, $n11, $n22, $n21, $twosided, 0); }
        else { $pvalue = _fisher($n21, $n22, $n11, $n12, $twosided, 0); }

    }

    return($pvalue);

}

sub _fisher {

    my ($n11, $n12, $n21, $n22, $twosided, $complement) = @_;

    if ($twosided && $complement) {

        Core::Utils::warn("_fisher() function returned a NaN");

        return("NaN");

    }

    my ($t11, $t12, $t21, $t22,
        $first, $delta, $pvalue);
    ($t11, $t12, $t21, $t22) = ($n11, $n12, $n21, $n22);
    $first = $delta = exp(logfact($t11 + $t12) + logfact($t21 + $t22) + logfact($t11 + $t21) +
                          logfact($t12 + $t22) - logfact($t11 + $t12 + $t21 + $t22) -
                          (logfact($t11) + logfact($t12) + logfact($t21) + logfact($t22)));
    $pvalue = 0;

    while ($t11 >= 1) {

        $pvalue += $delta;
        $delta *= (($t11-- * $t22--) / (++$t12 * ++$t21));

    }

    $pvalue += $delta;

    if ($twosided) {

        my ($m, $bound);

        $m = $n12 < $n21 ? $n12 : $n21;
        ($t11, $t12, $t21, $t22) = ($n11 + $m, $n12 - $m, $n21 - $m, $n22 + $m);
        $delta = exp(logfact($t11 + $t12) + logfact($t21 + $t22) + logfact($t11 + $t21) +
                     logfact($t12 + $t22) - logfact($t11 + $t12 + $t21 + $t22) -
                     (logfact($t11) + logfact($t12) + logfact($t21) + logfact($t22)));
        $bound = -$tolerance;

        if ($first) {

            while ($bound <= (($first - $delta) / $first) && $t11 > $n11) {

                $pvalue += $delta;
                $delta *= (($t11-- * $t22--) / (++$t12 * ++$t21));

            }

        }

    }
    elsif ($complement) { $pvalue = 1 - $pvalue + $first; }

    return(min($pvalue, 1));

}

sub logfact { return(gammln($_[0] + 1)); }

sub gammln {

    my $x = shift;

    my ($g, $base, @coefficients);
    $g = 4.7421875;
    @coefficients = (0.99999999999999709182, 57.156235665862923517, -59.597960355475491248,
                     14.136097974741747174, -0.49191381609762019978, 0.33994649984811888699e-4,
                     0.46523628927048575665e-4, -0.98374475304879564677e-4, 0.15808870322491248884e-3,
                     -0.21026444172410488319e-3, 0.21743961811521264320e-3, -.16431810653676389022e-3,
                     0.84418223983852743293e-4, -0.26190838401581408670e-4, 0.36899182659531622704e-5);

    if ($x < 0.5) { return(log(Core::Mathematics::pi / (sin(Core::Mathematics::pi * $x)) - gammln(1 - $x))); }
    else {

        my $tmp = $coefficients[0];
        $x -= 1;
        $tmp += $coefficients[$_] / ($x + $_) for (1 .. 14);
        $base = $x + $g + 0.5;

        return(((0.91893853320467274178 + log($tmp)) - $base) + log($base) * ($x + 0.5));

    }

}

sub gamnln {

    my $x = shift;

    my ($stp, $y, $t, $ser,
        @lg, @coeff);
    @lg = (0.5723649429247001, 0, -0.1207822376352452, 0, 0.2846828704729192, 0.6931471805599453, 1.200973602347074,
           1.791759469228055, 2.453736570842442, 3.178053830347946, 3.957813967618717, 4.787491742782046, 5.662562059857142,
           6.579251212010101, 7.534364236758733, 8.525161361065415, 9.549267257300997, 10.60460290274525, 11.68933342079727,
           12.80182748008147, 13.94062521940376, 15.10441257307552, 16.29200047656724, 17.50230784587389, 18.73434751193645,
           19.98721449566188, 21.2600761562447, 22.55216385312342, 23.86276584168909, 25.19122118273868, 26.53691449111561,
           27.89927138384089, 29.27775451504082, 30.67186010608068, 32.08111489594736, 33.50507345013689, 34.94331577687682,
           36.39544520803305, 37.86108650896109, 39.3398841871995, 40.8315009745308, 42.33561646075349, 43.85192586067515,
           45.3801388984769, 46.91997879580877, 48.47118135183522, 50.03349410501914, 51.60667556776437, 53.19049452616927,
           54.78472939811231, 56.38916764371993, 58.00360522298051, 59.62784609588432, 61.26170176100199, 62.9049908288765,
           64.55753862700632, 66.21917683354901, 67.88974313718154, 69.56908092082364, 71.257038967168, 72.9534711841694,
           74.65823634883016, 76.37119786778275, 78.09222355331531, 79.82118541361436, 81.55795945611503, 83.30242550295004,
           85.05446701758153, 86.81397094178108, 88.58082754219767, 90.35493026581838, 92.13617560368709, 93.92446296229978,
           95.71969454214322, 97.52177522288821, 99.33061245478741, 101.1461161558646, 102.9681986145138, 104.7967743971583,
           106.6317602606435, 108.4730750690654, 110.3206397147574, 112.1743770431779, 114.0342117814617, 115.9000704704145,
           117.7718813997451, 119.6495745463449, 121.5330815154387, 123.4223354844396, 125.3172711493569, 127.2178246736118,
           129.1239336391272, 131.0355369995686, 132.9525750356163, 134.8749893121619, 136.8027226373264, 138.7357190232026,
           140.6739236482343, 142.617282821146, 144.5657439463449, 146.5192554907206, 148.477766951773, 150.4412288270019,
           152.4095925844974, 154.3828106346716, 156.3608363030788, 158.3436238042692, 160.3311282166309, 162.3233054581712,
           164.3201122631952, 166.3215061598404, 168.3274454484277, 170.3378891805928, 172.3527971391628, 174.3721298187452,
           176.3958484069973, 178.4239147665485, 180.4562914175438, 182.4929415207863, 184.5338288614495, 186.5789178333379,
           188.6281734236716, 190.6815611983747, 192.7390472878449, 194.8005983731871, 196.86618167289, 198.9357649299295,
           201.0093163992815, 203.0868048358281, 205.1681994826412, 207.2534700596299, 209.3425867525368, 211.435520202271,
           213.5322414945632, 215.6327221499328, 217.7369341139542, 219.8448497478113, 221.9564418191303, 224.0716834930795,
           226.1905483237276, 228.3130102456502, 230.4390435657769, 232.5686229554685, 234.7017234428182, 236.8383204051684,
           238.9783895618343, 241.1219069670290, 243.2688490029827, 245.4191923732478, 247.5729140961868, 249.7299914986334,
           251.8904022097232, 254.0541241548883, 256.2211355500095, 258.3914148957209, 260.5649409718632, 262.7416928320802,
           264.9216497985528, 267.1047914568685, 269.2910976510198, 271.4805484785288, 273.6731242856937, 275.8688056629533,
           278.0675734403662, 280.2694086832001, 282.4742926876305, 284.6822069765408, 286.893133295427, 289.1070536083976,
           291.3239500942703, 293.5438051427607, 295.7666013507606, 297.9923215187034, 300.2209486470141, 302.4524659326413,
           304.6868567656687, 306.9241047260048, 309.1641935801469, 311.4071072780187, 313.652829949879, 315.9013459032995,
           318.1526396202093, 320.4066957540055, 322.6634991267262, 324.9230347262869, 327.1852877037753, 329.4502433708053,
           331.7178871969285, 333.9882048070999, 336.2611819791985, 338.5368046415996, 340.815058870799, 343.0959308890863,
           345.3794070622669, 347.6654738974312, 349.9541180407703, 352.2453262754350, 354.5390855194408, 356.835382823613,
           359.1342053695754);

    return($lg[$x - 1]) if ($x < 201);

    @coeff = (76.18009172947146, -86.50532032941677, 24.01409824083091, -1.231739572450155, 1.208650973866179e-3, -5.395239384953e-6);
    $stp = 2.5066282746310005;
    $x /= 2;
    $y = $x;
    $t = $x + 5.5;
    $t = ($x + 0.5) * log($t) - $t;
    $ser = 1.000000000190015;

    for (my $i = 0; $i < 6; $i++) {

        $y++;
        $ser += $coeff[$i] / $y;

    }

    return($t + log($stp * $ser / $x));

}

sub choose {

    my $total = shift;
    my $choose = shift if (@_);

    return(1) if (!$choose ||
                  $total == $choose);

    if ($choose < 20 &&
        $total < 20) {

        my ($min, $res);

        $min = $choose < ($total - $choose) ? $choose : $total - $choose;
        $res = $total / $min;

        while($min > 1) {

            $total--;
            $min--;
            $res = $res * $total / $min;

        }

        return($res);

    }
    else { return(exp(logfact($total) - logfact($choose) - logfact($total - $choose))); }

}

sub gini {

    my @values = @_;

    Core::Utils::throw("Values array is empty") if (!@values);
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@values));

    return(0) if (@values == 1);

    my ($mean, $gini);
    $mean = mean(@values);

    return(0) if (!$mean);

    for(my $i = 0; $i < @values; $i++) {

        for(my $j = 0; $j < @values; $j++) {

            next if ($i == $j);
            $gini += abs($values[$i] - $values[$j]);

        }

    }

    $gini /= 2 * (@values ** 2);
    $gini /= $mean;

    return($gini);

}

sub quantile {

    my ($values, $quantile) = @_;

    $quantile //= 0;

    Core::Utils::throw("Quantile value must be comprised between 0 and 4") if ($quantile < 0 ||
                                                                               $quantile > 4);
    Core::Utils::throw("Values must be provided as an ARRAY reference") if (ref($values) ne "ARRAY");
    Core::Utils::throw("Values array is empty") if (!@{$values});
    Core::Utils::throw("Values must be numeric") if (!isnumeric(@{$values}));

    my ($total, $k, $f, $ak,
        @data);
    $total = @{$values};
    @data = sort {$a <=> $b} @{$values};

    return($data[0]) unless($quantile);
    return($data[-1]) if ($quantile == 4);

    $k = (($quantile / 4) * ($total - 1) + 1);
    $f = $k - floor($k);
    $k = floor($k);
    $ak = $data[$k - 1];

    return($ak) unless($f);

    $ak += ($f * ($data[$k] - $ak));

    return($ak);

}

sub percentile {

    my ($values, $percentile) = @_;

    Core::Utils::throw("Percentile value must be comprised between 0 and 1") if ($percentile < 0 ||
                                                                                 $percentile > 1);

    return(quantile($values, $percentile * 4));

}

sub padjust {

    my ($pvalues, $method, $n) = @_;

    Core::Utils::throw("P-values must be provided as an ARRAY reference") if (ref($pvalues) ne "ARRAY");
    Core::Utils::throw("P-values array is empty") if (!@{$pvalues});
    Core::Utils::throw("P-values must be numeric") if (!isnumeric(@{$pvalues}));

    for (@{$pvalues}) { Core::Utils::throw("P-values must be comprised between 0 and 1") if ($_ < 0 ||
                                                                                             $_ > 1); }

    $n = defined $n && $n >= @{$pvalues} ? $n : @{$pvalues};
    $method ||= "BH";

    if ($method =~ m/^BH|BenjaminiHochberg$/i) { return(_padjust_bh($pvalues, $n)); }
    elsif ($method =~ m/^B(onferroni)?$/i) { return(_padjust_bonferroni($pvalues, $n)); }

    return();

}

sub _padjust_bh { # Benjamini-Hochberg

    my ($pvalues, $n) = @_;

    my ($lastfdr, $lasti, @sort, @adjusted);
    $lastfdr = -1e10;
    $lasti = -1;

    push(@sort, { pvalue => $pvalues->[$_],
                  index  => $_,
                  fdr    => 1 }) for (0 .. @{$pvalues} - 1);

    @sort = sort {$a->{pvalue} <=> $b->{pvalue}} @sort;

    for (my $i = 0; $i < @sort; $i++) {

        my $fdr = $sort[$i]->{pvalue} * $n / ($i + 1);

        if ($i < @sort - 1) { next if ($sort[$i]->{pvalue} == $sort[$i+1]->{pvalue}); }

        $fdr = $lastfdr if ($fdr < $lastfdr);
        $fdr = 1 if ($fdr > 1);

        for (my $j = $i; $j > $lasti; $j--) { $sort[$j]->{fdr} = $fdr; }

        $lastfdr = $fdr;
	    $lasti = $i;

    }

    push(@adjusted, $_->{fdr}) for (sort {$a->{index} <=> $b->{index}} @sort);

    return(wantarray() ? @adjusted : \@adjusted);

}

sub _padjust_bonferroni { # Bonferroni

    my ($pvalues, $n) = @_;

    my (@adjusted);

    push(@adjusted, min($_ * $n, 1)) for (@{$pvalues});

    return(wantarray() ? @adjusted : \@adjusted);

}

sub pchisq {

    my $chi = shift;
    my $df = shift || 1;

    return(gammq(($df / 2), ($chi / 2)));

}

sub gammq {

    my ($a, $x) = @_;

    if (ispositive($x) &&
        ispositive($a) &&
        $a > 0) {

        my ($gamser, $gln) = (0, 0);

        if ($x < ($a + 1)) {

            ($gamser, $gln) = gser($a, $x);

            return(1 - $gamser);

        }
        else {

            ($gamser, $gln) = gcf($a, $x);

            return($gamser);

        }

    }
    else { Core::Utils::throw("Invalid values in gammq()"); }

    return();

}

sub gser {

    my ($a, $x) = @_;

    my ($gln, $gamser);
    $gln = gammln($a);

    if ($x <= 0) {

        $gamser = 0;
        return($gamser, $gln);

    }
    else {

        my ($ap, $del, $sum);
        $ap = $a;
        $del = 1 / $a;
        $sum = $del;

        for (my $i = 1; $i <= ITMAX; $i++) {

            $ap++;
            $del *= $x / $ap;
            $sum += $del;

            if (abs($del) < abs($sum) * EPS) {

                $gamser = $sum * exp((-1 * $x) + ($a * log($x)) - $gln);

                return ($gamser, $gln);

            }

        }

        Core::Utils::warn("Reached maximum iterations limit for gser()");

        return ($gamser, $gln);

    }

    return();

}

sub gcf {

    my ($a, $x) = @_;

    my ($gammcf, $gln, $b, $c,
        $d, $h, $i, $del);
    $gammcf = 0;
    $gln = gammln($a);
    $b = $x + 1 - $a;
    $c = 1 / FPMIN;
    $d = 1 / $b;
    $h = $d;
    $i = 1;

    for ($i = 1; $i <= ITMAX; $i++) {

        my $an = $i * ($i - $a);
        $b += 2.0;
        $d = $an * $d + $b;

        $d = FPMIN if (abs($d) < FPMIN);

        $c = $b + ($an / $c);

        $c = FPMIN if (abs($c) < FPMIN);

        $d = 1 / $d;
        $del = $d * $c;
        $h *= $del;

        last if (abs($del - 1.0) < EPS);

    }

    Core::Utils::warn("Reached maximum iterations limit for gcf()") if ($i > ITMAX);

    $gammcf = exp((-1 * $x) + ($a * log($x)) - $gln) * $h;

    return ($gammcf, $gln);

}

sub qnorm {

    # http://rangevoting.org/NHack.html

    my $p = shift;

    if ($p < 0 ||
        $p > 1) {

        Core::Utils::warn("qnorm() function returned a NaN");

        return("NaN");

    }

    return("inf") if ($p == 1);
    return("-inf") if ($p == 0);

    my ($split, $q, $r, $ppnd,
        @a, @b, @c, @d);
    $split = 0.425;
    $q = $p - 0.5;
    @a = (2.50662823884, -18.61500062529, 41.39119773534, -25.44106049637);
    @b = (-8.47351093090, 23.08336743743, -21.06224101826, 3.13082909833);
    @c = (-2.78718931138, -2.29796479134, 4.85014127135, 2.32121276858);
    @d = (3.54388924762, 1.63706781897);

    if (abs($q) <= $split) {

        $r = $q ** 2;
        $ppnd = $q * ((($a[3] * $r + $a[2]) * $r + $a[1]) * $r + $a[0]) / (((($b[4] * $r + $b[3]) * $r + $b[2]) * $r + $b[1]) * $r + 1);

    }
    else {

        $r = $q > 0 ? 1 - $p : $p;

        if ($r > 0) {

            $r = sqrt(-log($r));
            $ppnd = ((($c[3] * $r + $c[2]) * $r + $c[1]) * $r + $c[0]) / (($d[1] * $r + $d[0]) * $r + 1);
            $ppnd *= -1 if ($q < 0);

        }
        else { $ppnd = 0; }

    }

    return($ppnd);

}

sub pnorm {

    # http://rangevoting.org/NHack.html

    my $z = shift;
    my $lowertail = shift if (@_);

    my ($ltone, $utzero, $con, $alnorm,
        @a, @b);
    $ltone = 7;
    $utzero = 18.66;
    $con = 1.28;
    @a = (0.398942280444, 0.399903438504, 5.75885480458, 29.8213557808,
          2.62433121679, 48.6959930692, 5.92885724438);
    @b = (0.398942280385, 3.8052e-8, 1.00000615302, 3.98064794e-4,
          1.986153813664, 0.151679116635, 5.29330324926, 4.8385912808,
          15.1508972451, 0.742380924027, 30.789933034, 3.99019417011);

    if ($z < 0) {

        $lowertail = 0;
        $z *= -1;

    }

    if ($z <= $ltone ||
        !$lowertail &&
        $z <= $utzero) {

        my $y = 0.5 * ($z ** 2);

        if ($z > $con ) { $alnorm = $b[0] * exp(-$y) / ($z - $b[1] + $b[2] / ($z + $b[3] + $b[4] / ($z - $b[5] + $b[6] / ($z + $b[7] - $b[8] / ($z + $b[9] + $b[10] / ($z + $b[11])))))); }
        else { $alnorm = 0.5 - $z * ($a[0] - $a[1] * $y / ($y + $a[2] - $a[3] / ($y + $a[4] + $a[5] / ($y + $a[6]))));}

    }
    else { $alnorm = 0; }

    return($lowertail ? 1 - $alnorm : $alnorm);

}


sub pcombine {

    my ($pvalues, $method) = @_;


    Core::Utils::throw("P-values must be provided as an ARRAY reference") if (ref($pvalues) ne "ARRAY");
    Core::Utils::throw("P-values array is empty") if (!@{$pvalues});
    Core::Utils::throw("P-values must be numeric") if (!isnumeric(@{$pvalues}));

    for (@{$pvalues}) {

        Core::Utils::throw("P-values must be comprised between 0 and 1") if ($_ < 0 ||
                                                                             $_ > 1);

        # P-values 0 are adjusted to avoid crash with log(pvalue)
        $_ = 1e-308 if ($_ == 0);

    }

    $method ||= "S";
    my $n = @{$pvalues};

    if ($method =~ m/^S(touffer)?$/i) { return(_pcombine_stouffer($pvalues, $n)); }
    elsif ($method =~ m/^F(isher)?$/i) { return(_pcombine_fisher($pvalues, $n)); }

    return();

}

sub _pcombine_stouffer {

    my ($pvalues, $n) = @_;

    my ($p);
    $p += qnorm($_) / sqrt($n) for (@{$pvalues});

    return(pnorm($p, 1));

}

sub _pcombine_fisher {

    my ($pvalues, $n) = @_;

    my ($p);
    $p += log($_) for (@{$pvalues});

    return(pchisq(-2 * $p, 2 * $n));

}

sub betai {

    my ($a, $b, $x) = @_;

    my ($bt, $eeps);
    $bt = 0;
    $eeps = 1e-10;

    Core::Utils::throw("betai() variable x value must be comprised between -1e-10 and 1+1e-10") if ($x < -$eeps ||
                                                                                                    $x > 1.0 + $eeps);

    $x = $x < 0 ? 0 : ($x > 1 ? 1 : $x);
    $bt = ($x == 0 || $x == 1) ? 0 : exp(gammln($a + $b) - gammln($a) - gammln($b) + $a * log($x) + $b * log(1 - $x));

    if ($x < ($a + 1 ) / ($a + $b + 2)) { return($bt * betacf($a, $b, $x) / $a); }
    else { return(1 - $bt * betacf($b, $a, 1 - $x) / $b); }

}

sub betacf {

    my ($a, $b, $x) = @_;

    my ($m, $m2, $aa, $c,
        $d, $del, $h, $qab,
        $qam, $qap);
    ($m, $m2, $aa, $del) = (0,0,0,0);
    $qab = $a + $b;
    $qap = $a + 1;
    $qam = $a - 1;
    $c = 1;
    $d = 1 - $qab * $x / $qap;
    $d = FPMIN if (abs($d) < FPMIN);
    $d = 1 / $d;
    $h = $d;

    for(my $m = 1; $m <= ITMAX; $m++) {

        $m2= 2 * $m;
        $aa = $m * ($b - $m) * $x / (($qam + $m2) * ($a + $m2));
        $d = 1 + $aa * $d;
        $d = FPMIN if (abs($d) < FPMIN);
        $c = 1 + $aa / $c;
        $c = FPMIN if (abs($c) < FPMIN);
        $d = 1 / $d;
        $h *= $d * $c;
        $aa = -($a + $m) * ($qab + $m) * $x / (($a + $m2) * ($qap + $m2));
        $d = 1 + $aa* $d;
        $d = FPMIN if (abs($d) < FPMIN);
        $c = 1 + $aa / $c;
        $c = FPMIN if (abs($c) < FPMIN);
        $d = 1 / $d;
        $del = $d * $c;
        $h *= $del;

        last if (abs($del - 1) < EPS);

        Core::Utils::throw("Reached maximum iterations limit for betacf()") if ($m == ITMAX);

    }

    return($h);

}

sub ttest { # Welch's t-test

    my @data = @_[0..1];
    my $params = checkparameters({ paired => 0,
                                   type   => "two.sided" }, $_[2] || {});

    for (@data) {

        Core::Utils::throw("Values must be provided as ARRAY references") if (ref($_) ne "ARRAY");
        Core::Utils::throw("Less than 2 observations in ARRAY") if (@{$_} < 2);

    }

    Core::Utils::throw("Insufficient parameters") if (@data < 2);
    Core::Utils::throw("Values ARRAY references are empty") if (@{$data[0]} <= 1);

    my ($df, $t, $p, @variance);

    if ($params->{paired}) {

        Core::Utils::throw("Values ARRAY references have different sizes") if (@{$data[0]} != @{$data[1]});

        my ($nx, @x);
        $nx = @{$data[0]};
        $df = $nx - 1;
        @x = map { $data[0]->[$_] - $data[1]->[$_] } 0 .. $nx - 1;
        @variance = (variance(\@x, 1));
        $t = mean(@x) / sqrt($variance[0] / $nx);

    }
    else {

        $df = @{$data[0]} + @{$data[1]} - 2;
        @variance = (variance($data[0], 1), variance($data[1], 1));

        return("NaN", "NaN") if (!$variance[0] &&
                                 !$variance[1]);

        $df = (($variance[0] / @{$data[0]}) + ($variance[1]/ @{$data[1]})) ** 2;
        $df /= ($variance[0] / @{$data[0]}) ** 2 / (@{$data[0]} - 1) + ($variance[1] / @{$data[1]}) ** 2 / (@{$data[1]} - 1);

        $t = (mean(@{$data[0]}) - mean(@{$data[1]})) / sqrt(($variance[0] / @{$data[0]}) + ($variance[1] / @{$data[1]}));

    }

    $p = _pt($t, $df, $params->{type});

    return($t, $p);

}

sub _pt {

    my ($t, $df, $type) = @_;

    my $p = betai(0.5 * $df, 0.5, $df / ($df + $t ** 2));
    $type = "two.sided" if (!defined $type);

    if ($type eq "less") { $p = $t > 0 ? 1 - 0.5 * $p : 0.5 * $p; }
    elsif ($type eq "greater") { $p = $t > 0 ? 0.5 * $p : 1 - 0.5 * $p; }
    elsif ($type eq "equal") { $p = 1 - $p; }

    return($p);

}

sub fact {

    my $n = shift || 1;

    if ($n > 170) {

        Core::Utils::warn("Factorial out of range");

        return("inf");

    }
    else { return(reduce { $a * $b } 1 .. $n); }

}

sub _binomial {

    my ($k, $n, $p) = @_;

    if (!$p) {

        if ($k) { return(0); }
        else { return(1); }

    }

    my $prob = 0;

    if ($n > 100) {

        my ($sigma, $mu, $const, $exponent);
        $mu = $n * $p;
        $sigma = sqrt($mu * (1 - $p));
        $const = 1 / ($sigma * sqrt(2 * Core::Mathematics::pi));
        $exponent = -0.5 * (($k - $mu) / $sigma)**2;
        $prob = $const * exp($exponent);

    }
    else { $prob = ($p ** $k) * ((1 - $p) ** ($n - $k)) * choose($n, $k); }

    return($prob);

}

sub binomialTest {

	my ($k, $n, $p, $mode) = @_;

    my ($pvalue);

    if (!$mode || $mode eq "two.sided") {

        my ($ref, %seen);
        $ref = _binomial($k, $n, $p);

        for (0 .. $n) {

            my $p = _binomial($_, $n, $p);

            last if (exists $seen{$_});
            last if ($p > $ref);

            $seen{$_} = 1;
            $pvalue += $p;

        }

        for (-$n .. 0) {

            my $p = _binomial(-$_, $n, $p);

            last if (exists $seen{-$_});
            last if ($p > $ref);

            $seen{-$_} = 1;
            $pvalue += $p;

        }

    }
    else {

        $k++ if ($mode eq "less");

        if (!$p) {

            if ($k) { return($mode eq "less" ? 1 : 0); }
            else { return(1); }

        }

        return(1) if (!$k);

        $pvalue = betai($k, $n - $k + 1, $p);
        $pvalue = 1 - $pvalue if ($mode eq "less");

    }

    return($pvalue)

}

1;
