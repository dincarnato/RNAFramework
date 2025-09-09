package Graphics::Chart;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ id              => randalphanum(0x16),
                   x               => undef,
                   fill            => undef,
                   data            => [],
                   dataLabels      => {},
                   dataLabelSort   => {},
                   dataLabelType   => {},
                   groupMethod     => "dodge",
                   legendPos       => "right",
                   legendKeyWidth  => undef,
                   legendKeyHeight => undef,
                   legendSort      => [],
                   legendColors    => {},
                   colorScale      => "discrete",
                   colorPalette    => "YlGnBu",
                   invertPalette   => 0,
                   xLimit          => [],
                   yLimit          => [],
                   xBreaks         => {},
                   labelTextSize   => 9,
                   axisTitleSize   => 9,
                   legendTextSize  => 9,
                   legendTitleSize => 9,
                   xLabelAngle     => 0,
                   xTitle          => undef,
                   yTitle          => undef,
                   legendTitle     => undef,
                   grid            => 1,
                   xTicks          => 1,
                   yTicks          => 1,
                   xLabels         => 1,
                   yLabels         => 1,
                   legend          => 1,
                   background      => 1,
                   flipCoords      => 0,
                   yScale          => "natural",
                   _nFillValues    => 0 }, \%parameters);

    $self->throw("Cannot create a generic Graphics::Chart object") if ($class eq "Graphics::Chart");

    return($self);

}

sub _validate {

    my $self = shift;

    my $palettes = join("|", qw(Spectral Blues BuGn BuPu GnBu Greens Greys Oranges OrRd PuBu PuBuGn 
                                PuRd Purples RdPu Reds YlGn YlGnBu YlOrBr YlOrRd Accent Dark2 Paired 
                                Pastel1 Pastel2 Set1 Set2 Set3 BrBG PiYG PRGn PuOr RdBu RdGy RdYlBu
                                RdYlGn));

    $self->throw("Data ARRAY is empty") if (!@{$self->{data}});
    $self->throw("No data label defined for fill") if ($self->{legend} && !defined $self->{fill});
    $self->throw("Invalid colorScale value \"" . $self->{colorScale} . "\" (allowed: \"discrete\" and \"gradient\")") if ($self->{colorScale} !~ /^(?:discrete|gradient)$/);
    $self->throw("Invalid colorPalette value \"" . $self->{colorPalette} . "\"") if ($self->{colorPalette} !~ /^(?:$palettes)$/);
    $self->throw("Invalid Y-axis scale \"" . $self->{yScale} . "\"") if ($self->{yScale} !~ /^(?:natural|log(?:2|10)?)$/);

    for (qw(x fill)) { $self->throw("Data label \"" . $self->{$_} . "\" does not exist") if (defined $self->{$_} && !exists $self->{dataLabels}->{$self->{$_}} && $self->{$_} ne "data"); }

    for (qw(xLabelAngle legendKeyWidth legendKeyHeight)) { $self->throw("$_ must be positive") if (defined $self->{$_} && !ispositive($self->{$_})); }
    for (qw(xLimit yLimit)) {

        if (@{$self->{$_}}) {

            if (($_ eq "xLimit" && (!$self->{dataLabels} || !$self->{x})) || $_ eq "yLimit") {

                $self->throw($_ . " must contain 2 values [from, to]") if (@{$self->{$_}} != 2);
                $self->throw($_ . " values must be numeric") if (!isnumeric(@{$self->{$_}}));

                @{$self->{$_}} = sort {$a <=> $b} @{$self->{$_}};

            }
            elsif ($_ eq "xLimit" && $self->{dataLabels} && (($self->{x} eq "data" && !isnumeric(@{$self->{data}})) || 
                                                             ($self->{x} ne "data" && !isnumeric(@{$self->{dataLabels}->{$self->{x}}})))) {

                my %groups = map { $_ => 0 } ($self->{x} eq "data" ? @{$self->{data}} : @{$self->{dataLabels}->{$self->{x}}});

                for (@{$self->{xLimit}}) { $self->throw("xLimit value \"$_\" does not exist in group \"" . $self->{x} . "\"") if (!exists $groups{$_}); }

            }

        }

    }

    for (qw(grid xTicks yTicks xLabels invertPalette
            yLabels background legend flipCoords)) { $self->throw($_ . " must be BOOL") if (!isbool($self->{$_})); }

    $self->throw("Invalid legendPos value (supported: \"top\" and \"right\")") if ($self->{legendPos} !~ m/^(?:top|right)$/);

    if (keys %{$self->{dataLabels}}) {

        for (keys %{$self->{dataLabels}}) { 
            
            $self->throw("\"$_\" dataLabel is not an ARRAY reference") if (ref($self->{dataLabels}->{$_}) ne "ARRAY"); 
            $self->throw("Different number of elements for data and \"$_\" dataLabel ARRAYs") if (@{$self->{data}} != @{$self->{dataLabels}->{$_}}); 
            
        }

        for my $label (keys %{$self->{dataLabelSort}}) {

            $self->throw("Sort specified for unknown label \"$label\"") if (!exists $self->{dataLabels}->{$label});
            $self->throw("\"$label\" dataLabelSort is not an ARRAY reference") if (ref($self->{dataLabelSort}->{$label}) ne "ARRAY");

            my %values = map { $_ => 1 } uniq(@{$self->{dataLabels}->{$label}});

            for (my $i = 0; $i < @{$self->{dataLabelSort}->{$label}}; $i++) {

                if (!exists $values{$self->{dataLabelSort}->{$label}->[$i]}) {

                    splice(@{$self->{dataLabelSort}->{$label}}, $i, 1);
                    $i--;

                }

            }

        }

        for my $label (keys %{$self->{dataLabelType}}) {

            $self->throw("Type specified for unknown label \"$label\"") if (!exists $self->{dataLabels}->{$label} && $label ne "data");
            $self->throw("Suppoted \"$label\" dataLabelType are \"numeric\" and \"character\"") if ($self->{dataLabelType}->{$label} !~ /^(?:numeric|character)$/);

        }

        $self->throw("Supported groupMethod values are \"dodge\" and \"stack\"") if ($self->{groupMethod} !~ /^(?:dodge|stack)$/);

    }
    else { $self->throw("No data labels specified"); }

    if (@{$self->{legendSort}} || keys %{$self->{legendColors}}) {

        my %values = map { $_ => 1 } ($self->{fill} eq "data" ? uniq(@{$self->{data}}) : uniq(@{$self->{dataLabels}->{$self->{fill}}}));

        for (my $i = 0; $i < @{$self->{legendSort}}; $i++) {

            if (!exists $values{$self->{legendSort}->[$i]}) {

                splice(@{$self->{legendSort}}, $i, 1);
                $i--;

            }

        }

        for (keys %{$self->{legendColors}}) { delete($self->{legendColors}->{$_}) if (!exists $values{$_}); }

    }

    $self->{_nFillValues} = $self->{fill} eq "data" ? scalar(uniq(@{$self->{data}})) : scalar(uniq(@{$self->{dataLabels}->{$self->{fill}}}));

    if (keys %{$self->{legendColors}}) {

        my $nLegendColors = scalar(keys %{$self->{legendColors}});

       $self->throw("Number of possible values for label \"" . $self->{fill} . "\" (n=" . $self->{_nFillValues} . 
                    ") differs from number of provided legendColors (n=$nLegendColors)") if ($nLegendColors != $self->{_nFillValues});

    }

}

sub id { return($_[0]->{id}); }

sub Rcode { return($_[0]->_generateRcode()); }

sub _setDataTypes {

    my $self = shift;

    my ($Rcode);
    $Rcode .= "df_" . $self->{id} . "\$$_<-as." . $self->{dataLabelType}->{$_} . "(" . "df_" . $self->{id} . "\$$_);\n" for (keys %{$self->{dataLabelType}});

    return($Rcode);

}

sub _generateRcode {

    my $self = shift;

    my ($Rcode, @coordLims);

    if (keys %{$self->{legendColors}}) {

        $Rcode = "scale_" . $self->{_paletteType} . "_manual(values=c(" .
                 join(", ", map { "'$_' = '" . $self->{legendColors}->{$_} . "'" } keys %{$self->{legendColors}}) . ")";
        $Rcode .= ", limits=c('" . join("', '", @{$self->{legendSort}}) . "')" if (@{$self->{legendSort}});        
        $Rcode .= ") +";

    }
    else {

        my ($isFillNumeric);
        $isFillNumeric = 1 if (isnumeric(@{$self->{dataLabels}->{$self->{fill}}}));

        if ($self->{colorScale} eq "discrete" && $self->{_nFillValues} > 12) {

            $self->warn("colorScale was set to \"discrete\", but values for label \"" . $self->{fill} . "\" " . 
                        ($isFillNumeric ? "look continuous" : "exceed the number of colors in the palette.") . 
                        "\ncolorScale will be adjusted accordingly");

            $self->{colorScale} = "gradient" if ($isFillNumeric);

        }
        
        if ($isFillNumeric || $self->{_nFillValues} < 12) {

            $Rcode = ($self->{colorScale} eq "discrete" ? "scale_" . $self->{_paletteType} . "_brewer" : "scale_" . $self->{_paletteType} . "_distiller") . "(palette='" . $self->{colorPalette} . "'";
            $Rcode .= ", limits=c('" . join("', '", @{$self->{legendSort}}) . "')" if (@{$self->{legendSort}});
            $Rcode .= ", guide = 'colourbar', direction=" . ($self->{invertPalette} ? -1 : 1) . ")";

        }
        else { 
            
            my $palette = "colorRampPalette(brewer.pal(9, '" . $self->{colorPalette} . "')";
            $palette = "rev($palette)" if ($self->{invertPalette});
            $Rcode = "scale_" . $self->{_paletteType} . "_manual(values = $palette)(" . $self->{_nFillValues} . "))"; 
            
        }
           
        $Rcode .= " + ";

    }

    $Rcode .= "theme(";
    $Rcode .= "axis.text.x=" . ($self->{xLabels} ? "element_text(size=" . $self->{labelTextSize} . ", angle=" . $self->{xLabelAngle} . ", vjust=0.5" . ($self->{xLabelAngle} =~ /^90|180$/ ? ", hjust=1)" : ")") : "element_blank()");
    $Rcode .= ", axis.text.y=" . ($self->{yLabels} ? "element_text(size=" . $self->{labelTextSize} . ")" : "element_blank()");
    $Rcode .= ", axis.ticks.x=element_blank()" if (!$self->{xTicks});
    $Rcode .= ", axis.ticks.y=element_blank()" if (!$self->{yTicks});
    $Rcode .= ", panel.grid.major = element_blank(), panel.grid.minor = element_blank()" if (!$self->{grid});
    $Rcode .= ", panel.background = element_blank()" if (!$self->{background});

    if ($self->{legend}) {

        if ($self->{legendPos} eq "top") { $Rcode .= ", legend.direction='horizontal', legend.justification='right', legend.position='top'"; }
        else { $Rcode .= ", legend.position='right'"; }

        $Rcode .= ", legend.key.width=unit(" . $self->{legendKeyWidth} . ", 'pt')" if (defined $self->{legendKeyWidth});
        $Rcode .= ", legend.key.height=unit(" . $self->{legendKeyHeight} . ", 'pt')" if (defined $self->{legendKeyHeight});
        $Rcode .= ", legend.spacing.x=unit(" . ($self->{legendPos} eq "top" ? 0 : 3) . ", 'pt'), legend.text = element_text(margin=margin(" . 
                  ($self->{legendPos} eq "top" ? "5,0,0,0" : "0,0,0,5") . ", 'pt'), size=" . $self->{legendTextSize} . "), legend.key=element_blank(), legend.ticks=element_blank()";
        $Rcode .= ", legend.title=element_text(size=" . $self->{legendTitleSize} . ")" if ($self->{legendTitle});

    }
    else { $Rcode .= ", legend.position='none'"; }

    $Rcode .= ", axis.title.x=" . ($self->{xTitle} ? "element_text(size=" . $self->{axisTitleSize} . ", margin=margin(t=10))" : "element_blank()") .
              ", axis.title.y=" . ($self->{yTitle} ? "element_text(size=" . $self->{axisTitleSize} . ", margin=margin(r=10))" : "element_blank()") . 
              ", plot.margin=margin(10,0,0,0))"; # This adds a bit of margin to the top of the plot

    if ($self->{legend}) {

        $Rcode .= "+ guides(";
        $Rcode .= join(", ", map { "$_=guide_" . ($self->{colorScale} eq "discrete" ? "legend" : "colourbar") . "(label.position='" . ($self->{legendPos} eq "top" ? "bottom" : "right") . 
                                   "', title.position='top', title.hjust=0.5, title=" . ($self->{legendTitle} ? "'" . $self->{legendTitle} . "'" : "NULL") . ")" } (qw(colour shape fill)));
        $Rcode .= ")";

    }

    push(@coordLims, "xlim=c(" . join(", ", @{$self->{xLimit}}) . ")") if (@{$self->{xLimit}});
    push(@coordLims, "ylim=c(" . join(", ", @{$self->{yLimit}}) . ")") if (@{$self->{yLimit}});

    $Rcode .= " + coord_cartesian(" . join(", ", @coordLims) . ")" if (@coordLims);
    $Rcode .= " + xlab('" . $self->{xTitle} . "')" if (defined $self->{xTitle});
    $Rcode .= " + ylab('" . $self->{yTitle} . "')" if (defined $self->{yTitle});

    if (keys %{$self->{xBreaks}}) {

        my ($isNumeric, @breaks, @labels);
        $isNumeric = (defined $self->{x} && exists $self->{dataLabelType}->{$self->{x}} && $self->{dataLabelType}->{$self->{x}} eq "numeric") ||
                     !defined $self->{x} ? 1 : 0;
        @breaks = $isNumeric ? sort { $a <=> $b } keys %{$self->{xBreaks}} : sort keys %{$self->{xBreaks}};
        @labels = map { $self->{xBreaks}->{$_} } @breaks;

        $Rcode .= " + scale_x_continuous(breaks=c(" . ($isNumeric ? join(", ", @breaks) : "'" . join("', '", @breaks) . "'") . ")" .
                  ", labels=c('" . join("', '", @labels) . "'))";

    }

    $Rcode .= " + coord_flip()" if ($self->{flipCoords});
    $Rcode .= " + scale_y_continuous(trans='" . $self->{yScale} . "')" if (substr($self->{yScale}, 0, 3) eq "log");
    $Rcode .= ";\n";

    return($Rcode);

}

sub _collapseDataLabels {

    my $self = shift;

    my $collapsed = {};

    foreach my $label (keys %{$self->{dataLabels}}) {

        my ($values, $lastGroup, $reps, $isNumeric, @groups);
        $values = $self->{dataLabels}->{$label};
        $isNumeric = 1 if (isnumeric(@$values));

        for my $i (0 .. $#{$values}) {

            if (defined $lastGroup) {

                if ($values->[$i] eq $lastGroup) { 
                    
                    $reps++; 

                    next;

                }
                else { push(@groups, $reps == 1 ? ($isNumeric ? $lastGroup : "'$lastGroup'") : "rep(" . ($isNumeric ? $lastGroup : "'$lastGroup'") . ", $reps)"); }

            }

            $lastGroup = $values->[$i];
            $reps = 1;

        }

        push(@groups, $reps == 1 ? ($isNumeric ? $lastGroup : "'$lastGroup'") : "rep(" . ($isNumeric ? $lastGroup : "'$lastGroup'") . ", $reps)"); 

        $collapsed->{$label} = join(", ", @groups);

    }

    return($collapsed);

}

1;
