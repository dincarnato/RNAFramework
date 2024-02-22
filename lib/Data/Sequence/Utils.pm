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
use Core::Mathematics qw(:all);
use Core::Utils;

use base qw(Exporter);

our @EXPORT = qw(isdna isrna isna isaa
                 isseq isalignment isiupac rev
                 dnacomp rnacomp revcomp dnarevcomp
                 rnarevcomp dna2rna rna2dna translate
                 aa1to3 nt2iupac iupac2nt iupac2regex
                 nshuffle dishuffle longestorf gencode
                 hamming);

sub isdna { return(is($_[0], $_[1] . "ACGNT")); }

sub isrna { return(is($_[0], $_[1] . "ACGNU")); }

sub isna { return(is($_[0], $_[1] . "ACGNTU")); }

sub isiupac { return(is($_[0], $_[1] . "ACGTUBDHKMNRSVWY")); }

sub isaa { return(is($_[0], $_[1] . "ACDEFGHIKLMNPQRSTVWXY*")); }

sub isseq { return(is($_[0], $_[1] . "ACDEFGHIKLMNPQRSTUVWXY*")); }

sub isalignment { return(is($_[0], $_[1] . " |*.")); }

sub rev {

    my $sequence = scalar reverse(uc(shift));

    return($sequence);

}

sub complement {

    my $sequence = uc(shift);

    return if (!isna($sequence, "BDHKMNRSVWY-"));

    if (isdna($sequence, "BDHKMNRSVWY-")) { return(dnacomp($sequence)); }
    else { return(rnacomp($sequence)); }

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

    my $sequence = shift;
    my $table = shift || 1;

    return if (!isna($sequence));
    return if (!isnumeric($table) ||
               !inrange($table, [1, 17]));

    my ($code, $peptide);

    $code = gencode($table);
    $sequence = dna2rna($sequence);

    while($sequence =~ m/^(\w{3})/) {

        my $codon = $1;

        $peptide .= $code->{$codon};
        $sequence =~ s/^$codon//;

    }

    return($peptide);

}

sub gencode {

    my $table = shift || 1;

    return if ($table !~ m/^\d+$/ ||
               $table < 1 ||
               $table > 33);

    my ($code, $altstart);
    $code = { UCA => "S", UCC => "S", UCG => "S", UCU => "S",
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
    $altstart = [];


    if ($table == 1) { $altstart = [ qw(CUG GUG UUG) ]; }
    elsif ($table == 2) {

        $code->{AGA} = "*";
        $code->{AGG} = "*";
        $code->{AUA} = "M";
        $code->{UGA} = "W";

        $altstart = [ qw(AUA AUU AUC GUG) ];

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

        $altstart = [ qw(AUA GUG) ];

    }
    elsif ($table == 4) {

      $code->{UGA} = "W";

      $altstart = [ qw(AUA AUC AUU CUG
                       GUG GUA UUA UUG) ];

    }
    elsif ($table == 5) {

        $code->{AGA} = "S";
        $code->{AGG} = "S";
        $code->{AUA} = "M";
        $code->{UGA} = "W";

        $altstart = [ qw(AUA AUC AUU GUG
                         UUG) ];

    }
    elsif ($table == 6) {

        $code->{UAA} = "Q";
        $code->{UAG} = "Q";

    }
    elsif ($table == 9) {

        $code->{AAA} = "N";
        $code->{AGA} = "S";
        $code->{AGG} = "S";
        $code->{UGA} = "W";

        $altstart = [ qw(GUG) ];

    }
    elsif ($table == 10) { $code->{UGA} = "C"; }
    elsif ($table == 11) {

        $altstart = [ qw(AUA AUC AUU CUG
                         GUG UUG) ];

    }
    elsif ($table == 12) {

        $code->{CUG} = "S";

        $altstart = [ qw(CAG CUG) ];

    }
    elsif ($table == 13) {

        $code->{AGA} = "G";
        $code->{AGG} = "G";
        $code->{AUA} = "M";
        $code->{UGA} = "W";

        $altstart = [ qw(AUA GUG UUG) ];

    }
    elsif ($table == 14) {

        $code->{AAA} = "N";
        $code->{AGA} = "S";
        $code->{AGG} = "S";
        $code->{UAA} = "Y";
        $code->{UGA} = "W";

    }
    elsif ($table == 16) { $code->{UAG} = "L"; }
    elsif ($table == 21) {

        $code->{UGA} = "W";
        $code->{AUA} = "M";
        $code->{AGA} = "S";
        $code->{AGG} = "S";
        $code->{AAA} = "N";

        $altstart = [ qw(GUG) ];

    }
    elsif ($table == 22) {

        $code->{UCA} = "*";
        $code->{UAG} = "L";

    }
    elsif ($table == 23) {

        $code->{UUA} = "*";

        $altstart = [ qw(AUU GUG) ];

    }
    elsif ($table == 24) {

        $code->{AGA} = "S";
        $code->{AGG} = "K";
        $code->{UGA} = "W";

        $altstart = [ qw(CUG GUG UUG) ];

    }
    elsif ($table == 25) {

        $code->{UGA} = "G";

        $altstart = [ qw(GUG UUG) ];

    }
    elsif ($table == 26) {

        $code->{CUG} = "A";

        $altstart = [ qw(CUG GUG UUG) ];

    }
    elsif ($table == 27) {

        $code->{UAG} = "Q";
        $code->{UAA} = "Q";

    }
    elsif ($table == 29) {

        $code->{UAA} = "Y";
        $code->{UAG} = "Y";

    }
    elsif ($table == 30) {

        $code->{UAA} = "E";
        $code->{UAG} = "E";

    }
    elsif ($table == 31) { $code->{UGA} = "W"; }
    elsif ($table == 33) {

        $code->{UAA} = "Y";
        $code->{UGA} = "W";
        $code->{AGA} = "S";
        $code->{AGG} = "K";

        $altstart = [ qw(CUG GUG UUG) ];

    }

    return(wantarray() ? ($code, $altstart) : $code);

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

        my @nt = sort(uniq(split(//, $nt)));
        $nt = join("", @nt);

        $nt =~ s/ACG[TU]/N/g;
        $nt =~ s/ACG/V/g;
        $nt =~ s/AC[TU]/H/g;
        $nt =~ s/AG[TU]/D/g;
        $nt =~ s/CG[TU]/B/g;
        $nt =~ s/AG/R/g;
        $nt =~ s/C[TU]/Y/g;
        $nt =~ s/A[TU]/W/g;
        $nt =~ s/CG/S/g;
        $nt =~ s/AC/M/g;
        $nt =~ s/G[TU]/K/g;

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

sub nshuffle {

    my $sequence = shift;

    my (@sequence, @letters);
    @sequence = split(//, $sequence);
    @letters = 0 .. $#sequence;

    return(join("", @sequence[map splice(@letters, rand(@letters), 1), @letters]));

}

sub dishuffle {

   my $sequence = shift;

   return unless(isna($sequence));

   my $clone = $sequence;

   for (1 .. length($sequence) - 2) {

      my ($triplet, $prepost, $i, $j,
          @tris, @indexes);
      $triplet = substr($clone, $_- 1, 3);
      @tris = split //, $triplet;
      $prepost = $tris[0] . $tris[2];
      $i = 0;
      $j = $_ - 1;

      while($clone =~ m/$prepost/g) {

         $i = index($clone, $prepost, $i);
         push(@indexes, $i) if ($i - 1 != $j);

         $i++;

      }

      next unless (@indexes);

      my $n = $indexes[int(rand(scalar(@indexes)))];

      $j++ if ($j > $n);

      $clone =~ s/^(.{$n})$prepost/$1 . $triplet/e;
      $clone =~ s/^(.{$j})$triplet/$1 . $prepost/e;

   }

   return($clone);

}

# Usage:
#
# longestorf($sequence, { gencode     => 1-33,
#                         altstart    => [01],
#                         ignorestart => [01],
#                         minlength   => min. len in aa })

sub longestorf {

   my $sequence = shift;
   my $params = checkparameters({ gencode     => 1,
                                  altstart    => 0,
                                  ignorestart => 0,
                                  minlength   => 0 }, shift || {});


   return if (!isna($sequence) ||
              !isbool($params->{altstart}, $params->{ignorestart}) ||
              !ispositive($params->{minlength}));

   my ($orf, $index, $startregex, $stopregex,
       $altstarts);
   $sequence = dna2rna($sequence);
   ($params->{gencode}, $altstarts) = gencode($params->{gencode} || 1);

   return unless($params->{gencode});

   $stopregex = join("|", grep { $params->{gencode}->{$_} eq "*" } keys %{$params->{gencode}});

   if ($params->{ignorestart}) { $startregex = "(?!" . $stopregex . ")"; }
   elsif ($params->{altstart}) { $startregex = "(?:" . join("|", @{$altstarts}) . ")"; }
   else { $startregex = "AUG"; }

   while ($sequence =~ m/(?=($startregex(?:(?!$stopregex).{3}?)+(?:$stopregex)))/ig) { $orf = $1 if (length($1) > length($orf)); }

	return if (!$orf ||
              (length($orf) / 3) - 1 < $params->{minlength});

	$index = index($sequence, $orf, 0);

   return(wantarray() ? ($orf, $index) : $orf);

}

sub hamming { return ($_[0] ^ $_[1]) =~ tr/\001-\255//; }

1;
