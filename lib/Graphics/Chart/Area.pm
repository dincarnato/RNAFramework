package Graphics::Chart::Area;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;

use base qw(Graphics::Chart);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ lineColor     => "black",
                   lineThickness => 0.5,
                   lineType      => "solid",
                   _paletteType  => "fill" }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->SUPER::_validate();

    $self->throw("lineThickness must be positive") if (!ispositive($self->{lineThickness}));
    $self->throw("Accepted lineType values are: \"" . join("\", \"", qw(twodash dotdash longdash dashed
                                                                        dotted solid blank)) . "\"") if ($self->{lineType} !~ m/^(?:(?:two|dot|long)dash|dashed|dotted|solid|blank)$/);

}

sub _generateRcode {

    my $self = shift;

    my ($id, $dataLabels, $Rcode);
    $id = $self->{id};
    $dataLabels = $self->_collapseDataLabels();
    $Rcode = "df_$id<-data.frame(data=c(" . join(",", @{$self->{data}}) . ")";
    $Rcode .= ", $_=c(" . $dataLabels->{$_} . ")" for (keys %$dataLabels);
    $Rcode .= ");\n";

    $Rcode .= "df_$id\$" . $self->{x} . "<-as.numeric(df_$id\$" . $self->{x} . ");\n" if (defined $self->{x});

    # In case of overlapping areas, this ensures that they are plotted in such a way that the one with the highest median value
    # will be plotted first (back) and the one with the lowest will be plotted last (top)
    if ($self->{groupMethod} eq "dodge" && grep { isnumeric($_) } @{$self->{data}}) {

        $Rcode .= "group_median_$id<-aggregate(data ~ " . $self->{fill} . ", data=df_$id, FUN=median);\n" .
                  "group_median_$id<-group_median_$id\[order(-group_median_$id\$data), ];\n" .
                  "df_$id\$" . $self->{fill} . "<- factor(df_$id\$" . $self->{fill} . ", levels = group_median_$id\$" . $self->{fill} . ");\n";

    }

    $Rcode .= "plot_$id<-ggplot(df_$id, aes(x=" . 
              (defined $self->{x} ? $self->{x} : "seq(from=1, to=nrow(df_$id))") . 
              ", y=data, fill=" . $self->{fill} . "))";
    $Rcode .= " + geom_area(stat='identity', position=" . ($self->{groupMethod} eq "dodge" ? "position_dodge(width=0)" : "'stack'") . ", color='" . $self->{lineColor} . "', lwd=" . $self->{lineThickness} . ", linetype='" . $self->{lineType} . "')";

    $Rcode .= " + " . $self->SUPER::_generateRcode();

    return($Rcode);

}

1;
