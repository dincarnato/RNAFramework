package Graphics::Image;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;
use Interface::Math::R;

use base qw(Interface::Math::R);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ file        => undef,
                   width       => "NA",
                   height      => "NA",
                   format      => "pdf",
                   units       => "in",
                   dpi         => 300, }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->SUPER::_validate();

    $self->throw("Width must be a positive INT > 0") if ($self->{width} <= 0 && $self->{width} ne "NA");
    $self->throw("Height must be a positive INT > 0") if ($self->{height} <= 0 && $self->{height} ne "NA");
    $self->throw("DPI must be a positive INT > 0, or one of the following: \"retina\", \"print\", or \"screen\"") if ($self->{dpi} <= 0 && $self->{dpi} !~ /^(?:retina|print|screen)$/);
    $self->throw("Invalid image format \"" . $self->{format} . "\"") if ($self->{format} !~ /^(?:eps|ps|tex|pdf|jpeg|tiff|png|bmp|svg)$/);
    $self->throw("Invalid units \"" . $self->{units} . "\"") if (defined $self->{units} && $self->{units} !~ m/^(?:in|cm|mm|px)$/);

    $self->start();

    foreach my $library (qw(ggplot2 patchwork RColorBrewer)) {

        my $eval = do {
            
            local $@;
            eval {$self->run("library($library)"); };
            $@;

        };

        $self->throw("Missing $library R package") if ($eval =~ m/Error in library\($library\) : there is no package/);

    }

    my $format = $self->{format};
    $self->{file} .= "." . $format if ($self->{file} !~ /\.$format$/);

}

sub file {

    my $self = shift;
    my $file = shift;

    $self->{file} = $file if (defined $file);

    return($self->{file});

}

sub width {

    my $self = shift;
    my $width = shift;

    if ($width) {

        $self->throw("Invalid width value: $width") if (!ispositive($width));

        $self->{width} = $width;

    }

    return($self->{width})

}

sub height {

    my $self = shift;
    my $height = shift;

    if ($height) {

        $self->throw("Invalid height value: $height") if (!ispositive($height));

        $self->{height} = $height;

    }

    return($self->{height})

}

sub plot {

    my $self = shift;
    my $rows = shift;
    my $sizes = shift || {};

    $self->throw("No output file specified") if (!defined $self->{file});
    $self->throw("Nothing to plot") if (!@$rows);

    my ($Rcode, $stdout, @plotLayout);
    $sizes = checkparameters({ widths  => [],
                               heights => [] }, $sizes);

    for (qw(widths heights)) { 

        if (@{$sizes->{$_}}) {

            $self->throw(ucfirst($_) . " must be positive") if (!ispositive(@{$sizes->{$_}}));
            push(@plotLayout, "$_=c(" . join(",", @{$sizes->{$_}}) . ")");

        }
        
    }

    for my $i (0 .. $#{$rows}) { 
        
        my @obj = ref($rows->[$i]) eq "ARRAY" ? @{$rows->[$i]} : $rows->[$i];

        for my $j (0 .. $#obj) { $self->throw("Object $i-$j is not a valid Graphics::Chart object") if (defined $obj[$j] && !$obj[$j]->isa("Graphics::Chart")); }

        $rows->[$i] = \@obj;
        
    }

    foreach my $row (@$rows) {

        for (@$row) {

            if (defined $_) {

                $self->run($_->Rcode());
                $_ = "plot_" . $_->id();

            }
            else { $_ = "plot_spacer()"; }

        }

    }

    $Rcode = "(" . join(") / (", map { join(" + ", @$_) } @$rows) . ")";
    $Rcode .= " + plot_layout(" . join(", ", @plotLayout) . ")" if (@plotLayout);
    $self->run("image<-$Rcode");
    $stdout = $self->run("ggsave('" . $self->{file} . "', plot=image, dpi=" . $self->{dpi} . ", units='" . $self->{units} . "'" .
                         ", width=" . $self->{width} . ", height=" . $self->{height} . ", device='" . $self->{format} . "', useDingbats=FALSE)");

    return($stdout !~ /Error/ && $stdout =~ /Saving \d+ x \d+ .+? image/ ? 1 : undef);

}

1;
