package Graphics::Chart::Linedot;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;

use base qw(Graphics::Chart);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ plotLines       => 1,
                   plotDataPoints  => 1,
                   lineType        => undef,
                   dataPointShape  => undef,
                   stdev           => undef,
                   errorBarWidth   => 0.05,
                   lineWidth       => 0.25,
                   dataPointSize   => 2,
                   colorDataPoints => 1,
                   colorLines      => 1,
                   colorErrorBars  => 0,
                   _paletteType    => "colour" }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    for (qw(lineType dataPointShape stdev)) { $self->throw("Data label \"" . $self->{$_} . "\" does not exist") if (defined $self->{$_} && !exists $self->{dataLabels}->{$self->{$_}});}

    $self->throw("lineWidth must be a positive number") if (!ispositive($self->{lineWidth}));

    $self->SUPER::_validate();

}

sub _generateRcode {

    my $self = shift;

    my ($id, $dataLabels, $Rcode);
    $id = $self->{id};
    $dataLabels = $self->_collapseDataLabels();
    $Rcode = "df_$id<-data.frame(data=c(" . join(",", @{$self->{data}}) . ")";
    $Rcode .= ", $_=c(" . $dataLabels->{$_} . ")" for (keys %$dataLabels);
    $Rcode .= ");\n";

    $Rcode .= $self->_setDataTypes();

    $Rcode .= "plot_$id<-ggplot(df_$id, aes(x=" . 
              (defined $self->{x} ? $self->{x} : "rep(c(seq(from=1, to=nrow(df_$id))), " . $self->{_nFillValues} . ")") . 
              ", y=data, group=" . $self->{fill} . "))";

    $Rcode .= " + geom_errorbar(aes(ymin=data-as.numeric(" . $self->{stdev} . "), ymax=data+as.numeric(" . $self->{stdev} . ")" . 
              ($self->{colorErrorBars} ? ", colour=" . $self->{fill} . ")" : ")") .
              ", width=" . $self->{errorBarWidth} . ")" if ($self->{stdev});

    if ($self->{plotLines}) {

        my (@aes);
        push(@aes, "colour=" . $self->{fill}) if ($self->{colorLines});
        push(@aes, "linetype=" . $self->{lineType}) if ($self->{lineType});

        $Rcode .= " + geom_line(linewidth=" . $self->{lineWidth};
        $Rcode .= ", aes(" . join(", ", @aes) . ")" if (@aes);
        $Rcode .= ")";

    }

    if ($self->{plotDataPoints}) {

        my (@aes);
        push(@aes, "colour=" . $self->{fill}) if ($self->{colorDataPoints});
        push(@aes, "shape=" . $self->{dataPointShape}) if ($self->{dataPointShape});

        $Rcode .= " + geom_point(";
        $Rcode .= "aes(" . join(", ", @aes) . ")" if (@aes);
        $Rcode .= ", size=" . $self->{dataPointSize} . ")";

    }

    $Rcode .= " + " . $self->SUPER::_generateRcode();

    return($Rcode);

}

1;
