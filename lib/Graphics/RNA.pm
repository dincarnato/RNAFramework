package Graphics::RNA;

##
# Note: Secondary structure layouts ported from RFview.js. The Radiate layout
#       derives from Yann Ponty's VARNA (https://github.com/yannponty/VARNA);
#       the NAView layout from Ivo Hofacker's adaptation of the Bruccoleri &
#       Heinrich algorithm (https://github.com/ViennaRNA/RNAcode/blob/master/librna/naview.c)
##

use strict;
use POSIX qw(ceil);

use Core::Mathematics;
use Core::Utils;
use Data::IO::XML;
use Data::Sequence::Utils;
use Data::XML;
use Graphics::RNA::Utils;
use RNA::Utils;

use base qw(Core::Base);

use constant BP_OFFSET => 2.8; # Distance between the two lines of a GC bond
use constant BOND_DOT_RADIUS => 4.5;
use constant BACKBONE_WIDTH => 1.3;    
use constant BOND_WIDTH => 1.43;       
use constant BASE_STROKE_WIDTH => 1.3; 
use constant CONTRAST_LIMIT => 0.5; # Luminance above which base letters are drawn dark rather than light
use constant BASE_FONT_SIZE => 1.3;  # Multiple of the base radius
use constant BASE_FONT_BASELINE => 0.334; # Multiple of the font size
use constant LEGEND_BAR_WIDTH => 110;
use constant LEGEND_SWATCH => 14;
use constant LEGEND_TITLE_SIZE => 13;
use constant LEGEND_LABEL_SIZE => 11;
use constant LEGEND_GAP => 4; # Between discrete swatches
use constant LEGEND_PAD => 6; # Between a swatch and its label
use constant LEGEND_MARGIN => 16; # Gap between the structure and the legend
use constant LEGEND_CHAR_WIDTH => 0.6;
use constant LEGEND_TITLE_CHAR_WIDTH => 0.58;

my %cssColors = (aliceblue => "#f0f8ff", antiquewhite => "#faebd7", aqua => "#00ffff",
                 aquamarine => "#7fffd4", azure => "#f0ffff", beige => "#f5f5dc",
                 bisque => "#ffe4c4", black => "#000000", blanchedalmond => "#ffebcd",
                 blue => "#0000ff", blueviolet => "#8a2be2", brown => "#a52a2a",
                 burlywood => "#deb887", cadetblue => "#5f9ea0", chartreuse => "#7fff00",
                 chocolate => "#d2691e", coral => "#ff7f50", cornflowerblue => "#6495ed",
                 cornsilk => "#fff8dc", crimson => "#dc143c", cyan => "#00ffff",
                 darkblue => "#00008b", darkcyan => "#008b8b", darkgoldenrod => "#b8860b",
                 darkgray => "#a9a9a9", darkgreen => "#006400", darkgrey => "#a9a9a9",
                 darkkhaki => "#bdb76b", darkmagenta => "#8b008b", darkolivegreen => "#556b2f",
                 darkorange => "#ff8c00", darkorchid => "#9932cc", darkred => "#8b0000",
                 darksalmon => "#e9967a", darkseagreen => "#8fbc8f", darkslateblue => "#483d8b",
                 darkslategray => "#2f4f4f", darkslategrey => "#2f4f4f", darkturquoise => "#00ced1",
                 darkviolet => "#9400d3", deeppink => "#ff1493", deepskyblue => "#00bfff",
                 dimgray => "#696969", dimgrey => "#696969", dodgerblue => "#1e90ff",
                 firebrick => "#b22222", floralwhite => "#fffaf0", forestgreen => "#228b22",
                 fuchsia => "#ff00ff", gainsboro => "#dcdcdc", ghostwhite => "#f8f8ff",
                 gold => "#ffd700", goldenrod => "#daa520", gray => "#808080",
                 green => "#008000", greenyellow => "#adff2f", grey => "#808080",
                 honeydew => "#f0fff0", hotpink => "#ff69b4", indianred => "#cd5c5c",
                 indigo => "#4b0082", ivory => "#fffff0", khaki => "#f0e68c",
                 lavender => "#e6e6fa", lavenderblush => "#fff0f5", lawngreen => "#7cfc00",
                 lemonchiffon => "#fffacd", lightblue => "#add8e6", lightcoral => "#f08080",
                 lightcyan => "#e0ffff", lightgoldenrodyellow => "#fafad2", lightgray => "#d3d3d3",
                 lightgreen => "#90ee90", lightgrey => "#d3d3d3", lightpink => "#ffb6c1",
                 lightsalmon => "#ffa07a", lightseagreen => "#20b2aa", lightskyblue => "#87cefa",
                 lightslategray => "#778899", lightslategrey => "#778899", lightsteelblue => "#b0c4de",
                 lightyellow => "#ffffe0", lime => "#00ff00", limegreen => "#32cd32",
                 linen => "#faf0e6", magenta => "#ff00ff", maroon => "#800000",
                 mediumaquamarine => "#66cdaa", mediumblue => "#0000cd", mediumorchid => "#ba55d3",
                 mediumpurple => "#9370db", mediumseagreen => "#3cb371", mediumslateblue => "#7b68ee",
                 mediumspringgreen => "#00fa9a", mediumturquoise => "#48d1cc", mediumvioletred => "#c71585",
                 midnightblue => "#191970", mintcream => "#f5fffa", mistyrose => "#ffe4e1",
                 moccasin => "#ffe4b5", navajowhite => "#ffdead", navy => "#000080",
                 oldlace => "#fdf5e6", olive => "#808000", olivedrab => "#6b8e23",
                 orange => "#ffa500", orangered => "#ff4500", orchid => "#da70d6",
                 palegoldenrod => "#eee8aa", palegreen => "#98fb98", paleturquoise => "#afeeee",
                 palevioletred => "#db7093", papayawhip => "#ffefd5", peachpuff => "#ffdab9",
                 peru => "#cd853f", pink => "#ffc0cb", plum => "#dda0dd",
                 powderblue => "#b0e0e6", purple => "#800080", rebeccapurple => "#663399",
                 red => "#ff0000", rosybrown => "#bc8f8f", royalblue => "#4169e1",
                 saddlebrown => "#8b4513", salmon => "#fa8072", sandybrown => "#f4a460",
                 seagreen => "#2e8b57", seashell => "#fff5ee", sienna => "#a0522d",
                 silver => "#c0c0c0", skyblue => "#87ceeb", slateblue => "#6a5acd",
                 slategray => "#708090", slategrey => "#708090", snow => "#fffafa",
                 springgreen => "#00ff7f", steelblue => "#4682b4", tan => "#d2b48c",
                 teal => "#008080", thistle => "#d8bfd8", tomato => "#ff6347",
                 turquoise => "#40e0d0", violet => "#ee82ee", wheat => "#f5deb3",
                 white => "#ffffff", whitesmoke => "#f5f5f5", yellow => "#ffff00",
                 yellowgreen => "#9acd32");

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ sequence     => undef,
                   structure    => undef,
                   file         => undef,
                   values       => [],
                   layout       => "auto",
                   tolerance    => 0,
                   maxAutoLen   => 1000,
                   colorScale   => "gradient",
                   legend       => {},
                   missingColor => "#8f8f8f",
                   plotIndices  => 0,
                   indicesStep  => 10,
                   plotLegend   => 0,
                   legendTitle  => undef,
                   legendScale  => 1,
                   baseRadius   => 12,
                   plotBases    => 1,
                   plotCircles  => 1,
                   plotPairs    => 1,
                   padding      => 40,
                   scale        => 1,
                   overwrite    => 0,
                   _coords      => [],
                   _pairs       => [],
                   _pkpairs     => [],
                   _legendKeys  => [],
                   _layout      => undef }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->{layout} = lc($self->{layout});
    $self->{colorScale} = lc($self->{colorScale});

    $self->throw("No structure provided") if (!defined $self->{structure});
    $self->throw("No output file provided") if (!defined $self->{file});
    $self->throw("Sequence contains invalid characters") if (defined $self->{sequence} && !isna($self->{sequence}, "-"));
    $self->throw("Structure is not balanced") if (!isdbbalanced($self->{structure}));
    $self->throw("Structure is not a valid dot-bracket") if (!isdotbracket($self->{structure}));
    $self->throw("Sequence and structure have different lengths") if (defined $self->{sequence} && length($self->{sequence}) != length($self->{structure}));
    $self->throw("Layout must be \"auto\", \"naview\" or \"radiate\"") if ($self->{layout} !~ /^(?:auto|naview|radiate)$/);
    $self->throw("Color scale must be \"gradient\" or \"discrete\"") if ($self->{colorScale} !~ /^(?:gradient|discrete)$/);
    $self->throw("Tolerance must be a positive integer") if (!ispositive($self->{tolerance}) || !isint($self->{tolerance}));
    $self->throw("maxAutoLen must be a positive integer") if (!ispositive($self->{maxAutoLen}) || !isint($self->{maxAutoLen}));
    $self->throw("Values must be provided as an ARRAY reference") if (ref($self->{values}) ne "ARRAY");
    $self->throw("Values array is longer than the RNA") if (@{$self->{values}} > length($self->{structure}));
    $self->throw("Legend must be provided as an HASH reference") if (ref($self->{legend}) ne "HASH");
    $self->throw("legendScale must be a positive number") if (!ispositive($self->{legendScale}) || !$self->{legendScale});
    $self->throw("Base radius must be a positive number") if (!ispositive($self->{baseRadius}));
    $self->throw("Scale must be a positive number") if (!ispositive($self->{scale}) || !$self->{scale});
    for (qw(plotLegend plotIndices plotBases plotCircles plotPairs)) { $self->throw("$_ must be BOOL") if (!isbool($self->{$_})); }

    my $missing = _normalizeColor($self->{missingColor});

    $self->throw("missingColor is not a valid CSS color (\"" . $self->{missingColor} . "\")") if (!defined $missing);

    $self->{missingColor} = $missing;

    foreach my $key (keys %{$self->{legend}}) {

        my $color = _normalizeColor($self->{legend}->{$key});

        $self->throw("Legend color for key \"$key\" is not a valid CSS color (\"" . $self->{legend}->{$key} . "\")") if (!defined $color);

        $self->{legend}->{$key} = $color;

        $self->throw("Legend keys must be numeric when colorScale is \"gradient\" (key: \"$key\")") if ($self->{colorScale} eq "gradient" && !isnumeric($key));

    }

    if ($self->{colorScale} eq "gradient") {

        foreach my $value (@{$self->{values}}) {

            $self->throw("Values must be numeric when colorScale is \"gradient\"") if (defined $value && !isnumeric($value) && !isnan($value));

        }

        $self->{_legendKeys} = [sort { $a <=> $b } keys %{$self->{legend}}];

    }
    else { $self->{_legendKeys} = [_sortKeys(keys %{$self->{legend}})]; }

    $self->{sequence} = uc(dna2rna($self->{sequence})) if (defined $self->{sequence});

}

sub _normalizeColor {

    my $color = shift;

    return if (!defined $color);

    $color =~ s/^\s+|\s+$//g;

    return(lc($color)) if ($color =~ m/^#[0-9a-fA-F]{6}$/);

    if ($color =~ m/^#([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])$/) { return(lc("#" . $1 . $1 . $2 . $2 . $3 . $3)); }
    elsif ($color =~ m/^rgba?\(([^)]+)\)$/i) {

        my @c = split(/\s*[,\s\/]\s*/, $1);

        return if (@c < 3);

        for (0 .. 2) {

            $c[$_] =~ s/^\s+|\s+$//g;
            $c[$_] = $c[$_] =~ m/%$/ ? 255 * ($c[$_] =~ s/%$//r) / 100 : $c[$_];

            return if (!isnumeric($c[$_]));

            $c[$_] = 0 if ($c[$_] < 0);
            $c[$_] = 255 if ($c[$_] > 255);

        }

        return(sprintf("#%02x%02x%02x", map { int($_ + 0.5) } @c[0 .. 2]));

    }

    return($cssColors{lc($color)}) if (exists $cssColors{lc($color)});

    return;

}

sub _valueToColor {

    my ($self, $v) = @_;

    my @keys = @{$self->{_legendKeys}};

    return($self->{missingColor}) if (!@keys || !defined $v);

    if ($self->{colorScale} eq "discrete") { return(exists $self->{legend}->{$v} ? $self->{legend}->{$v} : $self->{missingColor}); }

    return($self->{missingColor}) if (!isnumeric($v));
    return($self->{legend}->{$keys[0]}) if (@keys == 1 || $v <= $keys[0]);
    return($self->{legend}->{$keys[-1]}) if ($v >= $keys[-1]);

    for my $i (0 .. $#keys - 1) {

        if ($v >= $keys[$i] && $v <= $keys[$i + 1]) {

            my $t = ($keys[$i + 1] - $keys[$i]) ? ($v - $keys[$i]) / ($keys[$i + 1] - $keys[$i]) : 0;

            return(_lerpColor($self->{legend}->{$keys[$i]}, $self->{legend}->{$keys[$i + 1]}, $t));

        }

    }

    return($self->{legend}->{$keys[-1]});

}

sub _sortKeys {

    my @keys = @_;

    return(sort { $a <=> $b } @keys) if (!grep { !isnumeric($_) } @keys);

    return(sort { $a cmp $b } @keys);

}

sub _hex2rgb { my $h = shift; return(map { hex(substr($h, $_ * 2 + 1, 2)) / 255 } (0 .. 2)); }

sub _lerpColor {

    my ($a, $b, $t) = @_;

    my @ca = _hex2rgb($a);
    my @cb = _hex2rgb($b);

    return("#" . join("", map { sprintf("%02x", int(_clamp01($ca[$_] + ($cb[$_] - $ca[$_]) * $t) * 255 + 0.5)) } (0 .. 2)));

}

sub _clamp01 { my $x = shift; return($x < 0 ? 0 : ($x > 1 ? 1 : $x)); }

sub _contrastTextColor {

    my $hex = shift;

    return("#1a1a2e") if (!defined $hex || $hex !~ m/^#[0-9a-fA-F]{6}$/);

    my @rgb = _hex2rgb($hex);
    my @lin = map { $_ <= 0.03928 ? $_ / 12.92 : (($_ + 0.055) / 1.055) ** 2.4 } @rgb;
    my $L = 0.2126 * $lin[0] + 0.7152 * $lin[1] + 0.0722 * $lin[2];

    return($L > CONTRAST_LIMIT ? "#1a1a2e" : "#f0f6ff");

}

sub _scoreOverlaps {

    my ($self, $coords) = @_;

    my $n = @{$coords};
    my $count = 0;

    my $cross = sub {

        my ($ox, $oy, $ax, $ay, $bx, $by) = @_;

        return(($ax - $ox) * ($by - $oy) - ($ay - $oy) * ($bx - $ox));

    };

    for (my $i = 0; $i < $n - 1; $i++) {

        my ($x1, $y1) = ($coords->[$i]->{x}, $coords->[$i]->{y});
        my ($x2, $y2) = ($coords->[$i + 1]->{x}, $coords->[$i + 1]->{y});
        my ($lox, $hix) = $x1 < $x2 ? ($x1, $x2) : ($x2, $x1);
        my ($loy, $hiy) = $y1 < $y2 ? ($y1, $y2) : ($y2, $y1);

        for (my $j = $i + 2; $j < $n - 1; $j++) {

            my ($x3, $y3) = ($coords->[$j]->{x}, $coords->[$j]->{y});
            my ($x4, $y4) = ($coords->[$j + 1]->{x}, $coords->[$j + 1]->{y});

            next if (($x3 < $lox && $x4 < $lox) || ($x3 > $hix && $x4 > $hix) ||
                     ($y3 < $loy && $y4 < $loy) || ($y3 > $hiy && $y4 > $hiy));

            my $d1 = $cross->($x3, $y3, $x4, $y4, $x1, $y1);
            my $d2 = $cross->($x3, $y3, $x4, $y4, $x2, $y2);
            my $d3 = $cross->($x1, $y1, $x2, $y2, $x3, $y3);
            my $d4 = $cross->($x1, $y1, $x2, $y2, $x4, $y4);

            $count++ if ((($d1 > 0 && $d2 < 0) || ($d1 < 0 && $d2 > 0)) &&
                         (($d3 > 0 && $d4 < 0) || ($d3 < 0 && $d4 > 0)));

        }

    }

    return($count);

}

sub _autoRotate {

    my ($self, $result) = @_;

    my ($best, $bestAngle) = (undef, 0);

    for my $step (0 .. 179) {

        my $a = $step * Core::Mathematics::pi / 180;
        my ($cosA, $sinA) = (cos($a), sin($a));
        my ($minX, $maxX, $minY, $maxY);

        foreach my $c (@{$result->{coords}}) {

            my $x = $c->{x} * $cosA - $c->{y} * $sinA;
            my $y = $c->{x} * $sinA + $c->{y} * $cosA;
            $minX = $x if (!defined $minX || $x < $minX);
            $maxX = $x if (!defined $maxX || $x > $maxX);
            $minY = $y if (!defined $minY || $y < $minY);
            $maxY = $y if (!defined $maxY || $y > $maxY);

        }

        my $score = ($maxX - $minX) > ($maxY - $minY) ? $maxX - $minX : $maxY - $minY;

        if (!defined $best || $score < $best) {

            $best = $score;
            $bestAngle = $a;

        }

    }

    my ($cosA, $sinA) = (cos($bestAngle), sin($bestAngle));

    foreach my $key (qw(coords centers)) {

        foreach my $c (@{$result->{$key}}) {

            my ($x, $y) = ($c->{x}, $c->{y});
            $c->{x} = $x * $cosA - $y * $sinA;
            $c->{y} = $x * $sinA + $y * $cosA;

        }

    }

    return($result);

}

sub _layout {

    my $self = shift;

    my $n = length($self->{structure});
    my @pairs = (-1) x $n;

    my @allPairs = listpairs($self->{structure});
    my (@nested, @pk);

    foreach my $pair (@allPairs) {

        if (substr($self->{structure}, $pair->[0], 1) eq "(") { push(@nested, $pair); }
        else { push(@pk, $pair); }

    }

    foreach my $pair (@nested) {

        $pairs[$pair->[0]] = $pair->[1];
        $pairs[$pair->[1]] = $pair->[0];

    }

    $self->{_pairs} = \@nested;
    $self->{_pkpairs} = \@pk;

    my $result;

    if ($self->{layout} eq "radiate") {

        $result = drawRadiate(\@pairs, $n);
        $self->{_layout} = "radiate";

    }
    elsif ($self->{layout} eq "naview") {

        $result = $self->_autoRotate(drawNAView(\@pairs, $n));
        $self->{_layout} = "naview";

    }
    else {

        if ($n > $self->{maxAutoLen}) {

            $result = $self->_autoRotate(drawNAView(\@pairs, $n));
            $self->{_layout} = "naview";

        }
        else {

            my $rad = drawRadiate(\@pairs, $n);
            my $nav = drawNAView(\@pairs, $n);
            my $sRad = $self->_scoreOverlaps($rad->{coords});
            my $sNav = $self->_scoreOverlaps($nav->{coords});

            if ($sNav + $self->{tolerance} * 4 < $sRad) {

                $result = $self->_autoRotate($nav);
                $self->{_layout} = "naview";

            }
            else {

                $result = $rad;
                $self->{_layout} = "radiate";

            }

        }

    }

    $self->{_coords} = $result->{coords};

    return($result);

}

sub layout { return($_[0]->{_layout}); }

sub plot {

    my $self = shift;

    $self->_layout();

    my $n = length($self->{structure});
    my $r = $self->{baseRadius};
    my $coords = $self->{_coords};

    my ($minX, $maxX, $minY, $maxY);

    foreach my $c (@{$coords}) {

        $minX = $c->{x} if (!defined $minX || $c->{x} < $minX);
        $maxX = $c->{x} if (!defined $maxX || $c->{x} > $maxX);
        $minY = $c->{y} if (!defined $minY || $c->{y} < $minY);
        $maxY = $c->{y} if (!defined $maxY || $c->{y} > $maxY);

    }

    my $pad = $self->{padding} + $r + ($self->{plotIndices} ? 26 : 0);
    my ($legendW, $legendH) = (0, 0);

    if ($self->{plotLegend} && @{$self->{_legendKeys}}) {

        my $ls = $self->{legendScale};

        $legendW = LEGEND_MARGIN * $ls + ($self->_legendMetrics())[2];
        $legendH = $self->{colorScale} eq "gradient" ? 70 * $ls
                                                     : (@{$self->{_legendKeys}} + 1) * (LEGEND_SWATCH + LEGEND_GAP) * $ls + 30 * $ls;

    }

    # Rounded up to whole units: a fractional canvas is rounded inconsistently
    # by different tools, and the extra fraction of a unit cannot clip anything
    my $width = ceil($maxX - $minX + 2 * $pad + $legendW);
    my $contentH = $maxY - $minY + 2 * $pad;
    my $height = ceil($contentH > $legendH + 2 * $pad ? $contentH : $legendH + 2 * $pad);
    my ($offX, $offY) = ($pad - $minX, $pad - $minY);
    my $xml = Data::XML->new( heading => 0,
                              indent => 0 );

    # The viewBox keeps the drawing's own coordinate system while width and
    # height set the size it is rendered at, so scale changes the output size
    # without touching the layout
    $xml->opentag("svg", { xmlns         => "http://www.w3.org/2000/svg",
                           version       => "1.1",
                           width         => sprintf("%g", $width * $self->{scale}),
                           height        => sprintf("%g", $height * $self->{scale}),
                           viewBox       => "0 0 " . $width . " " . $height });

    my @px = map { sprintf("%.3f", $_->{x} + $offX) } @{$coords};
    my @py = map { sprintf("%.3f", $_->{y} + $offY) } @{$coords};
    my $clear = $self->{plotCircles} ? $r : ($self->{plotBases} ? $r * 0.7 : 0);

    $xml->opentag("g", { "stroke" => "#1f2328", "stroke-width" => BACKBONE_WIDTH, "stroke-linecap" => "round", fill => "none" });

    for my $i (0 .. $n - 2) {

        my $len = sqrt(($px[$i + 1] - $px[$i]) ** 2 + ($py[$i + 1] - $py[$i]) ** 2) || 1;
        my $shrink = $clear * 1.1 / $len;
        $shrink = 0.45 if ($shrink > 0.45);

        $xml->emptytag("line", { x1 => sprintf("%.3f", $px[$i] + ($px[$i + 1] - $px[$i]) * $shrink),
                                 y1 => sprintf("%.3f", $py[$i] + ($py[$i + 1] - $py[$i]) * $shrink),
                                 x2 => sprintf("%.3f", $px[$i + 1] - ($px[$i + 1] - $px[$i]) * $shrink),
                                 y2 => sprintf("%.3f", $py[$i + 1] - ($py[$i + 1] - $py[$i]) * $shrink) });

    }

    $xml->closelasttag();

    if ($self->{plotPairs}) {

        $xml->opentag("g", { "stroke" => "#1f2328", "stroke-width" => BOND_WIDTH, "stroke-linecap" => "round", fill => "none" });

        foreach my $pair (@{$self->{_pairs}}) {

            my ($i, $j) = @{$pair};
            my ($b1, $b2) = defined $self->{sequence} ? (substr($self->{sequence}, $i, 1), substr($self->{sequence}, $j, 1)) : ();
            my ($dx, $dy) = ($px[$j] - $px[$i], $py[$j] - $py[$i]);
            my $len = sqrt($dx * $dx + $dy * $dy) || 1;
            my $shrink = $clear * 1.3 / $len;
            my ($x1, $y1) = ($px[$i] + $dx * $shrink, $py[$i] + $dy * $shrink);
            my ($x2, $y2) = ($px[$j] - $dx * $shrink, $py[$j] - $dy * $shrink);
            my ($mx, $my) = (($px[$i] + $px[$j]) / 2, ($py[$i] + $py[$j]) / 2);

            if (defined $self->{sequence}) {

                my $isGC = (($b1 eq "G" && $b2 eq "C") || ($b1 eq "C" && $b2 eq "G"));
                my $isGU = (($b1 eq "G" && $b2 eq "U") || ($b1 eq "U" && $b2 eq "G"));

                if (!rnapair($b1, $b2)) { $self->_bondDot($xml, $mx, $my); }
                elsif ($isGC) {

                    my ($nx, $ny) = (-$dy / $len, $dx / $len);

                    foreach my $sign (1, -1) {

                        $xml->emptytag("line", { x1 => sprintf("%.3f", $x1 + $sign * $nx * BP_OFFSET),
                                                 y1 => sprintf("%.3f", $y1 + $sign * $ny * BP_OFFSET),
                                                 x2 => sprintf("%.3f", $x2 + $sign * $nx * BP_OFFSET),
                                                 y2 => sprintf("%.3f", $y2 + $sign * $ny * BP_OFFSET) });

                    }

                }
                else {

                    $xml->emptytag("line", { x1 => sprintf("%.3f", $x1), 
                                             y1 => sprintf("%.3f", $y1),
                                             x2 => sprintf("%.3f", $x2), 
                                             y2 => sprintf("%.3f", $y2) });

                    $self->_bondDot($xml, $mx, $my) if ($isGU);

                }

            }
            else {

                $xml->emptytag("line", { x1 => sprintf("%.3f", $x1), 
                                         y1 => sprintf("%.3f", $y1),
                                         x2 => sprintf("%.3f", $x2), 
                                         y2 => sprintf("%.3f", $y2) });

            }

        }

        $xml->closelasttag();

        if (@{$self->{_pkpairs}}) {

            $xml->opentag("g", { "stroke"           => "#1f2328", 
                                 "stroke-width"     => BACKBONE_WIDTH,
                                 "stroke-linecap"   => "round", 
                                 "stroke-dasharray" => "5 3", 
                                 fill               => "none" });

            foreach my $pair (@{$self->{_pkpairs}}) {

                my ($i, $j) = @{$pair};
                my $len = sqrt(($px[$j] - $px[$i]) ** 2 + ($py[$j] - $py[$i]) ** 2) || 1;
                my $shrink = $clear * 1.3 / $len;

                $xml->emptytag("line", { x1 => sprintf("%.3f", $px[$i] + ($px[$j] - $px[$i]) * $shrink),
                                         y1 => sprintf("%.3f", $py[$i] + ($py[$j] - $py[$i]) * $shrink),
                                         x2 => sprintf("%.3f", $px[$j] - ($px[$j] - $px[$i]) * $shrink),
                                         y2 => sprintf("%.3f", $py[$j] - ($py[$j] - $py[$i]) * $shrink) });

            }

            $xml->closelasttag();

        }

    }

    if ($self->{plotIndices}) {

        $xml->opentag("g", { "font-family" => "monospace, Courier New, Courier, Liberation Mono", 
                             "font-size"   => 12,
                             fill          => "#656d76", 
                             "text-anchor" => "middle" });

        for my $i (0 .. $n - 1) {

            next if (($i + 1) % $self->{indicesStep} && $i != 0 && $i != $n - 1);

            my ($cx, $cy) = (($minX + $maxX) / 2 + $offX, ($minY + $maxY) / 2 + $offY);
            my ($dx, $dy) = ($px[$i] - $cx, $py[$i] - $cy);
            my $d = sqrt($dx * $dx + $dy * $dy) || 1;

            $xml->tagline("text", $i + 1, { x  => sprintf("%.3f", $px[$i] + $dx / $d * 24),
                                            y  => sprintf("%.3f", $py[$i] + $dy / $d * 24),
                                            dy => "0.35em" });

        }

        $xml->closelasttag();

    }

    if ($self->{plotBases} || $self->{plotCircles}) {

        $xml->opentag("g");

        for my $i (0 .. $n - 1) {

            my $fill = $self->_valueToColor($self->{values}->[$i]);

            $xml->emptytag("circle", { cx             => $px[$i], 
                                       cy             => $py[$i], 
                                       r              => $r,
                                       fill           => $fill, 
                                       stroke         => "#1f2328",
                                       "stroke-width" => BASE_STROKE_WIDTH }) if ($self->{plotCircles});

            next if (!$self->{plotBases});

            my $textColor = $self->{plotCircles} ? _contrastTextColor($fill) : $fill;
            my $fontSize = $r * BASE_FONT_SIZE;

            $xml->tagline("text", defined $self->{sequence} ? substr($self->{sequence}, $i, 1) : "",
                          { x             => $px[$i], 
                            y             => $py[$i],
                            dy            => sprintf("%.3f", $fontSize * BASE_FONT_BASELINE),
                            "text-anchor" => "middle",
                            "font-family" => "monospace, Courier New, Courier, Liberation Mono",
                            "font-weight" => "bold", 
                            "font-size"   => sprintf("%.2f", $fontSize),
                             fill         => $textColor });

        }

        $xml->closelasttag();

    }

    $self->_legend($xml, $width - $legendW + LEGEND_MARGIN * $self->{legendScale}, $pad) if ($self->{plotLegend} && @{$self->{_legendKeys}});

    $xml->closealltags();

    my $io = Data::IO::XML->new(file      => $self->{file},
                                mode      => "w",
                                overwrite => $self->{overwrite});
    $io->write($xml);
    $io->close();

    return(1);

}

sub _bondDot {

    my ($self, $xml, $x, $y) = @_;

    $xml->emptytag("circle", { cx     => sprintf("%.3f", $x), 
                               cy     => sprintf("%.3f", $y),
                               r      => BOND_DOT_RADIUS, 
                               fill   => "#1f2328", 
                               stroke => "none" });

}

sub _hasMissing {

    my $self = shift;

    for my $i (0 .. length($self->{structure}) - 1) {

        my $v = $self->{values}->[$i];

        return(1) if (!defined $v ||
                      ($self->{colorScale} eq "discrete" && !exists $self->{legend}->{$v}) ||
                      ($self->{colorScale} eq "gradient" && !isnumeric($v)));

    }

    return(0);

}

sub _legendMetrics {

    my $self = shift;

    my $ls = $self->{legendScale};
    my $longest = 0;

    foreach my $key (@{$self->{_legendKeys}}, ($self->_hasMissing() ? "No data" : ())) { $longest = length($key) if (length($key) > $longest); }

    my $bodyW = $self->{colorScale} eq "gradient" ? LEGEND_BAR_WIDTH * $ls
                                                  : LEGEND_SWATCH * $ls + LEGEND_PAD * $ls + $longest * LEGEND_LABEL_SIZE * $ls * LEGEND_CHAR_WIDTH;
    my $titleW = defined $self->{legendTitle} ? length($self->{legendTitle}) * LEGEND_TITLE_SIZE * $ls * LEGEND_TITLE_CHAR_WIDTH : 0;

    return($bodyW, $titleW, $bodyW > $titleW ? $bodyW : $titleW);

}

sub _legend {

    my ($self, $xml, $x, $y) = @_;

    my @keys = @{$self->{_legendKeys}};
    my $ls = $self->{legendScale};
    my ($w, $h) = (LEGEND_BAR_WIDTH * $ls, LEGEND_SWATCH * $ls);
    my ($titleSize, $labelSize) = (LEGEND_TITLE_SIZE * $ls, LEGEND_LABEL_SIZE * $ls);
    my ($gap, $pad) = (LEGEND_GAP * $ls, LEGEND_PAD * $ls);
    my ($bodyW, $titleW, $blockW) = $self->_legendMetrics();
    my $cx = $x + $blockW / 2;

    $x += ($blockW - $bodyW) / 2;

    $xml->opentag("g");
    $xml->tagline("text", $self->{legendTitle},
                  { x             => sprintf("%.3f", $cx), 
                    y             => sprintf("%.3f", $y - 8 * $ls),
                    "text-anchor" => "middle", 
                    "font-family" => "Helvetica, Arial, sans-serif",
                    "font-size"   => sprintf("%.2f", $titleSize), 
                    "font-weight" => "bold", 
                    fill          => "#1f2328" })
        if (defined $self->{legendTitle});

    if ($self->{colorScale} eq "gradient") {

        my $steps = 60;
        my ($lo, $hi) = ($keys[0], $keys[-1]);

        for my $s (0 .. $steps - 1) {

            my $v = @keys > 1 ? $lo + ($hi - $lo) * $s / ($steps - 1) : $lo;

            $xml->emptytag("rect", { x      => sprintf("%.3f", $x + $w * $s / $steps),
                                     y      => $y, 
                                     width  => sprintf("%.3f", $w / $steps + 0.5),
                                     height => $h, 
                                     fill   => $self->_valueToColor($v), 
                                     stroke => "none" });

        }

        $xml->emptytag("rect", { x      => $x, 
                                 y      => $y, width => sprintf("%.3f", $w), 
                                 height => sprintf("%.3f", $h),
                                 fill   => "none", 
                                 stroke => "#1f2328", "stroke-width" => $ls });

        foreach my $label ([$x, $lo, "start"], [$x + $w, $hi, "end"]) {

            $xml->tagline("text", $label->[1], { x             => sprintf("%.3f", $label->[0]),
                                                 y             => sprintf("%.3f", $y + $h + $labelSize + 2 * $ls),
                                                 "font-family" => "monospace, Courier New, Courier, Liberation Mono",
                                                 "font-size"   => sprintf("%.2f", $labelSize),
                                                 "text-anchor" => $label->[2], fill => "#656d76" });

        }

    }
    else {

        for my $i (0 .. $#keys) {

            my $yy = $y + $i * ($h + $gap);

            $xml->emptytag("rect", { x     => $x, 
                                     y     => sprintf("%.3f", $yy),
                                     width => sprintf("%.3f", $h), height => sprintf("%.3f", $h),
                                     fill  => $self->{legend}->{$keys[$i]}, stroke => "#1f2328", "stroke-width" => $ls });
            $xml->tagline("text", $keys[$i], { x             => sprintf("%.3f", $x + $h + $pad),
                                               y             => sprintf("%.3f", $yy + $h - 3 * $ls),
                                               "font-family" => "monospace, Courier New, Courier, Liberation Mono",
                                               "font-size"   => sprintf("%.2f", $labelSize), fill => "#656d76" });

        }

    }

    if ($self->_hasMissing()) {

        my $yy = $y + ($self->{colorScale} eq "gradient" ? $h + 22 * $ls : @keys * ($h + $gap) + $gap);

        $xml->emptytag("rect", { x     => $x, 
                                 y     => sprintf("%.3f", $yy),
                                 width => sprintf("%.3f", $h), height => sprintf("%.3f", $h),
                                 fill  => $self->{missingColor}, stroke => "#1f2328", "stroke-width" => $ls });
        $xml->tagline("text", "No data", { x             => sprintf("%.3f", $x + $h + $pad),
                                           y             => sprintf("%.3f", $yy + $h - 3 * $ls),
                                           "font-family" => "monospace, Courier New, Courier, Liberation Mono",
                                           "font-size"   => sprintf("%.2f", $labelSize), fill => "#656d76" });

    }

    $xml->closelasttag();

}

1;