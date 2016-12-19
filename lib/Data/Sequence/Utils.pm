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

package Data::Sequence::Utils;

use strict;
use Core::Utils;

use base qw(Exporter);

our @EXPORT = qw(isdna isrna isna isaa
                 isseq isalignment isiupac rev
                 dnacomp rnacomp revcomp dnarevcomp
                 rnarevcomp dna2rna rna2dna translate
                 aa1to3 nt2iupac iupac2nt iupac2regex
                 shuffle);

sub isdna { return(is($_[0], $_[1] . "ACGNT")); }

sub isrna { return(is($_[0], $_[1] . "ACGNU")); }

sub isna { return(is($_[0], $_[1] . "ACGNTU")); }

sub isiupac { return(is($_[0], $_[1] . "ACGTUBDHKMNRSVWY")); }

sub isaa { return(is($_[0], $_[1] . "ACDEFGHIKLMNPQRSTVWXY*")); }

sub isseq { return(is($_[0], $_[1] . "ACDEFGHIKLMNPQRSTUVWXY*")); }

sub isalignment { return(is($_[0], $_[1] . " |*.")); }

sub rev {
    
    my $sequence = reverse(uc(shift));
    
    return($sequence);
    
}

sub complement {
    
    my $sequence = uc(shift);
    
    return if (!isna($sequence, "BDHKMNRSVWY-"));
    
    if (isdna($sequence, "BDHKMNRSVWY-")) { return(dnarevcomp($sequence)); }
    else { return(rnarevcomp($sequence)); }
    
    return($sequence);
    
}

sub revcomp {
    
    my $sequence = uc(shift);
    
    return (rev(complement($sequence)));
    
}

sub dnacomp {
    
    my $sequence = rna2dna(shift);
    
    return unless(isdna($sequence, "BDHKMNRSVWY-"));
    
    $sequence =~ tr/ACGTVHRMBDYK/TGCABDYKVHRM/;
    
    return($sequence);
    
}

sub rnacomp {
    
    my $sequence = shift;
    
   return(dna2rna(dnacomp($sequence)));
    
}

sub dnarevcomp {
    
    my $sequence = shift;
    
    return(rev(dnacomp($sequence)));
    
}

sub rnarevcomp {
    
    my $sequence = shift;
    
    return(rev(rnacomp($sequence)));
    
}

sub dna2rna {
    
    my $sequence = uc(shift);
    
    return if (!isiupac($sequence, "-"));
    
    $sequence =~ tr/T/U/;
    
    return($sequence);
    
}

sub rna2dna {
    
    my $sequence = uc(shift);
    
    return if (!isiupac($sequence, "-"));
    
    $sequence =~ tr/U/T/;
    
    return($sequence);
    
}

sub translate {
    
    my ($sequence, $table) = @_;
    
    return if (!isna($sequence));
    return if ($table !~ m/^\d+$/ ||
               $table < 1 ||
               $table > 17);
    
    my ($code, $peptide);
    
    $code = _codetable($table);
    $sequence = dna2rna($sequence);
    
    while($sequence =~ m/^(\w{3})/) {
        
        my $codon = $1;
        
        $peptide .= $code->{$codon};
        $sequence =~ s/^$codon//;
        
    }
    
    return($peptide);
    
}

sub _codetable {
    
    my $table = shift || 1;
    
    return if ($table !~ m/^\d+$/ ||
               $table < 1 ||
               $table > 17);
    
    my $code = { UCA => "S", UCC => "S", UCG => "S", UCU => "S",
                 UUC => "F", UUU => "F", UUA => "L", UUG => "L",
                 UAC => "Y", UAU => "Y", UAA => "*", UAG => "*",
                 UGC => "C", UGU => "C", UGA => "*", UGG => "W",
                 CUA => "L", CUC => "L", CUG => "L", CUU => "L",
                 CCA => "P", CAU => "H", CAA => "Q", CAG => "Q",
                 CGA => "R", CGC => "R", CGG => "R", CGU => "R",
                 AUA => "T", AUC => "T", AUU => "T", AUG => "M",
                 ACA => "T", ACC => "T", ACG => "T", ACU => "T",
                 AAC => "N", AAU => "N", AAA => "K", AAG => "K",
                 AGC => "S", AGU => "S", AGA => "R", AGG => "R",
                 CCC => "P", CCG => "P", CCU => "P", CAC => "H",
                 GUA => "V", GUC => "V", GUG => "V", GUU => "V",
                 GCA => "A", GCC => "A", GCG => "A", GCU => "A",
                 GAC => "D", GAU => "D", GAA => "E", GAG => "E",
                 GGA => "G", GGC => "G", GGG => "G", GGU => "G" };
    
    return($code) if ($table =~ m/^[19]$/);
    
    if ($table == 2) {
        
        $code->{AGA} = "*";
        $code->{AGG} = "*";
        $code->{AUA} = "M";
        $code->{UGA} = "W";
        
    }
    elsif ($table == 3) {
        
        $code->{AUA} = "M";
        $code->{CUU} = "T";
        $code->{CUC} = "T";
        $code->{CUA} = "T";
        $code->{CUG} = "T";
        $code->{UGA} = "W";
        $code->{CGA} = "-";
        $code->{CGC} = "-";
        
    }
    elsif ($table == 4) { $code->{UGA} = "W"; }
    elsif ($table == 5) {
        
        $code->{AGA} = "S";
        $code->{AGG} = "S";
        $code->{AUA} = "M";
        $code->{UGA} = "W";
        
    }
    elsif ($table == 6) {
        
        $code->{UAA} = "Q";
        $code->{UAG} = "Q";
        
    }
    elsif ($table == 7) {
        
        $code->{AAA} = "N";
        $code->{AGA} = "S";
        $code->{AGG} = "S";
        $code->{UGA} = "W";
        
    }
    elsif ($table == 8) { $code->{UGA} = "C"; } 
    elsif ($table == 10) { $code->{CUG} = "S"; }
    elsif ($table == 11) {
        
        $code->{AGA} = "G";
        $code->{AGG} = "G";
        $code->{AUA} = "M";
        $code->{UGA} = "W";
        
    }
    elsif ($table == 12) {
        
        $code->{AAA} = "N";
        $code->{AGA} = "S";
        $code->{AGG} = "S";
        $code->{UAA} = "Y";
        $code->{UGA} = "W";
        
    }
    elsif ($table == 13) { $code->{UAG} = "Q"; }
    elsif ($table == 14) { $code->{UAG} = "L"; }
    elsif ($table == 15) {
        
        $code->{UGA} = "W";
        $code->{AUA} = "M";
        $code->{AGA} = "S";
        $code->{AGG} = "S";
        
    }
    elsif ($table == 16) {
        
        $code->{UCA} = "*";
        $code->{UAG} = "L";
        
    }
    elsif ($table == 17) { $code->{UUA} = "*"; }
    
    return $code;
    
}

sub aa1to3 {
    
    my $sequence = uc(shift);
    
    return unless(isaa($sequence, "_*"));
    
    my ($aa, @peptide);
    
    $aa = { A => "Ala", C   => "Cys",  D    => "Asp", E => "Glu",
            F => "Phe", G   => "Gly",  H    => "His", I => "Ile",
            K => "Lys", L   => "Leu",  M    => "Met", N => "Asn",
            P => "Pro", Q   => "Gln",  R    => "Arg", S => "Ser",
            T => "Thr", V   => "Val",  W    => "Trp", X => "XXX",
            Y => "Tyr", "*" => "Stop", "_"  => "None" };
    
    while($sequence =~ m/^(.)/) {
        
        my $aminoacid = $1;
        
        push(@peptide, $aa->{$aminoacid});
        $sequence =~ s/^$aminoacid//;
        
    }
    
    return(join("-", @peptide));
    
}

sub nt2iupac {
    
    my @nucleotides = @_;
    
    my ($iupac);
    
    foreach my $nt (@nucleotides) {
        
        my @nt = sort(split(//, rna2dna($nt)));
        $nt = join("", $nt);
    
        $nt =~ s/ACGT/N/g;
        $nt =~ s/ACG/V/g;
        $nt =~ s/ACT/H/g;
        $nt =~ s/AGT/D/g;
        $nt =~ s/CGT/B/g;
        $nt =~ s/AG/R/g;
        $nt =~ s/CT/Y/g;
        $nt =~ s/AT/W/g;
        $nt =~ s/CG/S/g;
        $nt =~ s/AC/M/g;
        $nt =~ s/GT/K/g;
        
        $iupac .= $nt;
    
    }
         
    return($iupac);
    
}

sub iupac2nt {

    my $iupac = shift;
    
    return unless(isiupac($iupac, "-"));
    
    my (@nt);
    
    for (split(//, $iupac)) {
    
        $_ =~ s/N/ACGT/g;
        $_ =~ s/R/AG/g;
        $_ =~ s/Y/CT/g;
        $_ =~ s/W/AT/g;
        $_ =~ s/S/CG/g;
        $_ =~ s/M/AC/g;
        $_ =~ s/K/GT/g;
        $_ =~ s/B/CGT/g;
        $_ =~ s/H/ACT/g;
        $_ =~ s/D/AGT/g;
        $_ =~ s/V/ACG/g;
        
        push(@nt, $_);
           
    }
    
    return(wantarray() ? @nt : \@nt);
    
}

sub iupac2regex {

    my $regex = shift;
    
    return unless(isna($regex, "BDHKMNRSVWY-"));
    
    $regex =~ s/N/\[ACGTUN-\]/g;
    $regex =~ s/R/\[AGR\]/g;
    $regex =~ s/Y/\[CTUY\]/g;
    $regex =~ s/W/\[ATUW\]/g;
    $regex =~ s/S/\[CGS\]/g;
    $regex =~ s/M/\[ACM\]/g;
    $regex =~ s/K/\[GTUK\]/g;
    $regex =~ s/B/\[CGTUB\]/g;
    $regex =~ s/H/\[ACTUH\]/g;
    $regex =~ s/D/\[AGTUD\]/g;
    $regex =~ s/V/\[ACGV\]/g;
           
    return($regex);
    
}

sub shuffle {
    
    my $sequence = shift;
    
    my (@sequence, @letters);
    @sequence = split(//, $sequence);
    @letters = 0 .. $#sequence;
    
    return(join("", @sequence[map splice(@letters, rand(@letters), 1), @letters]));
    
}

1;