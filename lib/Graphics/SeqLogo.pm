package Graphics::SeqLogo;

use strict;
use POSIX qw(ceil);

use Core::Mathematics;
use Core::Utils;
use Data::IO::XML;
use Data::Sequence::Utils;
use Data::XML;

use base qw(Core::Base);

# Glyph outlines, taken from Liberation Mono Bold with fontTools and stored as
# [ xMin, yMin, xMax, yMax, path ] in font units, with y pointing up.
#
# Outlines rather than <text>, because a <text> glyph is sized by whatever font
# the renderer happens to resolve: ink height varies by 10% and ink width by
# nearly 40% between common fonts, so the letters stop filling their slots.
my (%glyph, %schemes);
%glyph = (
           "A" => [ 0, 0, 1229, 1349, "M1229 0H935L843 330H387L295 0H0L443 1349H787ZM615 1167Q607 1125 585.5 1041.5Q564 958 449 552H781Q664 964 643.5 1045.0Q623 1126 615 1167Z" ],
           "B" => [ 137, 0, 1186, 1349, "M1186 385Q1186 204 1062.0 102.0Q938 0 719 0H137V1349H662Q880 1349 992.5 1261.5Q1105 1174 1105 1010Q1105 895 1039.0 816.5Q973 738 836 709Q1007 691 1096.5 607.0Q1186 523 1186 385ZM808 970Q808 1130 641 1130H432V811H643Q808 811 808 970ZM889 410Q889 498 836.0 545.5Q783 593 682 593H432V219H689Q889 219 889 410Z" ],
           "C" => [ 80, -20, 1172, 1370, "M380 681Q380 456 450.0 334.0Q520 212 659 212Q821 212 899 456L1172 404Q1039 -20 656 -20Q375 -20 227.5 158.5Q80 337 80 681Q80 1370 648 1370Q834 1370 959.5 1272.0Q1085 1174 1144 981L872 915Q843 1021 785.0 1079.5Q727 1138 652 1138Q380 1138 380 681Z" ],
           "D" => [ 135, 0, 1149, 1349, "M1149 685Q1149 355 995.0 177.5Q841 0 556 0H135V1349H496Q824 1349 986.5 1184.5Q1149 1020 1149 685ZM852 685Q852 912 766.5 1016.5Q681 1121 491 1121H430V228H532Q852 228 852 685Z" ],
           "E" => [ 137, 0, 1146, 1349, "M137 0V1349H1105V1121H432V797H1044V569H432V228H1146V0Z" ],
           "F" => [ 167, 0, 1106, 1349, "M462 1121V737H1083V509H462V0H167V1349H1106V1121Z" ],
           "G" => [ 80, -20, 1128, 1370, "M1128 185Q885 -20 635 -20Q374 -20 227.0 163.5Q80 347 80 681Q80 1370 638 1370Q818 1370 932.0 1277.0Q1046 1184 1100 995L826 941Q773 1138 641 1138Q506 1138 442.5 1030.0Q379 922 379 681Q379 458 446.0 337.0Q513 216 650 216Q703 216 759.5 236.0Q816 256 858 290V525H584V743H1128Z" ],
           "H" => [ 138, 0, 1091, 1349, "M796 0V574H433V0H138V1349H433V818H796V1349H1091V0Z" ],
           "I" => [ 157, 0, 1073, 1349, "M157 1349H1073V1121H762V228H1073V0H157V228H468V1121H157Z" ],
           "K" => [ 136, 0, 1229, 1349, "M881 0 558 557 431 415V0H136V1349H431V750L867 1349H1210L750 770L1229 0Z" ],
           "L" => [ 211, 0, 1122, 1349, "M211 0V1349H506V228H1122V0Z" ],
           "M" => [ 99, 0, 1130, 1349, "M908 0V868Q908 973 924 1169Q865 879 849 828L725 360H507L381 828Q352 936 305 1169L312 1069Q319 964 319 868V0H99V1349H446L581 850Q596 803 619 619Q639 774 659 849L795 1349H1130V0Z" ],
           "N" => [ 135, 0, 1094, 1349, "M748 0 364 1010Q392 758 392 656V0H135V1349H472L865 312Q837 547 837 677V1349H1094V0Z" ],
           "P" => [ 136, 0, 1142, 1349, "M1142 923Q1142 789 1081.0 687.5Q1020 586 904.5 531.0Q789 476 628 476H431V0H136V1349H616Q873 1349 1007.5 1240.5Q1142 1132 1142 923ZM845 918Q845 1027 779.5 1073.5Q714 1120 583 1120H431V703H591Q723 703 784.0 757.5Q845 812 845 918Z" ],
           "Q" => [ 72, -403, 1168, 1370, "M1157 679Q1157 391 1060.5 221.0Q964 51 779 0Q814 -97 877.0 -141.5Q940 -186 1045 -186Q1090 -186 1168 -173V-375Q1042 -403 926 -403Q762 -403 655.0 -310.5Q548 -218 482 -7Q282 35 177.0 207.0Q72 379 72 679Q72 1024 212.5 1197.0Q353 1370 615 1370Q877 1370 1017.0 1197.0Q1157 1024 1157 679ZM858 679Q858 1138 615 1138Q371 1138 371 679Q371 449 432.5 330.5Q494 212 615 212Q736 212 797.0 330.5Q858 449 858 679Z" ],
           "R" => [ 137, 0, 1227, 1349, "M895 0 605 515H432V0H137V1349H631Q895 1349 1026.0 1246.0Q1157 1143 1157 949Q1157 812 1083.0 716.0Q1009 620 878 581L1227 0ZM860 937Q860 1031 798.0 1075.5Q736 1120 600 1120H432V744H608Q860 744 860 937Z" ],
           "S" => [ 38, -20, 1165, 1370, "M1165 391Q1165 199 1018.5 89.5Q872 -20 611 -20Q376 -20 228.0 79.0Q80 178 38 367L323 404Q346 310 419.0 255.5Q492 201 619 201Q751 201 814.5 243.0Q878 285 878 374Q878 440 822.0 485.5Q766 531 659 557Q444 609 355.5 647.5Q267 686 214.0 734.0Q161 782 132.5 846.5Q104 911 104 991Q104 1166 244.5 1268.0Q385 1370 615 1370Q839 1370 965.0 1281.5Q1091 1193 1128 1007L842 978Q798 1161 609 1161Q503 1161 447.0 1121.5Q391 1082 391 1008Q391 959 418.0 926.5Q445 894 491.5 871.5Q538 849 681 812Q869 766 970.0 709.5Q1071 653 1118.0 573.0Q1165 493 1165 391Z" ],
           "T" => [ 61, 0, 1168, 1349, "M762 1121V0H467V1121H61V1349H1168V1121Z" ],
           "V" => [ 3, 0, 1227, 1349, "M766 0H467L3 1349H311L544 574Q571 486 618 308L639 394L690 574L922 1349H1227Z" ],
           "W" => [ 0, 0, 1228, 1349, "M1018 0H770L706 267Q656 456 616 636L581 489L537 312L459 0H211L0 1349H259L348 654Q360 558 364 388L379 464L419 632L518 971H713L812 632Q825 587 834.5 543.5Q844 500 867 388L869 415Q875 576 885 654L969 1349H1228Z" ],
           "X" => [ 0, 0, 1229, 1349, "M919 0 616 493 312 0H0L459 711L41 1349H353L616 919L878 1349H1188L760 711L1229 0Z" ],
           "Y" => [ 3, 0, 1225, 1349, "M761 556V0H467V556L3 1349H312L612 783L916 1349H1225Z" ],
           "Z" => [ 87, 0, 1138, 1349, "M1138 0H87V209L758 1118H163V1349H1097V1144L426 231H1138Z" ],
           "U" => [ 129, -20, 1100, 1349, "M599 -20Q353 -20 241.0 114.0Q129 248 129 528V1349H424V531Q424 356 464.5 283.5Q505 211 607 211Q711 211 758.0 288.0Q805 365 805 541V1349H1100V543Q1100 257 976.5 118.5Q853 -20 599 -20Z" ] );
# These copy exactly the color schemes used by WebLogo
%schemes = ( nucleotide     => { G => "#ffa500", T => "#ff0000", U => "#ff0000",
                                 C => "#0000ff", A => "#008000" },
             basepairing    => { T => "#ff8c00", A => "#ff8c00", U => "#ff8c00",
                                 G => "#0000ff", C => "#0000ff" },
             chemistry      => { G => "#008000", S => "#008000", T => "#008000", Y => "#008000", 
                                 C => "#008000",
                                 N => "#800080", Q => "#800080",
                                 K => "#0000ff", R => "#0000ff", H => "#0000ff",
                                 D => "#ff0000", E => "#ff0000",
                                 P => "#000000", A => "#000000", W => "#000000", F => "#000000",
                                 L => "#000000", I => "#000000", M => "#000000", V => "#000000" },
             hydrophobicity => { R => "#0000ff", K => "#0000ff", D => "#0000ff", E => "#0000ff",
                                 N => "#0000ff", Q => "#0000ff",
                                 S => "#008000", G => "#008000", H => "#008000", T => "#008000",
                                 A => "#008000", P => "#008000",
                                 Y => "#000000", V => "#000000", M => "#000000", C => "#000000",
                                 L => "#000000", F => "#000000", I => "#000000", W => "#000000" },
             mono           => {} );

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ sequences     => [],
                   counts        => undef,
                   matrix        => undef,
                   alphabet      => undef,
                   file          => undef,
                   units         => "bits",
                   scheme        => "nucleotide",
                   colors        => {},
                   defaultColor  => "#1f2328",
                   background    => "#ffffff",
                   title         => undef,
                   start         => 1,
                   plotIndices   => 1,
                   indicesStep   => 1,
                   plotAxis      => 1,
                   plotErrorBars => 0,
                   stackWidth    => 26,
                   axisGap       => 6,
                   letterGap     => 1.5,
                   tickGap       => 8,
                   labelGap      => 2,
                   titleGap      => 10,
                   titleSize     => 15,
                   stackHeight   => 120,
                   padding       => 20,
                   scale         => 1,
                   overwrite     => 0,
                   _counts       => [],
                   _alphabet     => [],
                   _heights      => [],
                   _stacks       => [],
                   _yMax         => 0,
                   _error        => [] }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("No output file specified") if (!defined $self->{file});

    $self->{file} .= ".svg" if (lc(substr($self->{file}, -4)) ne ".svg");
    my $inputs = (defined $self->{matrix} ? 1 : 0) + (defined $self->{counts} ? 1 : 0) + (@{$self->{sequences}} ? 1 : 0);

    $self->throw("Multiple inputs provided") if ($inputs > 1);
    $self->throw("TRANSFAC matrix file \"" . $self->{matrix} . "\" does not exist") if (defined $self->{matrix} && !-e $self->{matrix});
    $self->throw("Units must be \"bits\", \"nats\" or \"probability\"") if ($self->{units} !~ m/^(?:bits|nats|probability)$/);
    $self->throw("Unknown color scheme \"" . $self->{scheme} . "\"") if (!exists $schemes{$self->{scheme}});
    $self->throw("Colors must be provided as a HASH reference") if (ref($self->{colors}) ne "HASH");
    $self->throw("Background must be a #RRGGBB hex string") if (defined $self->{background} && $self->{background} !~ m/^#[0-9a-fA-F]{6}$/);
    $self->throw("Stack width must be a positive number") if (!ispositive($self->{stackWidth}) || !$self->{stackWidth});
    $self->throw("Stack height must be a positive number") if (!ispositive($self->{stackHeight}) || !$self->{stackHeight});
    $self->throw("Padding must be positive") if (!ispositive($self->{padding}));
    $self->throw("Axis gap must be positive") if (!ispositive($self->{axisGap}));
    $self->throw("Letter gap must be positive") if (!ispositive($self->{letterGap}));
    $self->throw("Tick gap must be positive") if (!ispositive($self->{tickGap}));
    $self->throw("Label gap must be positive") if (!ispositive($self->{labelGap}));
    $self->throw("Title gap must be positive") if (!ispositive($self->{titleGap}));
    $self->throw("Title size must be a positive number") if (!ispositive($self->{titleSize}) || !$self->{titleSize});
    $self->throw("Scale must be a positive number") if (!ispositive($self->{scale}) || !$self->{scale});
    $self->throw("Letter gap cannot exceed the stack width") if ($self->{letterGap} >= $self->{stackWidth});
    $self->throw("Start position must be an integer") if (!isint($self->{start}));
    $self->throw("Indices step must be a positive integer") if (!isint($self->{indicesStep}) || !ispositive($self->{indicesStep}) || !$self->{indicesStep});

    for (qw(plotIndices plotAxis plotErrorBars overwrite)) { $self->throw("$_ must be BOOL") if (!isbool($self->{$_})); }

    $self->throw("File \"" . $self->{file} . "\" already exists") if (-e $self->{file} && !$self->{overwrite});

    my $colors = $self->{colors};

    foreach my $symbol (keys %{$colors}) {

        $self->throw("Color for \"" . $symbol . "\" must be a #RRGGBB hex string") if ($colors->{$symbol} !~ m/^#[0-9a-fA-F]{6}$/);

    }

    $self->_countSymbols();

}

sub _countSymbols {

    my $self = shift;

    my (@counts, %seen);

    if (defined $self->{matrix}) {

        my ($alphabet, $id, @rows);
        ($alphabet, $id, @rows) = $self->_readTransfac();

        $self->{_alphabet} = $alphabet;
        @counts = @rows;

    }
    elsif (defined $self->{counts}) {

        $self->throw("Counts must be provided as an ARRAY reference") if (ref($self->{counts}) ne "ARRAY");
        $self->throw("An alphabet must be provided along with counts") if (ref($self->{alphabet}) ne "ARRAY" || !@{$self->{alphabet}});

        $self->{_alphabet} = [ map { uc($_) } @{$self->{alphabet}} ];

        foreach my $position (@{$self->{counts}}) {

            $self->throw("Each position of the count matrix must be an ARRAY reference") if (ref($position) ne "ARRAY");
            $self->throw("Each position must hold one count per symbol of the alphabet") if (@{$position} != @{$self->{_alphabet}});
            $self->throw("Counts must be positive numbers") if (!ispositive(@{$position}));

            push(@counts, [ @{$position} ]);

        }

    }
    else {

        my ($length, @sequences);
        @sequences = @{$self->{sequences}};

        $self->throw("No sequences provided") if (!@sequences);

        $length = length($sequences[0]);

        foreach my $sequence (@sequences) {

            $self->throw("Sequences must all be the same length") if (length($sequence) != $length);

        }

        $self->throw("Sequences are empty") if (!$length);

        foreach my $sequence (@sequences) {

            $seen{$_} = 1 for (grep { $_ ne "-" && $_ ne "." } split(//, uc($sequence)));

        }

        $self->throw("Sequences contain no usable symbols") if (!keys %seen);

        $self->{_alphabet} = [ sort keys %seen ];

        for my $i (0 .. $length - 1) {

            my (%column, @column);

            foreach my $sequence (@sequences) { $column{uc(substr($sequence, $i, 1))}++; }

            @column = map { $column{$_} || 0 } @{$self->{_alphabet}};

            push(@counts, \@column);

        }

    }

    $self->throw("Count matrix is empty") if (!@counts);

    $self->{_counts} = \@counts;

    $self->_stackHeights();

}

sub _readTransfac {

    my $self = shift;

    my ($id, @alphabet, @rows, $lastPosition);
    $lastPosition = 0;

    open(my $fh, "<", $self->{matrix}) or $self->throw("Unable to read TRANSFAC matrix (" . $! . ")");
    while(<$fh>) {

        chomp();

        s/\r$//;

        next if (!m/\S/ || m/^(?:XX|\/\/)\s*$/);

        my @fields = split(/\s+/, $_);

        if ($fields[0] eq "ID") { $id = $fields[1]; }
        elsif ($fields[0] =~ m/^P0$/i) { @alphabet = map { uc($_) } @fields[1 .. $#fields]; }
        elsif ($fields[0] =~ m/^\d+$/) {

            $self->throw("Counts found before the P0 line in \"" . $self->{matrix} . "\"") if (!@alphabet);

            my @counts = @fields[1 .. scalar(@alphabet)];

            $self->throw("Position " . $fields[0] . " holds " . scalar(grep { defined } @counts) .
                         " counts, expected " . scalar(@alphabet)) if (grep { !defined } @counts);
            $self->throw("Counts at position " . $fields[0] . " must be positive numbers") if (!ispositive(@counts));
            $self->throw("Positions in \"" . $self->{matrix} . "\" are not consecutive (" .
                         $fields[0] . " follows " . $lastPosition . ")") if ($fields[0] != $lastPosition + 1);

            $lastPosition = $fields[0];

            push(@rows, \@counts);

        }

    }
    CORE::close($fh);

    $self->throw("No P0 line found in \"" . $self->{matrix} . "\"") if (!@alphabet);
    $self->throw("No counts found in \"" . $self->{matrix} . "\"") if (!@rows);

    return(\@alphabet, $id, @rows);

}

sub _stackHeights {

    my $self = shift;

    my ($alphabet, $units, @heights, @stacks, @errors);
    $alphabet = $self->{_alphabet};
    $units = $self->{units};

    foreach my $counts (@{$self->{_counts}}) {

        my ($total, $entropy, $information, $correction, @frequencies, @symbols);
        $total = 0;
        $total += $_ for (@{$counts});

        if (!$total) {

            push(@heights, []);
            push(@stacks, 0);
            push(@errors, 0);

            next;

        }

        @frequencies = map { $_ / $total } @{$counts};

        if ($units eq "probability") { $information = 1; }
        else {

            $entropy = 0;

            foreach my $frequency (@frequencies) { $entropy -= $frequency * log($frequency) if ($frequency > 0); }

            $information = log(scalar(@{$alphabet})) - $entropy;
            $information = 0 if ($information < 0);
            $information /= log(2) if ($units eq "bits");

        }

        $correction = (scalar(@{$alphabet}) - 1) / (2 * $total);
        $correction /= log(2) if ($units eq "bits");
        $correction = 0 if ($units eq "probability");

        for my $i (0 .. $#{$alphabet}) {

            next if (!$frequencies[$i]);

            push(@symbols, [ $alphabet->[$i], $frequencies[$i] * $information ]);

        }

        @symbols = sort { $a->[1] <=> $b->[1] } @symbols;

        push(@heights, \@symbols);
        push(@stacks, $information);
        push(@errors, $correction);

    }

    $self->{_heights} = \@heights;
    $self->{_stacks} = \@stacks;
    $self->{_error} = \@errors;
    $self->{_yMax} = $units eq "probability" ? 1 : log(scalar(@{$self->{_alphabet}})) / ($units eq "bits" ? log(2) : 1);

}

sub _symbolColor {

    my ($self, $symbol) = @_;

    return($self->{colors}->{$symbol}) if (exists $self->{colors}->{$symbol});
    return($schemes{$self->{scheme}}->{$symbol}) if (exists $schemes{$self->{scheme}}->{$symbol});

    return($self->{defaultColor});

}

sub _ticks {

    my $self = shift;

    my ($max, $step, @ticks);
    $max = $self->{_yMax};
    $step = $max > 3 ? 1 : ($max > 1 ? 0.5 : 0.25);

    for (my $tick = 0; $tick <= $max + 1e-9; $tick += $step) { push(@ticks, $tick); }

    return(@ticks);

}

sub plot {

    my $self = shift;

    my ($io, $xml, $width, $height, $left, $bottom, $gap,
        $plotWidth, $plotHeight, $stackX, $tickWidth, $titleBand, $overshoot, @ticks);

    @ticks = $self->_ticks();
    $tickWidth = 0;

    foreach my $tick (@ticks) {

        my $label = $tick == int($tick) ? int($tick) : sprintf("%.2g", $tick);

        $tickWidth = length($label) if (length($label) > $tickWidth);

    }

    $tickWidth *= 6.2;
    $left = $self->{plotAxis} ? $self->{tickGap} + $tickWidth + $self->{labelGap} + 14 : 0;
    $bottom = $self->{plotIndices} ? 24 : 0;
    $gap = $self->{plotAxis} ? $self->{axisGap} : 0;
    $plotWidth = @{$self->{_counts}} * $self->{stackWidth} + $gap;
    $plotHeight = $self->{stackHeight};
    $width = $plotWidth + $left + $self->{padding} * 2;
    $overshoot = 0;

    if ($self->{plotErrorBars}) {

        for my $i (0 .. $#{$self->{_stacks}}) {

            my $top = $self->{_stacks}->[$i] + $self->{_error}->[$i];

            $overshoot = $top - $self->{_yMax} if ($top - $self->{_yMax} > $overshoot);

        }

        $overshoot = ($overshoot / $self->{_yMax}) * $self->{stackHeight};

    }

    $titleBand = defined $self->{title} ? $self->{titleSize} + $self->{titleGap} + $overshoot : $overshoot;
    $height = $plotHeight + $bottom + $self->{padding} * 2 + $titleBand;

    $io = Data::IO::XML->new( file      => $self->{file},
                              mode      => "w",
                              overwrite => $self->{overwrite},
                              header    => 0 );
    $xml = Data::XML->new( heading => 0, 
                           indent  => 0 );
    $width = ceil($width);
    $height = ceil($height);

    # The viewBox keeps the drawing's own coordinates while width and height set
    # the size it renders at, so scale changes the output size without touching
    # the layout
    $xml->opentag("svg", { xmlns   => "http://www.w3.org/2000/svg",
                           width   => sprintf("%g", $width * $self->{scale}),
                           height  => sprintf("%g", $height * $self->{scale}),
                           viewBox => "0 0 $width $height" });

    $xml->emptytag("rect", { x      => 0, 
                             y      => 0, 
                             width  => $width, 
                             height => $height,
                             fill   => $self->{background} }) if ($self->{background});

    my ($originX, $originY);
    $originX = $self->{padding} + $left;
    $stackX = $originX + $gap;
    $originY = $self->{padding} + $titleBand + $plotHeight;

    if (defined $self->{title}) {

        $xml->tagline("text", $self->{title},
                      { x             => sprintf("%.2f", $stackX + ($plotWidth - $gap) / 2),
                        y             => sprintf("%.2f", $self->{padding} + $self->{titleSize}),
                        "text-anchor" => "middle", 
                        "font-family" => "Helvetica, Arial, sans-serif",
                        "font-size"   => $self->{titleSize}, 
                        "font-weight" => "bold", 
                        fill          => "#1f2328" });

    }

    if ($self->{plotAxis}) {

        $xml->opentag("g", { stroke         => "#1f2328", 
                             "stroke-width" => 1, 
                             fill           => "none" });
        $xml->emptytag("line", { x1 => $originX, 
                                 y1 => sprintf("%.2f", $originY - $plotHeight),
                                 x2 => $originX, 
                                 y2 => $originY });

        foreach my $tick (@ticks) {

            my $y = $originY - ($tick / $self->{_yMax}) * $plotHeight;

            $xml->emptytag("line", { x1 => $originX - 5, 
                                     y1 => sprintf("%.2f", $y),
                                     x2 => $originX, 
                                     y2 => sprintf("%.2f", $y) });

        }

        $xml->closelasttag();

        $xml->opentag("g", { "font-family" => "Helvetica, Arial, sans-serif", 
                             "font-size"   => 11,
                             fill          => "#656d76", 
                             "text-anchor" => "end" });

        foreach my $tick (@ticks) {

            my $y = $originY - ($tick / $self->{_yMax}) * $plotHeight;

            $xml->tagline("text", $tick == int($tick) ? int($tick) : sprintf("%.2g", $tick),
                          { x => sprintf("%.2f", $originX - $self->{tickGap}), 
                            y => sprintf("%.2f", $y + 3.7) });

        }

        $xml->closelasttag();

        my $label = $self->{units} eq "probability" ? "probability" : $self->{units};
        $xml->tagline("text", $label,
                      { x             => 0, 
                        y             => 0, 
                        "text-anchor" => "middle",
                        "font-family" => "Helvetica, Arial, sans-serif", 
                        "font-size"   => 12, 
                        fill          => "#1f2328",
                        transform     => "translate(" . sprintf("%.2f", $originX - $self->{tickGap} - $self->{labelGap} - $tickWidth) . "," .
                                         sprintf("%.2f", $originY - $plotHeight / 2) . ") rotate(-90)" });

    }

    for my $i (0 .. $#{$self->{_heights}}) {

        my ($x, $y);
        $x = $stackX + $i * $self->{stackWidth};
        $y = $originY;

        foreach my $symbol (@{$self->{_heights}->[$i]}) {

            my ($letter, $letterHeight, $pixels, $outline,
                $inkWidth);
            ($letter, $letterHeight) = @{$symbol};
            $pixels = ($letterHeight / $self->{_yMax}) * $plotHeight;

            next if ($pixels < 0.15);

            $inkWidth = $self->{stackWidth} - $self->{letterGap};
            $outline = $glyph{$letter};

            if (defined $outline) {

                my ($x0, $y0, $x1, $y1, $path,
                    $scaleX, $scaleY);
                ($x0, $y0, $x1, $y1, $path) = @{$outline};

                # The outline is scaled so its bounding box exactly fills the
                # slice, and flipped, since font outlines have y pointing up
                $scaleX = $inkWidth / ($x1 - $x0);
                $scaleY = $pixels / ($y1 - $y0);

                $xml->emptytag("path", { d         => $path,
                                         fill      => $self->_symbolColor($letter),
                                         transform => "translate(" . sprintf("%.3f", $x + $self->{letterGap} / 2 - $x0 * $scaleX) . "," .
                                                      sprintf("%.3f", $y + $y0 * $scaleY) . ") " .
                                                      "scale(" . sprintf("%.6f", $scaleX) . "," . sprintf("%.6f", -$scaleY) . ")" });

            }
            else {

                # No outline for this symbol, so it falls back to text: sized by
                # the renderer's font, but better than drawing nothing
                $xml->tagline("text", $letter,
                              { x             => sprintf("%.3f", $x + $self->{stackWidth} / 2),
                                y             => sprintf("%.3f", $y),
                                "text-anchor" => "middle",
                                "font-family" => "Courier New, Courier, Liberation Mono, monospace",
                                "font-weight" => "bold",
                                "font-size"   => sprintf("%.3f", $pixels * 1.4),
                                fill          => $self->_symbolColor($letter) });

            }

            $y -= $pixels;

        }

        if ($self->{plotErrorBars} && $self->{_error}->[$i]) {

            my ($top, $bar, $cx);
            $cx = $x + $self->{stackWidth} / 2;
            $top = $originY - ($self->{_stacks}->[$i] / $self->{_yMax}) * $plotHeight;
            $bar = ($self->{_error}->[$i] / $self->{_yMax}) * $plotHeight;

            $xml->opentag("g", { stroke         => "#1f2328", 
                                 "stroke-width" => 1, 
                                 fill           => "none" });
            $xml->emptytag("line", { x1 => sprintf("%.2f", $cx), 
                                     y1 => sprintf("%.2f", $top - $bar),
                                     x2 => sprintf("%.2f", $cx), 
                                     y2 => sprintf("%.2f", $top + $bar) });
            $xml->emptytag("line", { x1 => sprintf("%.2f", $cx - 3), 
                                     y1 => sprintf("%.2f", $top - $bar),
                                     x2 => sprintf("%.2f", $cx + 3), 
                                     y2 => sprintf("%.2f", $top - $bar) });
            $xml->emptytag("line", { x1 => sprintf("%.2f", $cx - 3), 
                                     y1 => sprintf("%.2f", $top + $bar),
                                     x2 => sprintf("%.2f", $cx + 3), 
                                     y2 => sprintf("%.2f", $top + $bar) });
            $xml->closelasttag();

        }

    }

    if ($self->{plotIndices}) {

        $xml->opentag("g", { "font-family" => "Helvetica, Arial, sans-serif", 
                             "font-size"   => 11,
                             fill          => "#656d76", 
                             "text-anchor" => "middle" });

        for my $i (0 .. $#{$self->{_counts}}) {

            my $position = $self->{start} + $i;

            next if (($i % $self->{indicesStep}) && $i != $#{$self->{_counts}});

            $xml->tagline("text", $position,
                          { x => sprintf("%.2f", $stackX + ($i + 0.5) * $self->{stackWidth}),
                            y => sprintf("%.2f", $originY + 15) });

        }

        $xml->closelasttag();

    }

    $xml->closelasttag();

    $io->write($xml);
    $io->close();

    return(1);

}

sub information {

    my $self = shift;

    return(wantarray() ? @{$self->{_stacks}} : $self->{_stacks});

}

sub alphabet {

    my $self = shift;

    return(wantarray() ? @{$self->{_alphabet}} : $self->{_alphabet});

}

1;
