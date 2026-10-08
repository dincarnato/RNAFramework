package RNA::Utils;

use strict;
use Scalar::Util qw(looks_like_number);

use Core::Mathematics;
use Core::Utils;
use Data::Sequence::Utils;

use base qw(Exporter);

our @EXPORT = qw(isdotbracket isdbbalanced fixdotbracket rnapair
                 listpairs listhelices ppv sensitivity
				 bpdistance rmpseudoknots rmnoncanonical rmlonelypairs
				 fmi mfmi);

my @bpchars = (([qw(\( \))], [qw([ ])], [qw({ })], [qw(< >)]), (map { [uc($_), $_] } ("a" .. "z")));

sub isdotbracket { return(1) if (is($_[0], $_[1] . quotemeta("([{<>}]).") . join("", ("a" .. "z"), ("A" .. "Z"))) &&
								 !isseq($_[0]) &&
                                 $_[0] =~ m/\./); } # Any dot-bracket structure should contain at least 1 dot

sub isdbbalanced {

    my $dotbracket = shift;

    my (@dotbracket, %pairs, %bpchars);
    @dotbracket = split("", $dotbracket);
	%bpchars = map { $_->[1] => $_->[0] } @bpchars;

    for(my $i = 0; $i < @dotbracket; $i++) {

		if ($dotbracket[$i] ne ".") {

			if (exists $bpchars{$dotbracket[$i]}) { $pairs{$bpchars{$dotbracket[$i]}}--; }
			else { $pairs{$dotbracket[$i]}++; }

		}

    }

    return(1) if (!keys %pairs || !sum(values %pairs));

    return();

}

sub fixdotbracket {

    my $dotbracket = shift;

    return("." x length($dotbracket)) if (!isdotbracket($dotbracket));

    my ($i, @dotbracket);
    $i = 0;
    @dotbracket = split(//, $dotbracket);

    while ($dotbracket =~ m/(\(\.+?\))/) {

        my ($match, $dots);
        $match = $1;
        $i = index($dotbracket, $match, 0);
        $dots = "." x length($match);
        $match = quotemeta($match);
        $dotbracket =~ s/^(.{$i})$match/$1 . $dots/e;

    }

    $dotbracket[$-[0]] = "." while($dotbracket =~ m/[\(\)]/g);

    return(join("", @dotbracket));

}

sub rnapair {

    my ($base1, $base2, $excludegu) = @_;

	my ($pair, %pairs);
    %pairs = map { $_ => 1 } (qw(AU CG GC UA), ($excludegu ? () : qw(GU UG)));
	$pair = uc($base1 . $base2);
	$pair =~ tr/T/U/;

    return unless($pair =~ /^[ACGU]{2}$/);

    return(1) if (exists $pairs{$pair});

    return();

}

sub rmnoncanonical {

	my ($sequence, $pairs) = @_;

	_checkStructure($sequence, $pairs);

	my (@pairs, @canonical, @noncanonical);

	if (isdotbracket($pairs)) { @pairs = listpairs($pairs); }
	elsif (ref($pairs) eq "ARRAY") { @pairs = @{$pairs}; }

	for my $bp (@pairs) { # single pass, rnapair() was previously evaluated twice per base-pair

		if (rnapair(substr($sequence, $bp->[0], 1), substr($sequence, $bp->[1], 1))) { push(@canonical, $bp); }
		else { push(@noncanonical, $bp); }

	}
	
	return(\@canonical, \@noncanonical);

}

sub listpairs {

    my $dotbracket = shift;

    return() if (!isdotbracket($dotbracket) || !isdbbalanced($dotbracket));

    my (@dotbracket, @pairs, %pairs, %bpchars);
    @dotbracket = split(//, $dotbracket);
	%bpchars = map { $_->[1] => $_->[0] } @bpchars;

    for(my $i = 0; $i < @dotbracket; $i++) {

		if ($dotbracket[$i] ne ".") {

			if (exists $bpchars{$dotbracket[$i]}) { push(@pairs, [pop(@{$pairs{$bpchars{$dotbracket[$i]}}}), $i]); }
			else { push(@{$pairs{$dotbracket[$i]}}, $i); }

		}

    }

    @pairs = sort { $a->[0] <=> $b->[0] } @pairs;

    return(wantarray() ? @pairs : \@pairs);

}

sub listhelices {

    my $dotbracket = shift;
    my $lonelyPairs = shift;

    my (@pairs, @h5bases, @h3bases, @helices, @pkhelices);
    @pairs = listpairs($dotbracket);

    for (0 .. $#pairs) {

        if (!@h5bases ||
            ($h5bases[0] == $pairs[$_]->[0] - 1 &&
             $h3bases[0] == $pairs[$_]->[1] + 1)) {

            unshift(@h5bases, $pairs[$_]->[0]);
            unshift(@h3bases, $pairs[$_]->[1]);

        }
        else {

            my $helix = { h5bases => [@h5bases],
                          h3bases => [@h3bases],
                          h5end   => $h5bases[0],
                          h3end   => $h3bases[0],
                          h5start => $h5bases[-1],
                          h3start => $h3bases[-1],
                          parents => [] };

            if ((@h5bases == 1 && $lonelyPairs) || @h5bases > 1) {

                if (substr($dotbracket, $h5bases[0], 1) eq "(") { push(@helices, $helix); }
                else { push(@pkhelices, $helix); }

            }

            @h5bases = ($pairs[$_]->[0]);
            @h3bases = ($pairs[$_]->[1]);

        }

    }

    if (@h5bases) {

        my $helix = { h5bases => [@h5bases],
                      h3bases => [@h3bases],
                      h5end   => $h5bases[0],
                      h3end   => $h3bases[0],
                      h5start => $h5bases[-1],
                      h3start => $h3bases[-1],
                      parents => [] };

        if ((@h5bases == 1 && $lonelyPairs) || @h5bases > 1) {

            if (substr($dotbracket, $h5bases[0], 1) eq "(") { push(@helices, $helix); }
            else { push(@pkhelices, $helix); }

        }

    }

	# Outputted helices are sorted by 5'-end start position
	@helices = _helixinheritance(sort {$a->{h5start} <=> $b->{h5start}} @helices);
	@pkhelices = _helixinheritance(sort {$a->{h5start} <=> $b->{h5start}} @pkhelices);

	return(\@helices, \@pkhelices);

}

sub _helixinheritance {

    my @helices = @_;

    foreach my $i (0 .. $#helices - 1) {

        foreach my $j ($i + 1 .. $#helices) {

			next if ($i == $j);
			
            last if (!intersect([$helices[$i]->{h5start}, $helices[$i]->{h3start}],
                                [$helices[$j]->{h5start}, $helices[$j]->{h3start}]));

            push(@{$helices[$j]->{parents}}, $i);

        }

    }

    return(@helices);

}

sub ppv {

    my ($reference, $structure, $relaxed) = @_;

    if (my $common = _commonpairs($reference, $structure, $relaxed)) { return($common / @{listpairs($structure)}); }

    return(0);

}

sub sensitivity {

    my ($reference, $structure, $relaxed) = @_;

    if (my $common = _commonpairs($reference, $structure, $relaxed)) { return($common / @{listpairs($reference)}); }

    return(0);

}

sub fmi {

	my ($reference, $structure, $relaxed) = @_;

	my ($common, $refPairs, $structPairs, $refOnly, 
		$structOnly);
	$refPairs = @{listpairs($reference)};
	$structPairs = @{listpairs($structure)};

	return(0) if (!$refPairs || !$structPairs);

	$common = _commonpairs($reference, $structure, $relaxed) || 0;
	$refOnly = @{listpairs($reference)} - $common;
	$structOnly = @{listpairs($structure)} - $common;

	return($common / sqrt(($common + $refOnly) * ($common + $structOnly)));

}

sub mfmi { # Lan et al., 2022

	my ($reference, $structure, $relaxed) = @_;

	my ($commonUnpaired, $fmi, $length);
	$length = length($reference);

	return(0) if ($length != length($structure));

	$commonUnpaired = scalar(grep { substr($reference, $_, 1) eq "." && substr($structure, $_, 1) eq "." } 0 .. $length - 1) / $length;
	$fmi = fmi($reference, $structure, $relaxed);

	return($commonUnpaired + (1 - $commonUnpaired) * $fmi);

}

sub bpdistance {

    my ($reference, $structure) = @_;

    my $distance = length($reference);
    $distance -= 2 * _commonpairs($reference, $structure);

    for (0 .. length($reference) - 1) { $distance-- if (substr($reference, $_, 1) eq "." && substr($structure, $_, 1) eq "."); }

    return($distance);

}

sub _commonpairs {

    my ($reference, $structure, $relaxed) = @_;

    my ($common, %reference);

    return if (!isdotbracket($reference) || !isdbbalanced($reference) ||
               !isdotbracket($structure) || !isdbbalanced($structure) ||
               length($reference) != length($structure));

    for (listpairs($reference)) { $reference{$_->[0] . "-" . $_->[1]} = 1; }

	if ($relaxed) {

		# This relaxed comparison method has been described by K. Weeks and coworkers in Deigan et al., 2009
		# and considers a basepair i-j as present in the reference structure if any of the following pairs exist:
		# i/j; i-1/j; i+1/j; i/j-1; i/j+1

		for (listpairs($structure)) {

			my @pairs = ($_->[0] . "-" . $_->[1], ($_->[0] - 1) . "-" . $_->[1], ($_->[0] + 1) . "-" . $_->[1],
						 $_->[0] . "-" . ($_->[1] - 1), $_->[0] . "-" . ($_->[1] + 1));

			foreach my $pair (@pairs) {

				if (exists $reference{$pair}) {

					$common++;
					delete($reference{$pair});

					last;

				}

			}
			
		}

	}
	else { for (listpairs($structure)) { $common++ if (exists $reference{$_->[0] . "-" . $_->[1]}); } }

    return($common);

}

sub rmlonelypairs {

    my $db = shift;

    return if (!isdotbracket($db) || !isdbbalanced($db));

    my ($helices, $pkhelices, @db);
    ($helices, $pkhelices) = listhelices($db, 1);
    @db = split(//, $db);

    for (@{$helices}) {

        if (@{$_->{h5bases}} == 1) {

            $db[$_->{h5bases}->[0]] = ".";
            $db[$_->{h3bases}->[0]] = ".";

        }

    }

    for (@{$pkhelices}) {

        if (@{$_->{h5bases}} == 1) {

            $db[$_->{h5bases}->[0]] = ".";
            $db[$_->{h3bases}->[0]] = ".";

        }

    }

    $db = join("", @db);

}

sub rmpseudoknots {

	my ($sequence, $pairs, $scoresub) = @_;

	return if (!$sequence);

	_checkStructure($sequence, $pairs);

	Core::Utils::throw("Scoring function must be a CODE reference") if (defined $scoresub && ref($scoresub) ne "CODE");
	$scoresub = \&Core::Mathematics::sum unless(defined $scoresub);

	if (ref($pairs) eq "ARRAY") {

		my (@ct, @ctcopy, @sequence, @score,
			%pkpairs, %hbonds);

		%hbonds = ( AU => 2,
					GU => 2,
					CG => 3 );
		@sequence = split(//, $sequence);
		@ct = (undef) x @sequence;

		for (@{$pairs}) {

			$ct[$_->[0]] = $_->[1];
			$ct[$_->[1]] = $_->[0];
			$score[$_->[0]] = @{$_} == 3 ? $_->[2] : ($hbonds{dna2rna(join("", sort($sequence[$_->[0]], $sequence[$_->[1]])))} || 0);

		}

		@ctcopy = @ct;

		for my $i (0 .. $#ct) {

			my $j = $ct[$i];

			if (defined $j &&
				$i < $j) {

				foreach my $ki ($i .. $j) {

					my $kj = $ct[$ki];

					if (defined $kj &&
						($kj > $j ||
						 $kj < $i)) {

						undef($ctcopy[$ki]);
						undef($ctcopy[$kj]);

						if ($kj > $j) { $pkpairs{$ki} = $kj; }
						elsif ($kj < $i) { $pkpairs{$kj} = $ki; }

					}

				}

			}

		}

		if (keys %pkpairs) {

			my ($largest, @r1, @r2, @pkpairs, @r, @stems, @compm, @l, @sets, @lst, @lst2, @largest, %tmp, %addback);
			@pkpairs = map {[$_, $pkpairs{$_}]} sort {$a <=> $b} keys %pkpairs;

			for(my $i = 1; $i < @pkpairs; $i++) {

				my ($d1, $d2);
				$d1 = $pkpairs[$i]->[1] - $pkpairs[$i-1]->[1];
				$d2 = $pkpairs[$i]->[0] - $pkpairs[$i-1]->[0];

				push(@r, $i - 1) if ($d1 != -1 || $d2 != 1);

			}

			push(@r, $#pkpairs);
			@r = sort {$a <=> $b} uniq(@r);

			for my $i (0 .. $#r) {

				my (%stem);

				if (!$i) { $stem{$pkpairs[$_]->[0]} = $pkpairs[$_]->[1] for ($i .. $r[$i]); }
				else { $stem{$pkpairs[$_]->[0]} = $pkpairs[$_]->[1] for ($r[$i-1] + 1 .. $r[$i]); }

				push(@stems, \%stem);

			}

			for my $i (0 .. $#stems) {

				for my $j (0 .. $#stems) {

					my ($conflict, $stem1, $stem2, $mb1,
						$mp1, $mb2, $mp2, $mm2,
						$mx2);
					$conflict = 0;
					$stem1 = $stems[$i];
					$stem2 = $stems[$j];
					$mb1 = min(values %{$stem1});
					$mp1 = min(keys %{$stem1});
					$mb2 = min(values %{$stem2});
					$mp2 = min(keys %{$stem2});
					$mm2 = min($mp2, $mb2);
					$mx2 = max($mp2, $mb2);

					$conflict = 1 if (($mp1 < $mx2 && $mp1 > $mm2 && ($mb1 < $mm2 || $mb1 > $mx2)) ||
									  ($mb1 < $mx2 && $mb1 > $mm2 && ($mp1 > $mx2 || $mp1 < $mm2)));

					push(@compm, { i => $i,
								   j => $j,
								   c => $conflict });

				}

			}

			@l = (0 .. $#stems);
			@sets = _compatible_stems(@compm);

			foreach my $stem (0 .. $#stems) { push(@lst, $scoresub->(map { $score[$_] } (keys %{$stems[$stem]}))); }

			# @lst2 are cumulative stem lengts or H-bonds
			for (0 .. $#sets) {

				my @set = @{$sets[$_]}[0 .. $#{$sets[$_]}]; 
				push(@lst2, sum(@lst[@set]));

			}

			($largest) = grep { $lst2[$_] == max(@lst2) } 0 .. $#lst2;
			@largest = @{$sets[$largest]}[0 .. $#{$sets[$largest]}]; 
			%addback = %{$stems[$largest[0]]};

			if (@largest > 1) { %addback = (%addback, %{$stems[$largest[$_]]}) for (1 .. $#largest); }

			foreach my $i (keys %addback) {

				my $j = $addback{$i};
				$ctcopy[$i] = $j;
				$ctcopy[$j] = $i;

				delete($pkpairs{$i});

			}

		}

		for (0 .. $#ctcopy) {

			if (defined $ctcopy[$_]) { $ctcopy[$_] = $ctcopy[$_] > $_ ? "(" : ")"; }
			else { $ctcopy[$_] = "."; }

		}

		return(join("", @ctcopy), [map {[sort {$a <=> $b} ($_, $pkpairs{$_})]} sort {$a <=> $b} keys %pkpairs]);

	}
	elsif (isdotbracket($pairs)) {

		my (@pkpairs, @structure);

		for my $helix (@{(listhelices($pairs, 1))[1]}) { push(@pkpairs, map { [$helix->{h5bases}->[$_], $helix->{h3bases}->[$_]]} 0 .. $#{$helix->{h5bases}}); }

		$pairs =~ s/[^\(\)\.]/./g; # Remove pseudoknotted base-pairs from original structure

		return($pairs, \@pkpairs);

	}

}

# Called by rmpseudoknots
# Recursively finds all combinations of compatible stems
sub _compatible_stems {

	my @compm = @_;

	my (@compatible, @incompatible, %incompatibleOf, %followerOf);

	# The compatibility matrix has one entry per ordered pair of stems, and the
 	# traversal below used to grep the whole of it once per predecessor at every
	# node. Indexing it once up front turns each of those scans into a lookup.
	for my $entry (@compm) {

		if ($entry->{c}) { push(@{$incompatibleOf{$entry->{i}}}, $entry->{j}); }
		else { push(@{$followerOf{$entry->{i}}}, $entry->{j}); }

	}

	# Followers are always consumed in ascending order, so they are sorted once
	# rather than on every visit
	@{$_} = sort { $a <=> $b } @{$_} for (values %followerOf);
	@{$_} = sort { $a <=> $b } @{$_} for (values %incompatibleOf);

	local *_traverse = sub {

		my @predecessors = @_;
		my $current = $predecessors[-1];
		my %seen = map { $_ => 1 } @predecessors;

		# Successors incompatible with any predecessor are marked as seen, so that they are discarded
		for my $predecessor (@predecessors) { $seen{$_} = 1 for (@{$incompatibleOf{$predecessor} || []}); }

        # The first following compatible stem, then the first one incompatible
		# with it
		my (@followers, $first);

		for my $j (@{$followerOf{$current} || []}) {

			next if ($j <= $current || exists $seen{$j});

			$first = $j;

			last;

		}

		if (defined $first) {

			@followers = ($first);

			for my $j (@{$incompatibleOf{$first} || []}) {

				next if ($j <= $current || exists $seen{$j});

				push(@followers, $j);

				last;

			}

			_traverse(@predecessors, $_) for (@followers);

		}
		else { push(@compatible, [@predecessors]); }

	};

	@incompatible = defined $incompatibleOf{0} ? ($incompatibleOf{0}->[0]) : ();
	push(@incompatible, 0);

    _traverse($_) for (@incompatible);

	return(@compatible);

}

sub _checkStructure {

	my ($sequence, $pairs) = @_;

	my $length = length($sequence);

	if (ref($pairs) eq "ARRAY") {

		my ($min, $max);

		for my $pair (@{$pairs}) {

			Core::Utils::throw("Base-pairs must be ARRAY refs") if (ref($pair) ne "ARRAY");
			Core::Utils::throw("Base-pair must be ARRAY refs of 2 values") if (@{$pair} < 2);

			for my $i (0, 1) {

				my $base = $pair->[$i];

				Core::Utils::throw("Base-pair indexes must be INT") if (!defined $base || !looks_like_number($base) || $base != int($base));

				$min = $base if (!defined $min || $base < $min);
				$max = $base if (!defined $max || $base > $max);

			}

		}

		Core::Utils::throw("Base-pair indices must be >= 0") if (defined $min && $min < 0);
		Core::Utils::throw("Base-pair index $max exceeds sequence length ($length)") if (defined $max && $max >= $length);

		return;

	}
	else { 
		
		Core::Utils::throw("Structure and sequence have different lengths ($length != " . length($pairs) . ")") if (length($pairs) != $length);
		Core::Utils::throw("Invalid structure") if (!isdotbracket($pairs));
		Core::Utils::throw("Unbalanced dot-bracket structure") if (!isdbbalanced($pairs));

		return;
		
	}

	Core::Utils::throw("Invalid structure");

}

1;
