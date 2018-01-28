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

package RNA::Utils;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;
use Data::Sequence::Utils;

use base qw(Exporter);

our @EXPORT = qw(isdotbracket isdbbalanced fixdotbracket rnapair
                 listpairs listhelices ppv sensitivity
				 bpdistance rmpseudoknots rmnoncanonical rmlonelypairs);
				 
our @bpchars = (([qw(\( \))], [qw([ ])], [qw({ })], [qw(< >)]), (map { [uc($_), $_] } ("a" .. "z")));

sub isdotbracket { return(1) if (is($_[0], $_[1] . quotemeta("([{<>}]).") . join("", ("a" .. "z"), ("A" .. "Z"))) &&
								 !isseq($_[0]) &&
                                 $_[0] =~ m/\./); } # Any dot-bracket structure should contain at least 1 dot

sub isdbbalanced {
    
    my ($dotbracket, $sequence) = @_;
    
    return() if (!isdotbracket($dotbracket) ||
                 (defined $sequence &&
                  (length($sequence) != length($dotbracket) ||
                   !isna($sequence))));
    
    my $i = 0;

	for my $c (1 .. @bpchars) {
		
		my ($open, $close, $pattern);
		($open, $close) = (quotemeta($bpchars[$c - 1]->[0]), quotemeta($bpchars[$c - 1]->[1]));
		$pattern = $open . "[" . quotemeta(join("", (map { @$_ } @bpchars[$c .. $#bpchars]), ".")) . "]*" . $close;
		
		while ($dotbracket =~ m/($pattern)/) {
		
			my ($match, $dots);
			$match = $1;
			$i = index($dotbracket, $match, 0);
		
			return() if (defined $sequence &&
						 !rnapair(substr($sequence, $i, 1), substr($sequence, ($i + length($match) - 1), 1)));
			
			$dots = $match;
			$dots =~ s/[$open$close]/./g;
			$match = quotemeta($match);
			$dotbracket =~ s/^(.{$i})$match/$1 . $dots/e;
			
		}
		
	}
    
    return() if ($dotbracket !~ m/^\.+?$/);
    
    return(1);
    
}

sub fixdotbracket {
    
    my $dotbracket = shift;
    
    return() if (!isdotbracket($dotbracket));
    
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
    
    my $pairs = { A => "U",
                  U => $excludegu ? "A" : "AG",
                  G => $excludegu ? "C" : "CU",
                  C => "G" };
    
    $_ = dna2rna(uc($_)) for ($base1, $base2); 
    
    return unless(isrna(join("", $base1, $base2)));
    
    return(1) if ($pairs->{$base1} =~ m/$base2/);
    
    return();
    
}

sub rmnoncanonical {
	
	my ($sequence, $pairs) = @_;
	
	return if (!isna($sequence));
	
	my (@pairs, @canonical, @noncanonical);
	
	if (isdotbracket($pairs) &&
		isdbbalanced($pairs)) { @pairs = listpairs($pairs); }
	elsif (ref($pairs) eq "ARRAY") { @pairs = @{$pairs}; }
	else { return; }

	@canonical = grep { rnapair(substr($sequence, $_->[0], 1), substr($sequence, $_->[1], 1)) } @pairs;
	@noncanonical = grep { !rnapair(substr($sequence, $_->[0], 1), substr($sequence, $_->[1], 1)) } @pairs;
	
	return(\@canonical, \@noncanonical);
	
}

sub listpairs {
    
    my $dotbracket = shift;
   
    return() if (!isdotbracket($dotbracket) ||
                 !isdbbalanced($dotbracket));
    
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
	
    return if (!isdotbracket($dotbracket) ||
               !isdbbalanced($dotbracket));
	
	my (@helices, @pkhelices);

	for my $c (1 .. @bpchars) {
	
		my ($open, $close, $pattern, $loop, @list);
		
		($open, $close) = (quotemeta($bpchars[$c - 1]->[0]), quotemeta($bpchars[$c - 1]->[1]));
		$loop = quotemeta(join("", (map { @$_ } @bpchars[$c .. $#bpchars]), "."));
		$pattern = $open . "[" . $loop . "]*" . $close;
		
		while($dotbracket =~ m/($pattern)/) {
			
			my ($k, $h5start, $h5end, $h3end,
				$h3start, $start, $end, $structure,
				$replaced, @dotbracket, @h5bases, @h3bases);
			@dotbracket = split(//, $dotbracket);
			$k = $1;
			$h5start = $h5end = index($dotbracket, $k, 0);
			$h3start = $h3end = $h5start + length($k) - 1;
		
			while($dotbracket[$h5start] =~ m/^$open$/ &&
				  $dotbracket[$h3start] =~ m/^$close$/) {
				
				push(@h5bases, $h5start);
				push(@h3bases, $h3start);
				$h5start--;
				$h3start++;
				
				last if ($dotbracket[$h5start] =~ m/^[$loop]$/ &&
						 $dotbracket[$h3start] =~ m/^[$loop]$/);
				
				if ($dotbracket[$h5start] =~ m/^$open$/ &&
					$dotbracket[$h3start] =~ m/^[$loop]$/) {
					
					my $last = $h3start;
					
					while($dotbracket[$h3start] =~ m/^[$loop]$/) { $h3start++; }
					
					if ($dotbracket[$h3start] =~ m/^$open$/) {
						
						$h3start = $last;
						#push(@h3bases, $h3start);
						
						last;
						
					}
					
				}
				elsif ($dotbracket[$h5start] =~ m/^[$loop]$/ &&
					   $dotbracket[$h3start] =~ m/^$close$/) {
					
					my $last = $h5start;
					
					while($dotbracket[$h5start] =~ m/^[$loop]$/) { $h5start--; }
					
					if ($dotbracket[$h5start] =~ m/^$close$/) {
						
						$h5start = $last; 
						#push(@h5bases, $h5start);
						
						last;
						
					}
					
				}
				
			}
			
			$h5start++;
			$h3start--;
			
			push(@list, { h5start => $h5start,
						  h5end   => $h5end,
						  h3start => $h3start,
						  h3end   => $h3end,
						  h5bases => \@h5bases,
						  h3bases => \@h3bases,
                          parents => [] });

			($start, $end) = ($list[-1]->{h5start}, $list[-1]->{h3start});
			$structure = substr($dotbracket, $start, $end - $start + 1);
			$replaced = $structure;  
			$replaced =~ s/[$open$close]/./g;
			$structure = quotemeta($structure); 
			$dotbracket =~ s/^(.{$start})$structure/$1 . $replaced/e; 
			
		}
		

		if (!@helices) { @helices = @list; }
		else { @pkhelices = (@pkhelices, @list); }
	
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
    
    return();
    
}

sub sensitivity {
    
    my ($reference, $structure, $relaxed) = @_;
    
    if (my $common = _commonpairs($reference, $structure, $relaxed)) { return($common / @{listpairs($reference)}); }
    
    return();
    
}

sub bpdistance {
    
    my ($reference, $structure) = @_;
    
    my $distance = length($reference);
    $distance -= 2 * _commonpairs($reference, $structure);
    
    for (0 .. length($reference) - 1) { $distance-- if (substr($reference, $_, 1) eq "." &&
                                                        substr($structure, $_, 1) eq "."); }
    
    return($distance);
    
}

sub _commonpairs {
    
    my ($reference, $structure, $relaxed) = @_;
    
    my ($common, %reference);
    
    return() if (!isdotbracket($reference) ||
                 !isdbbalanced($reference) ||
                 !isdotbracket($structure) ||
                 !isdbbalanced($structure) ||
                 length($reference) != length($structure));
    
    for (listpairs($reference)) { $reference{$_->[0] . "-" . $_->[1]} = 1; }

	if ($relaxed) {
		
		# This relaxed comparison method has been described by K. Weeks and coworkers in Deigan et al., 2009
		# and considers a basepair i-j as present in the reference structure if any of the following pairs exist:
		# i/j; i-1/j; i+1/j; i/j-1; i/j+1
		
		for (listpairs($structure)) { $common++ if (exists $reference{($_->[0] - 1) . "-" . $_->[1]} ||
													exists $reference{$_->[0] . "-" . $_->[1]} ||
													exists $reference{($_->[0] + 1) . "-" . $_->[1]} ||
													exists $reference{$_->[0] . "-" . ($_->[1] - 1)} ||
													exists $reference{$_->[0] . "-" . ($_->[1] + 1)}); }
		
	}
	else { for (listpairs($structure)) { $common++ if (exists $reference{$_->[0] . "-" . $_->[1]}); } }

    return($common);
    
}

sub rmlonelypairs {
    
    my $db = shift;
    
    return if (!isdotbracket($db) ||
               !isdbbalanced($db));

    my ($helices, $pkhelices, @db);
    ($helices, $pkhelices) = listhelices($db);
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

	my ($sequence, $pairs) = @_;
	
	return unless($sequence);
	
	if (ref($pairs) eq "ARRAY") {
	
		my (@ct, @ctcopy, @sequence, %pkpairs,
			%hbonds);
		
		%hbonds = ( AU => 2,
					GU => 2,
					CG => 3 );
		@sequence = split(//, $sequence);
		@ct = (undef) x @sequence;
		
		for (@{$pairs}) {
		
			$ct[$_->[0]] = $_->[1];
			$ct[$_->[1]] = $_->[0];
			
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
			
			push(@r, $#pkpairs); # Patch to original code (missing last hairpin)
			@r = sort {$a <=> $b} uniq(@r);
			
			for my $i (0 .. $#r) {
				
				my (%stem);
				
				if (!$i) { $stem{$pkpairs[$_]->[0]} = $pkpairs[$_]->[1] for ($i .. $r[$i]); }
				else { $stem{$pkpairs[$_]->[0]} = $pkpairs[$_]->[1] for ($r[$i-1] + 1 .. $r[$i]); }
				
				push(@stems, \%stem);
				
			}
			
			# Bug 2 in original code (removed to patch)
			#$tmp{$pkpairs[$_]->[0]} = $pkpairs[$_]->[1] for ($r[0] + 1 .. $#pkpairs);
			#push(@stems, \%tmp);
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
	
			# @sets are the combinations of compatible sets
			# Bug 3 in original code
			# Here the problem is that the code takes hairpin 1,
			# then takes all the compatible hairpins with hairpin 1,
			# but it doesn't consider that the hairpins that are compatible
			# with hairpin 1, can be incompatible among each others
			#while(@l) {
			#	
			#	my (@v, @j, @s);
			#	@s = grep { $_->{c} == 0 &&
			#				$_->{i} == $l[0] } @compm;
			#	@j = map {$_->{j}} @s;
			#	@v = ($s[0]->{j});
			#	#use Data::Dumper; print Dumper(\@s);exit;
			#	for my $j (@j) {
			#		
			#		push(@v, $j);
			#		@l = grep { $_ != $j } @l;
			#		
			#	}
			#	
			#	push(@sets, \@v);
			#	
			#}
			
			# Patch to bug 3
			@sets = _compatible_stems(@compm);
			# unshift(@{$_}, $_->[0]) for (@sets); Unnecessary due to patch 4 & 5
			
			# @lst are stem lengths
			#push(@lst, scalar(keys %{$stems[$_]})) for (0 .. $#stems);
			
			for (0 .. $#stems) {
				
				my $hbonds = 0;
				
				foreach my $i (keys %{$stems[$_]}) {
					
					my $j = $stems[$_]->{$i};
					$hbonds += ($hbonds{dna2rna(join("", sort($sequence[$i], $sequence[$j])))} || 0);
					
				}
				
				push(@lst, $hbonds);
				
			}
			
			# @lst2 are cumulative stem lengts or H-bonds
			for (0 .. $#sets) {
				
				my @set = @{$sets[$_]}[0 .. $#{$sets[$_]}]; # 4. Patched from 1 .. $#{$sets[$_]
				push(@lst2, sum(@lst[@set]));
				
			}
			
			($largest) = grep { $lst2[$_] == max(@lst2) } 0 .. $#lst2;
			@largest = @{$sets[$largest]}[0 .. $#{$sets[$largest]}]; # 5. Patched from 1 .. $#{$sets[$largest]}
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
		
		Core::Utils::throw("Unbalanced dot-bracket structure") unless(isdbbalanced($pairs));
		
		my (@pkpairs, @structure);
		
		for my $helix (@{(listhelices($pairs))[1]}) { push(@pkpairs, map { [$helix->{h5bases}->[$_], $helix->{h3bases}->[$_]]} 0 .. $#{$helix->{h5bases}}); }
		
		#$pairs =~ s/[^\(\)\.]/./g; # Remove pseudoknotted base-pairs from original structure
		               
		return($pairs, \@pkpairs); 
		
	}
		
}

# Called by rmpseudoknots
# Recursively finds all combinations of compatible stems
sub _compatible_stems {
	
	my @compm = @_;
 
	my (@compatible, @incompatible);
 
	local *_traverse = sub {
	 
		my @predecessors = @_;
		my $current = $predecessors[-1];
		my %seen = map { $_ => 1 } @predecessors;
		
		# Search for successors that are incompatible with predecessors and
		# add them to %seen so that they are discarded
		if (@_) { # Changed to @_ instead of @_ > 1 (in case of issues change it back)
		
			my (%incompatible);
		
			for my $k (0 .. $#predecessors) {
			 
				%incompatible = map { $_->{j} => 1 } (grep {$_->{i} == $predecessors[$k] &&
							   					            $_->{c} == 1} @compm);
				%seen = (%seen, %incompatible);
										
			}
			
		}
		
		# Insert inside followers the first following compatible stem, or the first incompatible with this one
		my @followers = (map { $_->{j} } sort {$a->{j} <=> $b->{j}} (grep { $_->{i} == $current &&
																		    $_->{c} == 0 &&
																		    !exists $seen{$_->{j}} &&
																		    $_->{j} > $current } @compm))[0];
		
		if (@followers) {
			
			push(@followers, (map { $_->{j} } sort {$a->{j} <=> $b->{j}} (grep { $_->{i} == $followers[-1] &&
																			     $_->{c} == 1 &&
																			     !exists $seen{$_->{j}} &&
																			     $_->{j} > $current } @compm))[0]);
		
			_traverse(@predecessors, $_) for (@followers);
			
		}
		else { push(@compatible, [@predecessors]); }
		 
	};
 
	@incompatible =  (sort {$a <=> $b} (map { $_->{j} } (grep {$_->{i} == 0 && $_->{c} == 1} @compm)))[0];  
	push(@incompatible, 0); 
	
    _traverse($_) for (@incompatible);
                          
	return(@compatible); 
	
}

1;