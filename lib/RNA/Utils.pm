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
use Core::Mathematics;
use Core::Utils;
use Data::Sequence::Utils;

use base qw(Exporter);

our @EXPORT = qw(isdotbracket isdbbalanced fixdotbracket rnapair
                 ct2db db2ct listpairs ppv
                 sensitivity bpdistance);

sub isdotbracket { return(is($_[0], $_[1] . quotemeta("()."))); }

sub isdbbalanced {
    
    my ($dotbracket, $sequence) = @_;
    
    return() if (!isdotbracket($dotbracket) ||
                 (defined $sequence &&
                  (length($sequence) != length($dotbracket) ||
                   !isna($sequence))));
    
    my $i = 0;

    while ($dotbracket =~ m/(\(\.+?\))/) {
    
        my ($match, $dots);
        $match = $1;
        $i = index($dotbracket, $match, 0);
    
        return() if (defined $sequence &&
                     !rnapair(substr($sequence, $i, 1), substr($sequence, ($i + length($match) - 1), 1)));
        
        $dots = "." x length($match);
        $match = quotemeta($match);
        $dotbracket =~ s/^(.{$i})$match/$1 . $dots/e;
        
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
    
    my $pairs = { A => "U", U => "AG", G => "CU", C => "G" };
    
    if ($excludegu) {
        
        $pairs->{U} = "A";
        $pairs->{G} = "C";
        
    }
    
    $_ = dna2rna(uc($_)) for ($base1, $base2); 
    
    return unless(isrna(join("", $base1, $base2)));
    
    return(1) if ($pairs->{$base1} =~ m/$base2/);
    
    return();
    
}

sub ct2db {
    
    my ($ct, $n) = @_;
    $n = 0 unless(isint($n));
    
    return() unless(-e $ct);
    
    my ($i, $head, $sequence, $dotbracket,
        $energy);
    $i = 0;
    $head = 0;
    
    open(my $fh, "<" . $ct) or return();
    while(<$fh>) {
        
        my @line = split(" ", $_);
        
        if ($_ =~ m/ = / &&
            @line != 6) {
            
            if ($i == $n) {
                
                $energy = $line[3] || 0;
                $head = 1;
                    
            }
            else { $head = 0; }
            
            $i++;
            
            next();
            
        }
        
        if ($head) {
            
            $sequence .= $line[1];
            
            if ($line[4] == 0) { $dotbracket .= "."; }
            elsif ($line[4] > $line[0]) { $dotbracket .= "("; }
            elsif ($line[4] < $line[0]) { $dotbracket .= ")"; }
            
        }
    
    }
    close($fh);
    
    return() unless($dotbracket);
    
    return($dotbracket, $sequence, $energy);
    
}

sub db2ct {
    
    my ($sequence, $dotbracket) = @_;
    
    return() if (!isna($sequence) ||
                 !isdotbracket($dotbracket));
    
    my ($i, $ct, @ct);
    
    while ($dotbracket =~ m/(\(\.+?\))/) {
        
        my $match = $1;
        $i = index($dotbracket, $match, 0);
        my $j = $i + length($match) - 1;
    
        my $dots = "." x length($match);
        
        $match = quotemeta($match);
        $dotbracket =~ s/^(.{$i})$match/$1 . $dots/e;
    
        $ct[$i] = $j + 1;
        $ct[$j] = $i + 1;
            
    }
    
    $ct .= sprintf("%6d %s %6d %6d %6d %6d\n", ($_ + 1), substr($sequence, $_, 1), $_, ($_ + 2), ($ct[$_] || 0), ($_ + 1)) for (0 .. length($sequence) - 1);
    
    return($ct);
    
}

sub listpairs {
    
    my $dotbracket = shift;
    
    return() if (!isdotbracket($dotbracket) ||
                 !isdbbalanced($dotbracket));
    
    my (@dotbracket, @open, @pairs);
    @dotbracket = split(//, $dotbracket);

    for(my $i = 0; $i < @dotbracket; $i++) {

        if ($dotbracket[$i] eq "(") { push(@open, $i); }
        elsif ($dotbracket[$i] eq ")") {
            
            my $n5 = pop(@open);
            push(@pairs, [$n5, $i]);
            
        }

    }

    @pairs = reverse(@pairs);
    
    return(wantarray() ? @pairs : \@pairs);
    
}

sub ppv {
    
    my ($reference, $structure) = @_;
    
    if (my $common = _commonpairs($reference, $structure)) { return($common / @{listpairs($structure)}); }
    
    return();
    
}

sub sensitivity {
    
    my ($reference, $structure) = @_;
    
    if (my $common = _commonpairs($reference, $structure)) { return($common / @{listpairs($reference)}); }
    
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
    
    my ($reference, $structure) = @_;
    
    my ($common, %reference);
    
    return() if (!isdotbracket($reference) ||
                 !isdbbalanced($reference) ||
                 !isdotbracket($structure) ||
                 !isdbbalanced($structure) ||
                 length($reference) != length($structure));
    
    for (listpairs($reference)) { $reference{$_->[0] . "-" . $_->[1]} = 1; }

    for (listpairs($structure)) { $common++ if (exists $reference{$_->[0] . "-" . $_->[1]}); }

    return($common);
    
}

1;
