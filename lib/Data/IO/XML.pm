package Data::IO::XML;

use strict;
use Core::Mathematics;
use Core::Utils;
use Data::XML::Tree;

use base qw(Data::IO);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ header  => 1,
                   binmode => ":encoding(utf-8)" }, \%parameters);

    $self->_validate();
    $self->_openfh();

    if ($self->{mode} ne "r") {

        my $fh = $self->{_fh};
        print $fh "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";

    }

    return($self);

}

sub _validate {

    my $self = shift;

    $self->SUPER::_validate();
    $self->throw("Header parameter must be BOOL") if (!isbool($self->{header}));

}

sub read {

    my $self = shift;

    $self->throw("Filehandle is not in read mode") if ($self->{mode} ne "r");

    my ($fh, $justClosed, $lastValue, $tree,
        @openTags);
    $fh = $self->{_fh};
    $tree = {};

    if (eof($fh)) {

        $self->reset() if ($self->{autoreset});

        return;

    }

    local $/ = "\n";

    while (my $line = <$fh>) {

        chomp($line);

        $line = rmEndSpaces($line); 

        my @chunks;

        # This is the time consuming part (split is very slow),
        # so let's avoid using it and going into the for cycle
        # unless necessary
        if ($line =~ m/</) { @chunks = split("<", $line); }
        else {

            $lastValue .= $line;

            next;

        }

        unshift(@chunks, $lastValue);
        undef($lastValue);

        for (my $i = 0; $i < @chunks; $i++) {

            my $chunk = $chunks[$i];
            $chunk = "<" . $chunk if ($chunk =~ m/>/);

            next if ($chunk =~ m/^\s*$/);

            if ($chunk =~ m/>([^<>]+)$/) {

                my $value = quotemeta($1);
                $chunk =~ s/$value$//;

                if ($line !~ m/<\//) { $lastValue .= $value; }
                else {

                    $chunks[$i] = $value;
                    $i--;

                }

            }

            if ($chunk =~ m/^<([^\/][^>]*)>/) {

                my ($tag, $att, $attribs, $lastRef);
                $tag = $1;
                $line = rmEndSpaces($tag);

                next if ($tag =~ /^[!\?]/);

                ($att) = $tag =~ /^\S+\s+?(.+)?$/;
                $tag =~ s/\s+?$att$//;
                $attribs = {};

                while ($att =~ /^\s*([^=]+="[^"]+")/) {

                    my ($attribute, @attribute);
                    $attribute = $1;
                    @attribute = split("=", $attribute);
                    $attribute[1] =~ s/"//g;
                    $attribs->{$attribute[0]} = $attribute[1];
                    $att =~ s/^\s*$attribute//;

                }

                if ($tag eq $justClosed) {

                    my $ref = $tree;

                    for (@openTags) {

                        $ref = $ref->[-1] if (ref($ref) eq "ARRAY");
                        $ref = $ref->{$_};

                    }

                    $ref = $ref->[-1] if (ref($ref) eq "ARRAY");
                    $ref->{$tag} = [ clonehashref($ref->{$tag}) ] if (ref($ref->{$tag}) ne "ARRAY");

                }

                $lastRef = $tree;
                push(@openTags, $tag);

                for (0 .. $#openTags) {

                    my $openTag = $openTags[$_];

                    if ($_ == $#openTags) {

                        $lastRef = $lastRef->[-1] if (ref($lastRef) eq "ARRAY");

                        if (exists $lastRef->{$openTag}) { push(@{$lastRef->{$openTag}}, { xml_attribs => $attribs}); }
                        else { $lastRef->{$openTag} = { xml_attribs => $attribs }; }

                    }
                    else {

                        $lastRef = $lastRef->[-1] if (ref($lastRef) eq "ARRAY");
                        $lastRef = $lastRef->{$openTag};

                    }

                }

            }
            elsif ($chunk =~ m/^<\/([^>]+)>/) {

                my ($closedTag, $lastTag);
                $closedTag = $1;
                $closedTag =~ s/^\s+|\s+$//g;
                $lastTag = pop(@openTags);

                $self->throw("Unexpected tag closure (expected: $lastTag, observed: $closedTag)") if ($closedTag ne $lastTag);

                $justClosed = $lastTag;

            }
            else {

                my $lastRef = $tree;
                $chunk =~ s/\s+/ /g;

                for (0 .. $#openTags) {

                    my $openTag = $openTags[$_];

                    if ($_ == $#openTags) {

                        $lastRef = $lastRef->[-1] if (ref($lastRef) eq "ARRAY");
                        $lastRef = $lastRef->{$openTag};
                        $lastRef = $lastRef->[-1] if (ref($lastRef) eq "ARRAY");

                        $lastRef->{xml_value} .= $chunk;

                    }
                    else {

                        $lastRef = $lastRef->[-1] if (ref($lastRef) eq "ARRAY");
                        $lastRef = $lastRef->{$openTag};

                    }

                }

            }

        }

    }

    $self->throw("Truncated XML file") if (@openTags);
    $self->reset() if ($self->{autoreset});

    return(Data::XML::Tree->new(tree => $tree));

}

sub write {

    my $self = shift;
    my @entries = @_;

    $self->throw("Filehandle is not in write/append mode") if ($self->{mode} !~ m/^w\+?$/);

    my $fh = $self->{_fh};

    foreach my $entry (@entries) {

        if (ref($entry) ne "Data::XML") {

            $self->warn("Entry is not a Data::XML object");

            next;

        }
        else { $self->SUPER::write($entry->xml()); }

    }

}

1;
