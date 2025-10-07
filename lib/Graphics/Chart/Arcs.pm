package Graphics::Chart::Arcs;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;

use base qw(Graphics::Chart);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ flip          => "up",
                   lineThickness => 0.5,
                   _paletteType  => "colour" }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->SUPER::_validate();

    for (@{$self->{data}}) {

        $self->throw("Data points must be ARRAY refs") if (ref($_) ne "ARRAY");
        $self->throw("Data points must contain 2 elements") if (@{$_} != 2);
        $self->throw("Data point elements must be positive INT") if (!ispositive(@{$_}) || !isint(@{$_}));

    }

    $self->throw("lineThickness must be positive") if (!ispositive($self->{lineThickness}));
    $self->throw("Accepted flip values are: \"up\" and \"down\"") if ($self->{flip} !~ m/^(?:up|down)$/);

}

sub _generateRcode {

    my $self = shift;

    my ($id, $dataLabels, $Rcode, @x1, @x2);
    $id = $self->{id};
    $dataLabels = $self->_collapseDataLabels();
    @x1 = map { $_->[0] } @{$self->{data}};
    @x2 = map { $_->[1] } @{$self->{data}};

    $Rcode = "df_$id<-data.frame(x1=c(" . join(",", @x1) . "), x2=c(" . join(",", @x2) . ")";
    $Rcode .= ", $_=c(" . $dataLabels->{$_} . ")" for (keys %$dataLabels);
    $Rcode .= ");\n";

    # Stole this very clever approach somewhere on StackOverflow
    $Rcode .= "arcFun <- function(x1Values, x2Values, fillValues, n=100, ylim=c(" . ($self->{flip} eq "down" ? "-0.5, 0" : "0, 0.5") . ")) {\n" .
              "  xdiff <- max(abs(x1Values - x2Values), na.rm = TRUE) / 2\n" .
              "  ydiff <- abs(diff(ylim))\n" .
              "  do.call('rbind', Map(function(x1, x2, g, " . $self->{fill} . ") {\n" .
              "    r <- (x1 - x2) / 2\n" .
              "    mid <- (x1 + x2) / 2\n" .
              "    theta <- seq(0, pi, length.out = n)\n" .
              "    x <- mid + r * cos(theta) + 1\n" .
              "    y <- r * ydiff / xdiff * " . ($self->{flip} eq "down" ? "sin(theta)" : "-sin(theta)") . "\n" .
              "    data.frame(x, y, g=g, " . $self->{fill} . "=" . $self->{fill} . ")\n" .
              "  }, x1Values, x2Values, seq_along(x1Values), fillValues))\n" .
              "}\n" .
              "arcs_$id<-arcFun(df_$id\$x1, df_$id\$x2, df_$id\$" . $self->{fill} . ")\n";

    $Rcode .= "plot_" . $id . "<-ggplot(arcs_$id) + geom_path(aes(x, y, group=g, color=" . $self->{fill} . "), linewidth=" . $self->{lineThickness} . ")" .
              " + coord_cartesian(ylim = c(" . ($self->{flip} eq "down" ? "-0.5, 0" : "0, 0.5") . "))";

    $Rcode .= " + " . $self->SUPER::_generateRcode();

    return($Rcode);

}

1;
