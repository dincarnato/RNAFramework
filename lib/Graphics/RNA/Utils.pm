package Graphics::RNA::Utils;

use strict;
use POSIX qw(fmod);

use Core::Mathematics;

use base qw(Exporter);

our @EXPORT = qw(drawRadiate drawNAView scoreOverlaps);

use constant LOOP_DISTANCE      => 40.0;
use constant BASE_PAIR_DISTANCE => 65.0;
use constant MULTILOOP_DISTANCE => 35.0;
use constant HYSTERESIS_EPSILON => 0.15;

my @HYSTERESIS_ATTRACTORS = (0, Core::Mathematics::pi / 4, Core::Mathematics::pi / 2, 3 * Core::Mathematics::pi / 4,
                             Core::Mathematics::pi, 5 * Core::Mathematics::pi / 4, 3 * Core::Mathematics::pi / 2, 7 * Core::Mathematics::pi / 4);

sub _asin { my $x = shift; $x = 1 if ($x > 1); $x = -1 if ($x < -1); return(atan2($x, sqrt(1 - $x * $x))); }

sub _normalizeAngle {

    my ($angle, $from) = @_;
    $from = 0 if (!defined $from);

    my $to = $from + 2 * Core::Mathematics::pi;
    my $r = $angle;

    while ($r < $from) { $r += 2 * Core::Mathematics::pi; }
    while ($r >= $to) { $r -= 2 * Core::Mathematics::pi; }

    return($r);

}

sub _correctHysteresis {

    my $angle = shift;

    my $r = _normalizeAngle($angle);

    foreach my $att (@HYSTERESIS_ATTRACTORS) { $r = $att if (abs(_normalizeAngle($att - $r, -Core::Mathematics::pi)) < HYSTERESIS_EPSILON); }

    return($r);

}

sub _objFun {

    my ($n1, $n2, $r, $bpdist, $multidist) = @_;

    return($n1 * 2 * _asin($bpdist / (2 * $r)) + $n2 * 2 * _asin($multidist / (2 * $r)) - 2 * Core::Mathematics::pi);

}

sub _determineRadius {

    my ($nbHel, $nbUnpaired, $startRadius, $bpdist, $multidist) = @_;
    $bpdist = BASE_PAIR_DISTANCE if (!defined $bpdist);
    $multidist = MULTILOOP_DISTANCE if (!defined $multidist);

    my ($xmin, $xmax, $x, $y, $numIt);
    $xmin = $bpdist / 2;
    $xmax = 3 * $multidist + 1;
    $x = ($xmin + $xmax) / 2;
    $y = 10000;
    $numIt = 0;

    while (abs($y) > 1e-5 && $numIt < 10000) {

        $x = ($xmin + $xmax) / 2;
        $y = _objFun($nbHel, $nbUnpaired, $x, $bpdist, $multidist);

        my $ymin = _objFun($nbHel, $nbUnpaired, $xmax, $bpdist, $multidist);
        my $ymax2 = _objFun($nbHel, $nbUnpaired, $xmin, $bpdist, $multidist);

        if ($ymin > 0) { $xmax = $xmax + ($xmax - $xmin); }
        elsif ($y <= 0 && $ymax2 > 0) { $xmax = $x; }
        elsif ($y >= 0 && $ymin < 0) { $xmin = $x; }
        elsif ($ymax2 < 0) {

            my $lo = $bpdist / 2 > $multidist / 2 ? $bpdist / 2 : $multidist / 2;
            my $cand = $xmin - ($x - $xmin);
            $xmin = $cand > $lo ? $cand : $lo;
            $xmax = $x;

        }

        $numIt++;

    }

    return($x);

}

#
# Radiate layout, ported from Yann Ponty's VARNA via RFview.js
# $pairs is a 0-based arrayref where $pairs->[$i] is the index paired to $i, or -1
#
sub drawRadiate {

    my ($pairs, $n, $dirAngle, $flatExteriorLoop, $straightBulges) = @_;
    $dirAngle = -1.0 if (!defined $dirAngle);
    $flatExteriorLoop = 1 if (!defined $flatExteriorLoop);
    $straightBulges = 1 if (!defined $straightBulges);

    my (@coords, @centers, @angles);
    @coords = map { { x => 0, y => 0 } } (1 .. $n);
    @centers = map { { x => 0, y => 0 } } (1 .. $n);
    @angles = (0) x $n;

    my $drawLoop;
    $drawLoop = sub {

        my ($i, $j, $x, $y, $dir) = @_;

        return if ($i > $j);

        if ($pairs->[$i] == $j) {

            my $na = Core::Mathematics::pi / 2;

            $centers[$i] = { x => $x, y => $y };
            $centers[$j] = { x => $x, y => $y };
            $coords[$i] = { x => $x + BASE_PAIR_DISTANCE * cos($dir - $na) / 2,
                            y => $y + BASE_PAIR_DISTANCE * sin($dir - $na) / 2 };
            $coords[$j] = { x => $x + BASE_PAIR_DISTANCE * cos($dir + $na) / 2,
                            y => $y + BASE_PAIR_DISTANCE * sin($dir + $na) / 2 };

            $drawLoop->($i + 1, $j - 1, $x + LOOP_DISTANCE * cos($dir), $y + LOOP_DISTANCE * sin($dir), $dir);

            return;

        }

        my (@basesML, @helices);
        my $k = $i;

        while ($k <= $j) {

            my $l = $pairs->[$k];

            if ($l > $k) {

                push(@basesML, $k, $l);
                push(@helices, $k);
                $k = $l + 1;

            }
            else {

                push(@basesML, $k);
                $k++;

            }

        }

        my ($mlSize, $numHel, $totalLen, $mlR, $aiBP, $aiML);
        $mlSize = @basesML + 2;
        $numHel = @helices + 1;
        $totalLen = MULTILOOP_DISTANCE * ($mlSize - $numHel) + BASE_PAIR_DISTANCE * $numHel;

        if ($mlSize > 3) {

            $mlR = _determineRadius($numHel, $mlSize - $numHel, $totalLen / (2 * Core::Mathematics::pi));
            $aiBP = -2 * _asin(BASE_PAIR_DISTANCE / (2 * $mlR));
            $aiML = -2 * _asin(MULTILOOP_DISTANCE / (2 * $mlR));

        }
        else {

            $mlR = 35;
            $aiBP = -2 * _asin(BASE_PAIR_DISTANCE / (2 * $mlR));
            $aiML = (-2 * Core::Mathematics::pi - $aiBP) / 2;

        }

        my $sq = $mlR * $mlR - (BASE_PAIR_DISTANCE / 2) ** 2;
        $sq = 0 if ($sq < 0);

        my $centerDist = sqrt($sq) - LOOP_DISTANCE;
        my $mlCenter = { x => $x + $centerDist * cos($dir),
                         y => $y + $centerDist * sin($dir) };

        my $baseAngle = $dir + Core::Mathematics::pi + 0.5 * $aiBP + $aiML;
        my (@currUnpaired, @intervals, %currInterval);
        %currInterval = (second => $baseAngle - $aiML);

        for (my $ki = $#basesML; $ki >= 0; $ki--) {

            my $l = $basesML[$ki];
            $centers[$l] = $mlCenter;

            my $paired = ($pairs->[$l] != -1);
            my $paired3 = ($paired && $pairs->[$l] < $l);
            my $paired5 = ($paired && !$paired3);

            if ($paired3) {

                $baseAngle = ($numHel == 2 && $straightBulges) ? $dir - $aiBP / 2
                                                               : _correctHysteresis($baseAngle + $aiBP / 2) - $aiBP / 2;
                $currInterval{first} = $baseAngle;
                push(@intervals, { unpaired => [@currUnpaired], interval => { %currInterval } });
                %currInterval = ();
                @currUnpaired = ();

            }
            elsif ($paired5) { $currInterval{second} = $baseAngle; }
            else { push(@currUnpaired, $l); }

            $angles[$l] = $baseAngle;
            $baseAngle += ($paired3 ? $aiBP : $aiML);

        }

        $currInterval{first} = $dir - Core::Mathematics::pi - 0.5 * $aiBP;
        push(@intervals, { unpaired => [@currUnpaired], interval => { %currInterval } });

        foreach my $iv (@intervals) {

            my ($unpaired, $interval) = ($iv->{unpaired}, $iv->{interval});
            my $mina = $interval->{first};
            my $maxa = _normalizeAngle($interval->{second}, $mina);

            for (my $ni = 0; $ni < @{$unpaired}; $ni++) {

                my $ratio = (1 + $ni) / (1 + @{$unpaired});
                $angles[$unpaired->[$ni]] = $mina + (1 - $ratio) * ($maxa - $mina);

            }

        }

        for (my $ki = $#basesML; $ki >= 0; $ki--) {

            my $l = $basesML[$ki];
            $coords[$l] = { x => $mlCenter->{x} + $mlR * cos($angles[$l]),
                            y => $mlCenter->{y} + $mlR * sin($angles[$l]) };

        }

        foreach my $hBase (@helices) {

            my $hPair = $pairs->[$hBase];
            my $newAngle = ($angles[$hBase] + $angles[$hPair]) / 2;

            $drawLoop->($hBase + 1, $hPair - 1,
                        LOOP_DISTANCE * cos($newAngle) + ($coords[$hBase]->{x} + $coords[$hPair]->{x}) / 2,
                        LOOP_DISTANCE * sin($newAngle) + ($coords[$hBase]->{y} + $coords[$hPair]->{y}) / 2,
                        $newAngle);

        }

    };

    if ($flatExteriorLoop) {

        my $da = $dirAngle + 1.0 - Core::Mathematics::pi / 2;
        my ($vx, $vy) = (-sin($da), cos($da));
        my ($px, $py, $i) = (0, 0, 0);

        while ($i < $n) {

            $coords[$i] = { x => $px, y => $py };
            $centers[$i] = { x => $px + BASE_PAIR_DISTANCE * $vy,
                             y => $py - BASE_PAIR_DISTANCE * $vx };

            my $j = $pairs->[$i];

            if ($j > $i) {

                $drawLoop->($i, $j, $px + BASE_PAIR_DISTANCE * $vx / 2, $py + BASE_PAIR_DISTANCE * $vy / 2, $da);
                $centers[$i] = { x => $coords[$i]->{x} + BASE_PAIR_DISTANCE * $vy,
                                 y => $py - BASE_PAIR_DISTANCE * $vx };
                $i = $j;
                $px += BASE_PAIR_DISTANCE * $vx;
                $py += BASE_PAIR_DISTANCE * $vy;
                $centers[$i] = { x => $coords[$i]->{x} + BASE_PAIR_DISTANCE * $vy,
                                 y => $py - BASE_PAIR_DISTANCE * $vx };

            }

            $px += MULTILOOP_DISTANCE * $vx;
            $py += MULTILOOP_DISTANCE * $vy;
            $i++;

        }

    }
    else { $drawLoop->(0, $n - 1, 0, 0, $dirAngle); }

    return({ coords => \@coords, centers => \@centers, pairs => $pairs, n => $n });

}

#
# NAView layout, ported from Ivo Hofacker's adaptation of the Bruccoleri &
# Heinrich algorithm via RFview.js
#
sub drawNAView {

    my ($pairs, $n) = @_;

    # The loop graph degenerates below 3 bases (a single base would be made to
    # pair with itself), so the trivial case is handed to the radiate layout,
    # which places short unbranched stretches identically anyway
    return(drawRadiate($pairs, $n)) if ($n < 3);

    my $ANUM = 9999.0;
    my $LENCUT = 0.5;
    my $SCALE = BASE_PAIR_DISTANCE;

    # 1-indexed bases (index 0 is a virtual origin)
    my @bases = map { { mate => 0, x => $ANUM, y => $ANUM,
                        extracted => 0, region => undef, loopCenter => undef } } (0 .. $n);

    my $npairs = 0;

    for my $i (1 .. $n) {

        $bases[$i]->{mate} = ($pairs->[$i - 1] == -1) ? 0 : $pairs->[$i - 1] + 1;
        $npairs++ if ($bases[$i]->{mate} > $i);

    }

    if (!$npairs) {

        $bases[1]->{mate} = $n;
        $bases[$n]->{mate} = 1;

    }

    # find_regions: a region is a maximal stack of consecutive base pairs
    my (@regions, @mark);
    @mark = (0) x ($n + 1);

    for my $i (0 .. $n) {

        my $mate = $bases[$i]->{mate};

        if ($mate && !$mark[$i]) {

            my $reg = { start1 => $i, end1 => 0, start2 => 0, end2 => $mate };
            $mark[$i] = $mark[$mate] = 1;
            $bases[$i]->{region} = $bases[$mate]->{region} = $reg;

            my ($ii, $m) = ($i + 1, $mate - 1);

            while ($ii < $m && $bases[$ii]->{mate} == $m) {

                $mark[$ii] = $mark[$m] = 1;
                $bases[$ii]->{region} = $bases[$m]->{region} = $reg;
                $ii++;
                $m--;

            }

            $reg->{end1} = $ii - 1;
            $reg->{start2} = $m + 1;

            push(@regions, $reg);

        }

    }

    # construct_loop: build the loop graph recursively
    my (@loops, $constructLoop);

    $constructLoop = sub {

        my $ibase = shift;

        my $retloop = { nconnection => 0, connections => [], depth => 0,
                        number => scalar(@loops) + 1, radius => 0, x => 0, y => 0, mark => 0 };
        push(@loops, $retloop);

        my $i = $ibase;

        do {

            my $mate = $bases[$i]->{mate};

            if ($mate != 0) {

                my $rp = $bases[$i]->{region};

                if (!$bases[$rp->{start1}]->{extracted}) {

                    my $lp;
                    $bases[$rp->{start1}]->{extracted} = $bases[$rp->{end1}]->{extracted} =
                        $bases[$rp->{start2}]->{extracted} = $bases[$rp->{end2}]->{extracted} = 1;

                    if ($i == $rp->{start1}) { $lp = $constructLoop->($rp->{end1} < $n ? $rp->{end1} + 1 : 0); }
                    else { $lp = $constructLoop->($rp->{end2} < $n ? $rp->{end2} + 1 : 0); }

                    my $cp1 = { loop => $lp, region => $rp,
                                start => $i == $rp->{start1} ? $rp->{start1} : $rp->{start2},
                                end => $i == $rp->{start1} ? $rp->{end2} : $rp->{end1},
                                xrad => 0, yrad => 0, angle => 0, extruded => 0, broken => 0 };
                    push(@{$retloop->{connections}}, $cp1);
                    $retloop->{nconnection}++;

                    my $cp2 = { loop => $retloop, region => $rp,
                                start => $i == $rp->{start1} ? $rp->{start2} : $rp->{start1},
                                end => $i == $rp->{start1} ? $rp->{end1} : $rp->{end2},
                                xrad => 0, yrad => 0, angle => 0, extruded => 0, broken => 0 };
                    push(@{$lp->{connections}}, $cp2);
                    $lp->{nconnection}++;

                }

                $i = $mate;

            }

            $i = 0 if (++$i > $n);

        } while ($i != $ibase);

        return($retloop);

    };

    $constructLoop->(0);

    # depth + find_central_loop
    my $getDepth;
    $getDepth = sub {

        my $lp = shift;

        return(0) if ($lp->{nconnection} <= 1);
        return(-1) if ($lp->{mark});

        $lp->{mark} = 1;

        my ($ret, $count) = (0, 0);

        for my $ci (0 .. $lp->{nconnection} - 1) {

            my $d = $getDepth->($lp->{connections}->[$ci]->{loop});

            if ($d >= 0) {

                if (++$count == 1) { $ret = $d; }
                elsif ($d < $ret) { $ret = $d; }

            }

        }

        $lp->{mark} = 0;

        return($ret + 1);

    };

    for my $li (0 .. $#loops) {

        $_->{mark} = 0 for (@loops);
        $loops[$li]->{depth} = $getDepth->($loops[$li]);

    }

    my ($root, $maxconn, $maxdepth) = ($loops[0], 0, -1);

    for my $lp (@loops) {

        if ($lp->{nconnection} > $maxconn ||
            ($lp->{nconnection} == $maxconn && $lp->{depth} > $maxdepth)) {

            $maxconn = $lp->{nconnection};
            $maxdepth = $lp->{depth};
            $root = $lp;

        }

    }

    # determine_radius
    my $naviewDetermineRadius = sub {

        my $lp = shift;

        my $RT2_2 = 0.7071068;
        my ($radius, $mindit, $sumn, $sumd, $imindit, $restart);

        do {

            $restart = 0;
            $mindit = 1e10;
            $sumn = 0;
            $sumd = 0;
            $imindit = 0;

            for my $i (0 .. $lp->{nconnection} - 1) {

                my $cp = $lp->{connections}->[$i];
                my $cpnext = $lp->{connections}->[($i + 1) % $lp->{nconnection}];
                my ($end, $start) = ($cp->{end}, $cpnext->{start});
                $start += $n + 1 if ($start <= $end);

                my $dt = $cpnext->{angle} - $cp->{angle};
                $dt += 2 * Core::Mathematics::pi if ($dt <= 0);

                my $ci = $cp->{extruded} ? ($dt <= Core::Mathematics::pi / 2 ? 2.0 : 1.5) : ($start - $end);
                $sumn += $dt * (1.0 / $ci + 1.0);
                $sumd += $dt * $dt / $ci;

                my $dit = $dt / $ci;

                if ($dit < $mindit && !$cp->{extruded} && $ci > 1.0) {

                    $mindit = $dit;
                    $imindit = $i;

                }

            }

            $radius = $sumn / $sumd;
            $radius = $RT2_2 if ($radius < $RT2_2);

            if ($mindit * $radius < $LENCUT) {

                $lp->{connections}->[$imindit]->{extruded} = 1;
                $restart = 1;

            }

        } while ($restart);

        if ($lp->{radius} > 0) { $radius = $lp->{radius}; }
        else { $lp->{radius} = $radius; }

    };

    # find_center_for_arc
    my $findCenterForArc = sub {

        my ($nn, $b) = @_;

        my $hhi = ($nn + 1) / Core::Mathematics::pi;
        my $hlow = $b < 1 ? 0 : -$hhi - $b / ($nn + 1.000001 - $b);
        my ($h, $r, $disc, $theta, $phi, $e);
        my $iter = 0;

        do {

            $h = ($hhi + $hlow) / 2;
            $r = sqrt($h * $h + $b * $b / 4);
            $disc = 1 - 0.5 / ($r * $r);
            $disc = 1 if ($disc > 1);
            $disc = -1 if ($disc < -1);
            $theta = _acos($disc);
            my $hr = $h / $r;
            $hr = 1 if ($hr > 1);
            $hr = -1 if ($hr < -1);
            $phi = _acos($hr);
            $e = $theta * ($nn + 1) + 2 * $phi - 2 * Core::Mathematics::pi;

            if ($e > 0) { $hlow = $h; }
            else { $hhi = $h; }

        } while (abs($e) > 0.0001 && ++$iter < 500);

        return({ h => $iter < 500 ? $h : 0, theta => $iter < 500 ? $theta : 0 });

    };

    # construct_circle_segment
    my $constructCircleSegment = sub {

        my ($start, $end) = @_;

        my $dx = $bases[$end]->{x} - $bases[$start]->{x};
        my $dy = $bases[$end]->{y} - $bases[$start]->{y};
        my $rr = sqrt($dx * $dx + $dy * $dy);
        my $l = $end - $start;
        $l += $n + 1 if ($l < 0);

        if ($rr >= $l) {

            $dx /= $rr;
            $dy /= $rr;

            for my $j (1 .. $l - 1) {

                my $idx = $start + $j;
                $idx -= $n + 1 if ($idx > $n);
                $bases[$idx]->{x} = $bases[$start]->{x} + $dx * $j / $l;
                $bases[$idx]->{y} = $bases[$start]->{y} + $dy * $j / $l;

            }

        }
        else {

            my $arc = $findCenterForArc->($l - 1, $rr);
            $dx /= $rr;
            $dy /= $rr;

            my $midx = $bases[$start]->{x} + $dx * $rr / 2;
            my $midy = $bases[$start]->{y} + $dy * $rr / 2;
            my ($xn, $yn) = ($dy, -$dx);
            my $nrx = $midx + $arc->{h} * $xn;
            my $nry = $midy + $arc->{h} * $yn;
            my $mx = $bases[$start]->{x} - $nrx;
            my $my = $bases[$start]->{y} - $nry;
            my $arcR = sqrt($mx * $mx + $my * $my);
            my $a = atan2($my, $mx);

            for my $j (1 .. $l - 1) {

                my $idx = $start + $j;
                $idx -= $n + 1 if ($idx > $n);
                $bases[$idx]->{x} = $nrx + $arcR * cos($a + $j * $arc->{theta});
                $bases[$idx]->{y} = $nry + $arcR * sin($a + $j * $arc->{theta});

            }

        }

    };

    # construct_extruded_segment
    my $constructExtrudedSegment = sub {

        my ($cp, $cpnext) = @_;

        my $astart = $cp->{angle};
        my $aend1 = $cpnext->{angle};
        my $aend2 = $aend1 < $astart ? $aend1 + 2 * Core::Mathematics::pi : $aend1;
        my $aave = ($astart + $aend2) / 2;
        my ($start, $end) = ($cp->{end}, $cpnext->{start});
        my $num = $end - $start;
        $num += $n + 1 if ($num < 0);

        my $da = fmod((($cpnext->{angle} - $cp->{angle}) + 2 * Core::Mathematics::pi), (2 * Core::Mathematics::pi));

        if ($num == 2) {

            $constructCircleSegment->($start, $end);

            return;

        }

        my $dx = $bases[$end]->{x} - $bases[$start]->{x};
        my $dy = $bases[$end]->{y} - $bases[$start]->{y};
        my $rr = sqrt($dx * $dx + $dy * $dy);
        $dx /= $rr;
        $dy /= $rr;

        if ($rr >= 1.5 && $da <= Core::Mathematics::pi / 2) {

            my $ns = $start + 1;
            $ns -= $n + 1 if ($ns > $n);
            my $ne = $end - 1;
            $ne += $n + 1 if ($ne < 0);
            $bases[$ns]->{x} = $bases[$start]->{x} + 0.5 * $dx;
            $bases[$ns]->{y} = $bases[$start]->{y} + 0.5 * $dy;
            $bases[$ne]->{x} = $bases[$end]->{x} - 0.5 * $dx;
            $bases[$ne]->{y} = $bases[$end]->{y} - 0.5 * $dy;
            $start = $ns;
            $end = $ne;

        }

        my ($collision, $safetyCount) = (0, 0);

        do {

            $collision = 0;
            $constructCircleSegment->($start, $end);

            my $ns2 = $start + 1;
            $ns2 -= $n + 1 if ($ns2 > $n);
            my $ddx = $bases[$ns2]->{x} - $bases[$start]->{x};
            my $ddy = $bases[$ns2]->{y} - $bases[$start]->{y};
            my $a1 = atan2($ddy, $ddx);
            $a1 += 2 * Core::Mathematics::pi if ($a1 < 0);
            my $dac = $a1 - $astart;
            $dac += 2 * Core::Mathematics::pi if ($dac < 0);
            $collision = 1 if ($dac > Core::Mathematics::pi);

            my $ne2 = $end - 1;
            $ne2 += $n + 1 if ($ne2 < 0);
            $ddx = $bases[$ne2]->{x} - $bases[$end]->{x};
            $ddy = $bases[$ne2]->{y} - $bases[$end]->{y};
            my $a2 = atan2($ddy, $ddx);
            $a2 += 2 * Core::Mathematics::pi if ($a2 < 0);
            $dac = $aend1 - $a2;
            $dac += 2 * Core::Mathematics::pi if ($dac < 0);
            $collision = 1 if ($dac > Core::Mathematics::pi);

            if ($collision) {

                my $ac1 = $aave < $astart + 0.5 ? $aave : $astart + 0.5;
                $bases[$ns2]->{x} = $bases[$start]->{x} + cos($ac1);
                $bases[$ns2]->{y} = $bases[$start]->{y} + sin($ac1);
                $start = $ns2;

                my $ac2 = $aave > $aend2 - 0.5 ? $aave : $aend2 - 0.5;
                $bases[$ne2]->{x} = $bases[$end]->{x} + cos($ac2);
                $bases[$ne2]->{y} = $bases[$end]->{y} + sin($ac2);
                $end = $ne2;
                $num -= 2;

            }

        } while ($collision && $num > 1 && ++$safetyCount < 50);

    };

    # generate_region
    my $generateRegion = sub {

        my $cp = shift;

        my $rp = $cp->{region};
        my $start = ($cp->{start} == $rp->{start1}) ? $rp->{start1} : $rp->{start2};
        my $end = ($cp->{start} == $rp->{start1}) ? $rp->{end1} : $rp->{end2};

        for my $i ($start + 1 .. $end) {

            my $l = $i - $start;
            $bases[$i]->{x} = $bases[$cp->{start}]->{x} + $l * $cp->{xrad};
            $bases[$i]->{y} = $bases[$cp->{start}]->{y} + $l * $cp->{yrad};
            my $mate = $bases[$i]->{mate};
            $bases[$mate]->{x} = $bases[$cp->{end}]->{x} + $l * $cp->{xrad};
            $bases[$mate]->{y} = $bases[$cp->{end}]->{y} + $l * $cp->{yrad};

        }

    };

    my $connectedConnection = sub {

        my ($cp, $cpnext) = @_;

        return($cp->{extruded} || ($cp->{end} + 1 == $cpnext->{start}));

    };

    my $findIcMiddle = sub {

        my ($icstart, $icend, $anchorConn, $acp, $lp) = @_;

        my ($count, $ret, $ic, $done) = (0, -1, $icstart, 0);

        while (!$done) {

            last if (++$count > $lp->{nconnection} * 2);
            $ret = $ic if (defined $anchorConn && $lp->{connections}->[$ic] == $acp);
            $done = ($ic == $icend);
            $ic = 0 if (++$ic >= $lp->{nconnection});

        }

        if ($ret == -1) {

            $ic = $icstart;

            for my $i (1 .. int(($count + 1) / 2) - 1) { $ic = 0 if (++$ic >= $lp->{nconnection}); }

            $ret = $ic;

        }

        return($ret);

    };

    # traverse_loop
    my $traverseLoop;
    $traverseLoop = sub {

        my ($lp, $anchorConnection) = @_;

        my $angleinc = 2 * Core::Mathematics::pi / ($n + 1);
        my ($acp, $icroot) = (undef, -1);

        for my $ic (0 .. $lp->{nconnection} - 1) {

            my $cp = $lp->{connections}->[$ic];
            my $xs = -sin($angleinc * $cp->{start});
            my $ys = cos($angleinc * $cp->{start});
            my $xe = -sin($angleinc * $cp->{end});
            my $ye = cos($angleinc * $cp->{end});
            my $xn = $ye - $ys;
            my $yn = $xs - $xe;
            my $r = sqrt($xn * $xn + $yn * $yn);
            $cp->{xrad} = $xn / $r;
            $cp->{yrad} = $yn / $r;
            $cp->{angle} = atan2($yn, $xn);
            $cp->{angle} += 2 * Core::Mathematics::pi if ($cp->{angle} < 0);

            if (defined $anchorConnection && $anchorConnection->{region} == $cp->{region}) {

                $acp = $cp;
                $icroot = $ic;

            }

        }

        my ($globalRestart, $xc, $yc, $radius);

        do {

            $globalRestart = 0;
            $naviewDetermineRadius->($lp);
            $radius = $lp->{radius};

            if (!defined $anchorConnection) { ($xc, $yc) = (0, 0); }
            else {

                my $xo = ($bases[$acp->{start}]->{x} + $bases[$acp->{end}]->{x}) / 2;
                my $yo = ($bases[$acp->{start}]->{y} + $bases[$acp->{end}]->{y}) / 2;
                $xc = $xo - $radius * $acp->{xrad};
                $yc = $yo - $radius * $acp->{yrad};

            }

            my $icstart = $icroot == -1 ? 0 : $icroot;
            my $cp = $lp->{connections}->[$icstart];
            my ($count, $done) = (0, 0);

            do {

                my $j = $icstart - 1;
                $j = $lp->{nconnection} - 1 if ($j < 0);
                my $cpprev = $lp->{connections}->[$j];

                if (!$connectedConnection->($cpprev, $cp)) { $done = 1; }
                else {

                    $icstart = $j;
                    $cp = $cpprev;

                }

                if (++$count > $lp->{nconnection}) {

                    # all connected: break at the largest angular gap
                    my ($maxang, $imaxloop) = (-1, 0);

                    for my $ic2 (0 .. $lp->{nconnection} - 1) {

                        my $j2 = ($ic2 + 1) % $lp->{nconnection};
                        my $ac2 = $lp->{connections}->[$j2]->{angle} - $lp->{connections}->[$ic2]->{angle};
                        $ac2 += 2 * Core::Mathematics::pi if ($ac2 < 0);

                        if ($ac2 > $maxang) {

                            $maxang = $ac2;
                            $imaxloop = $ic2;

                        }

                    }

                    $icstart = ($imaxloop + 1) % $lp->{nconnection};
                    $lp->{connections}->[$imaxloop]->{broken} = 1;
                    $done = 1;

                }

            } while (!$done);

            my ($done_all, $icstart1) = (0, $icstart);

            while (!$done_all && !$globalRestart) {

                $count = 0;
                $done = 0;
                my ($icend, $rooted) = ($icstart, 0);

                while (!$done) {

                    $rooted = 1 if ($icend == $icroot);
                    my $j3 = ($icend + 1) % $lp->{nconnection};

                    if ($connectedConnection->($lp->{connections}->[$icend], $lp->{connections}->[$j3])) {

                        last if (++$count >= $lp->{nconnection});
                        $icend = $j3;

                    }
                    else { $done = 1; }

                }

                my $icmiddle = $findIcMiddle->($icstart, $icend, $anchorConnection, $acp, $lp);
                my ($icup, $icdown) = ($icmiddle, $icmiddle);
                $done = 0;
                my $direction = 0;

                while (!$done) {

                    my $ic3 = ($direction < 0) ? $icup : ($direction == 0 ? $icmiddle : $icdown);

                    if ($ic3 >= 0) {

                        my $cpX = $lp->{connections}->[$ic3];

                        if (!defined $anchorConnection || $acp != $cpX) {

                            if ($direction == 0) {

                                my $ha = _asin(0.5 / $radius < 1 ? 0.5 / $radius : 1);
                                $bases[$cpX->{start}]->{x} = $xc + $radius * cos($cpX->{angle} - $ha);
                                $bases[$cpX->{start}]->{y} = $yc + $radius * sin($cpX->{angle} - $ha);
                                $bases[$cpX->{end}]->{x} = $xc + $radius * cos($cpX->{angle} + $ha);
                                $bases[$cpX->{end}]->{y} = $yc + $radius * sin($cpX->{angle} + $ha);

                            }
                            elsif ($direction < 0) {

                                my $j4 = ($ic3 + 1) % $lp->{nconnection};
                                my $cpA = $lp->{connections}->[$ic3];
                                my $cpB = $lp->{connections}->[$j4];
                                my $acM = ($cpA->{angle} + $cpB->{angle}) / 2;
                                $acM -= Core::Mathematics::pi if ($cpA->{angle} > $cpB->{angle});
                                my $lnx = sin($acM);
                                my $lny = -cos($acM);
                                my $daX = fmod((($cpB->{angle} - $cpA->{angle}) + 2 * Core::Mathematics::pi), (2 * Core::Mathematics::pi));
                                my $rl = $cpA->{extruded} ? ($daX <= Core::Mathematics::pi / 2 ? 2 : 1.5) : 1;
                                $bases[$cpA->{end}]->{x} = $bases[$cpB->{start}]->{x} + $rl * $lnx;
                                $bases[$cpA->{end}]->{y} = $bases[$cpB->{start}]->{y} + $rl * $lny;
                                $bases[$cpA->{start}]->{x} = $bases[$cpA->{end}]->{x} + $cpA->{yrad};
                                $bases[$cpA->{start}]->{y} = $bases[$cpA->{end}]->{y} - $cpA->{xrad};

                            }
                            else {

                                my $j5 = $ic3 - 1 < 0 ? $lp->{nconnection} - 1 : $ic3 - 1;
                                my $cpC = $lp->{connections}->[$j5];
                                my $cpD = $lp->{connections}->[$ic3];
                                my $acN = ($cpC->{angle} + $cpD->{angle}) / 2;
                                $acN -= Core::Mathematics::pi if ($cpC->{angle} > $cpD->{angle});
                                my $lnx2 = -sin($acN);
                                my $lny2 = cos($acN);
                                my $daY = fmod((($cpD->{angle} - $cpC->{angle}) + 2 * Core::Mathematics::pi), (2 * Core::Mathematics::pi));
                                my $rl2 = $cpC->{extruded} ? ($daY <= Core::Mathematics::pi / 2 ? 2 : 1.5) : 1;
                                $bases[$cpD->{start}]->{x} = $bases[$cpC->{end}]->{x} + $rl2 * $lnx2;
                                $bases[$cpD->{start}]->{y} = $bases[$cpC->{end}]->{y} + $rl2 * $lny2;
                                $bases[$cpD->{end}]->{x} = $bases[$cpD->{start}]->{x} - $cpD->{yrad};
                                $bases[$cpD->{end}]->{y} = $bases[$cpD->{start}]->{y} + $cpD->{xrad};

                            }

                        }

                    }

                    if ($direction < 0) {

                        if ($icdown == $icend) { $icdown = -1; }
                        elsif ($icdown >= 0) { $icdown = 0 if (++$icdown >= $lp->{nconnection}); }

                        $direction = 1;

                    }
                    else {

                        if ($icup == $icstart) { $icup = -1; }
                        elsif ($icup >= 0) { $icup = $lp->{nconnection} - 1 if (--$icup < 0); }

                        $direction = -1;

                    }

                    $done = ($icup == -1 && $icdown == -1);

                }

                my $icnext = ($icend + 1) % $lp->{nconnection};

                if ($icend != $icstart && !($icstart == $icstart1 && $icnext == $icstart1)) {

                    my $cpSt = $lp->{connections}->[$icstart];
                    my $cpEn = $lp->{connections}->[$icend];
                    my $dx5 = $bases[$cpEn->{end}]->{x} - $bases[$cpSt->{start}]->{x};
                    my $dy5 = $bases[$cpEn->{end}]->{y} - $bases[$cpSt->{start}]->{y};
                    my $midxB = $bases[$cpSt->{start}]->{x} + $dx5 / 2;
                    my $midyB = $bases[$cpSt->{start}]->{y} + $dy5 / 2;
                    my $rrB = sqrt($dx5 * $dx5 + $dy5 * $dy5) || 1e-9;
                    my $mxB = $dx5 / $rrB;
                    my $myB = $dy5 / $rrB;
                    my $vxB = ($xc - $midxB) / $rrB;
                    my $vyB = ($yc - $midyB) / $rrB;
                    my $dotmv = $vxB * $mxB + $vyB * $myB;
                    my $nrxB = $dotmv * $mxB - $vxB;
                    my $nryB = $dotmv * $myB - $vyB;
                    $rrB = sqrt($nrxB * $nrxB + $nryB * $nryB) || 1e-9;
                    $nrxB /= $rrB;
                    $nryB /= $rrB;

                    my $acS = atan2($bases[$cpSt->{start}]->{y} - $yc, $bases[$cpSt->{start}]->{x} - $xc);
                    $acS += 2 * Core::Mathematics::pi if ($acS < 0);
                    my $acE = atan2($bases[$cpEn->{end}]->{y} - $yc, $bases[$cpEn->{end}]->{x} - $xc);
                    $acE += 2 * Core::Mathematics::pi if ($acE < 0);
                    $acE += 2 * Core::Mathematics::pi if ($acE < $acS);

                    my $signB = ($acE - $acS > Core::Mathematics::pi) ? -1 : 1;
                    my $nmidxB = $xc + $signB * $radius * $nrxB;
                    my $nmidyB = $yc + $signB * $radius * $nryB;

                    if ($rooted) {

                        $xc -= $nmidxB - $midxB;
                        $yc -= $nmidyB - $midyB;

                    }
                    else {

                        for (my $icM = $icstart;;) {

                            my $cpM = $lp->{connections}->[$icM];
                            $bases[$cpM->{start}]->{x} += $nmidxB - $midxB;
                            $bases[$cpM->{start}]->{y} += $nmidyB - $midyB;
                            $bases[$cpM->{end}]->{x} += $nmidxB - $midxB;
                            $bases[$cpM->{end}]->{y} += $nmidyB - $midyB;
                            last if ($icM == $icend);
                            $icM = 0 if (++$icM >= $lp->{nconnection});

                        }

                    }

                }

                $icstart = $icnext;
                $done_all = ($icstart == $icstart1);

            }

            last if ($globalRestart);

            # fill unpaired bases between connections
            for (my $ic4 = 0; $ic4 < $lp->{nconnection} && !$globalRestart; $ic4++) {

                my $cpF = $lp->{connections}->[$ic4];
                my $cpNF = $lp->{connections}->[($ic4 + 1) % $lp->{nconnection}];
                my $dxF = $bases[$cpF->{end}]->{x} - $xc;
                my $dyF = $bases[$cpF->{end}]->{y} - $yc;
                my $rcF = sqrt($dxF * $dxF + $dyF * $dyF);
                my $acF = atan2($dyF, $dxF);
                $acF += 2 * Core::Mathematics::pi if ($acF < 0);

                my $dxNF = $bases[$cpNF->{start}]->{x} - $xc;
                my $dyNF = $bases[$cpNF->{start}]->{y} - $yc;
                my $rcNF = sqrt($dxNF * $dxNF + $dyNF * $dyNF);
                my $acNF = atan2($dyNF, $dxNF);
                $acNF += 2 * Core::Mathematics::pi if ($acNF < 0);
                $acNF += 2 * Core::Mathematics::pi if ($acNF < $acF);

                my $danF = $acNF - $acF;
                my $dcpF = fmod((($cpNF->{angle} - $cpF->{angle}) + 2 * Core::Mathematics::pi), (2 * Core::Mathematics::pi));

                if (abs($danF - $dcpF) > Core::Mathematics::pi) {

                    if ($cpF->{extruded}) { } # crossed regions, skip
                    elsif (($cpNF->{start} - $cpF->{end}) != 1) {

                        $cpF->{extruded} = 1;
                        $globalRestart = 1;

                        last;

                    }

                }

                if (!$globalRestart) {

                    if ($cpF->{extruded}) { $constructExtrudedSegment->($cpF, $cpNF); }
                    else {

                        my $numF = $cpNF->{start} - $cpF->{end};
                        $numF += $n + 1 if ($numF < 0);
                        my $angStepF = $numF > 0 ? $danF / $numF : 0;

                        for my $ji (1 .. $numF - 1) {

                            my $idxF = $cpF->{end} + $ji;
                            $idxF -= $n + 1 if ($idxF > $n);
                            my $aF = $acF + $ji * $angStepF;
                            my $rrF = $rcF + ($rcNF - $rcF) * ($aF - $acF) / $danF;
                            $bases[$idxF]->{x} = $xc + $rrF * cos($aF);
                            $bases[$idxF]->{y} = $yc + $rrF * sin($aF);

                        }

                    }

                }

            }

        } while ($globalRestart);

        # loop centroid
        my ($sx, $sy, $nm) = (0, 0, 0);

        for my $ic5 (0 .. $lp->{nconnection} - 1) {

            my $cpL = $lp->{connections}->[$ic5];
            my $cpNL = $lp->{connections}->[($ic5 + 1) % $lp->{nconnection}];
            $nm += 2;
            $sx += $bases[$cpL->{start}]->{x} + $bases[$cpL->{end}]->{x};
            $sy += $bases[$cpL->{start}]->{y} + $bases[$cpL->{end}]->{y};
            $bases[$cpL->{start}]->{loopCenter} = $lp;
            $bases[$cpL->{end}]->{loopCenter} = $lp;

            if (!$cpL->{extruded}) {

                for (my $j8 = $cpL->{end} + 1; $j8 != $cpNL->{start};) {

                    $j8 -= $n + 1 if ($j8 > $n);
                    $nm++;
                    $sx += $bases[$j8]->{x};
                    $sy += $bases[$j8]->{y};
                    $bases[$j8]->{loopCenter} = $lp;
                    $j8 -= $n + 1 if (++$j8 > $n);

                    last if ($j8 == $cpNL->{start});

                }

            }

        }

        $lp->{x} = $sx / $nm;
        $lp->{y} = $sy / $nm;

        # recurse into sub-loops
        for my $ic6 (0 .. $lp->{nconnection} - 1) {

            if ($ic6 != $icroot) {

                my $cpR = $lp->{connections}->[$ic6];
                $generateRegion->($cpR);
                $traverseLoop->($cpR->{loop}, $cpR);

            }

        }

    };

    $traverseLoop->($root, undef);

    my (@coords, @centers);

    for my $i (0 .. $n - 1) { $coords[$i] = { x => $bases[$i + 1]->{x} * $SCALE, y => $bases[$i + 1]->{y} * $SCALE }; }

    for my $i (0 .. $n - 1) {

        my $lc = $bases[$i + 1]->{loopCenter};

        if (defined $lc) { $centers[$i] = { x => $lc->{x} * $SCALE, y => $lc->{y} * $SCALE }; }
        elsif ($pairs->[$i] != -1) {

            my $j = $pairs->[$i];
            $centers[$i] = { x => ($coords[$i]->{x} + $coords[$j]->{x}) / 2,
                             y => ($coords[$i]->{y} + $coords[$j]->{y}) / 2 };

        }
        else { $centers[$i] = { x => $coords[$i]->{x}, y => $coords[$i]->{y} }; }

    }

    return({ coords => \@coords, centers => \@centers, pairs => $pairs, n => $n });

}

sub _acos { my $x = shift; $x = 1 if ($x > 1); $x = -1 if ($x < -1); return(atan2(sqrt(1 - $x * $x), $x)); }

1;
