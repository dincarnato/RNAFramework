package Graphics::Chart::Boxplot;

use strict;
use Core::Mathematics qw(:all);
use Core::Statistics;
use Core::Utils;

use base qw(Graphics::Chart);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ layout         => "vertical",
                   lineThickness   => 0.5,
                   plotOutliers    => 1,
                   outlierSize     => 1,
                   notch           => 0,
                   plotDataPoints  => 0,
                   dataPointSize   => 1,
                   colorDataPoints => 1,
                   _paletteType    => "fill" }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->SUPER::_validate();

    $self->throw("lineThickness must be positive") if (!ispositive($self->{lineThickness}));
    $self->throw("Accepted layout values are: \"vertical\" and \"horizontal\"") if ($self->{layout} !~ m/^(?:horizontal|vertical)$/);

    for (qw(plotOutliers notch plotDataPoints colorDataPoints)) { $self->throw($_ . " must be BOOL") if (!isbool($self->{$_})); }

}

sub _generateRcode {

    my $self = shift;

    my ($id, $dataLabels, $Rcode);
    $id = $self->{id};
    $dataLabels = $self->_collapseDataLabels();
    $Rcode = "df_$id<-data.frame(data=c(" . join(",", @{$self->{data}}) . ")";
    $Rcode .= ", $_=c(" . $dataLabels->{$_} . ")" for (keys %$dataLabels);
    $Rcode .= ");\n";
   
    $Rcode .= "df_$id\$$_<-factor(df_$id\$$_, levels=c('" . join("', '", @{$self->{dataLabelSort}->{$_}}) . "'));\n" for (keys %{$self->{dataLabelSort}});

    $Rcode .= "plot_$id<-ggplot(df_$id, aes(x=" . $self->{x} . ", y=data, " .
              "fill=" . $self->{fill} . ")) + geom_boxplot(notch=" . ($self->{notch} ? "TRUE" : "FALSE") . ", " . 
              ($self->{plotOutliers} ? "outlier.size=" . $self->{outlierSize} : "outlier.shape=NA") . ", position=position_dodge(0.85))";

    if ($self->{plotDataPoints}) {

        $Rcode .= " + geom_point(aes(group=" . $self->{fill} . "), shape=21, position=position_dodge(0.85), size=" . $self->{dataPointSize};
        $Rcode .= ", fill='black'" if (!$self->{colorDataPoints});
        $Rcode .= ")";

    }

    $self->_calcPlotLimits() if (!$self->{plotOutliers});

    $Rcode .= " + " . $self->SUPER::_generateRcode();

    return($Rcode);

}

sub _calcPlotLimits {

    my $self = shift;

    my ($min, $max);

    foreach my $value (uniq(@{$self->{dataLabels}->{$self->{fill}}})) {

        my ($tmpMin, $tmpMax, $iqr, $q1,
            $q3, @data);
        @data = grep { isnumeric($_) } map { $self->{data}->[$_] } grep { $self->{dataLabels}->{$self->{fill}}->[$_] eq $value } 0 .. $#{$self->{data}};

        next if (!@data);

        $q1 = percentile(\@data, 0.25);
        $q3 = percentile(\@data, 0.75);
        $iqr = $q3 - $q1;
        $tmpMin = max(min(@data), $q1 - 1.5 * $iqr);
        $tmpMax = min(max(@data), $q3 + 1.5 * $iqr);

        $min = $tmpMin if (!defined $min || $min > $tmpMin);
        $max = $tmpMax if (!defined $max || $max < $tmpMax);

    }

    $self->{yLimit} = [$min, $max] if (defined $min && defined $max);

}

1;
