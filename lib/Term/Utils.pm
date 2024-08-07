package Term::Utils;

use strict;
use Core::Mathematics;
use Core::Utils;

use base qw(Exporter);

our @EXPORT = qw(termsize getCursorPos setCursorPos formatlongtext);

sub termsize {
    
    my ($lines, $columns);
    
    if (defined $ENV{LINES} &&
        defined $ENV{COLUMNS}) {
        
        $lines = $ENV{LINES};
        $columns = $ENV{COLUMNS};
        
    }
    elsif (which("tput")) {
        
        $lines = `tput lines`;
        $columns = `tput cols`;
        
        chomp($lines, $columns);
        
    }
    elsif (my $stty = which("stty")) {

        if (`$stty -a` =~ m/rows (\d+); columns (\d+)/) {
        
            $lines = $1;
            $columns = $2;

       }
        
    }
    else {
        
        eval { require Term::ReadKey; };
        
        if (@_) { Core::Utils::throw("Please install Term::ReadKey module to allow terminal size determination"); }
        
        ($columns, $lines) = GetTerminalSize();
        
    }
    
    return($lines, $columns);

}

sub getCursorPos {

    my ($x, $y);

    if (my $stty = which("stty")) {

        `stty raw -echo`;
        print "\e[6n";
        ($x, $y) = _getc();
        `stty -raw echo`;

    }
    else{
        
        eval { require Term::ReadKey; };
        
        if (@_) { Core::Utils::throw("Please install Term::ReadKey module to allow terminal size determination"); }
        
        Term::ReadKey::ReadMode(4);
        print "\e[6n";
        ($x, $y) = _getc();
        Term::ReadKey::ReadMode(0);
        
    }

    return($x, $y);

}

sub formatlongtext {
 
    my $text = shift;
    my $indent = shift || 0;
    
    Core::Utils::throw("Indentation value must be a positive integer") if (!ispositive($indent) ||
                                                                           !isint($indent));
    
    my ($columns, $remove, $formatted, $row,
        @words);
    $columns = (termsize())[1];
    $indent = " " x $indent;
    @words = split(/\s+/, $text);
    
    while (@words) {
        
        my $word = shift(@words);
        
        if (length($indent . $row . $word) > $columns) {
            
            if (length($indent . $row . $word) > $columns) {
                
                my $diff = $columns - length($indent . $row);
                
                if ($diff > 0) {
                
                    my $part = substr($word, 0, $diff);
                    $row .= $part . "\n" . $indent;
                    $word =~ s/^$part//;
                    
                }
                else { $row .= $indent; }
                
                unshift(@words, $word) if ($word);
                
            }
            else {
                
                unshift(@words, $word);

                $row .= "\n" . $indent;
            
            }
            
            $formatted .= $row;
            undef($row);
            
            next;
            
        }
        else {
            
            $row .= $word;
            $row .= " " if (length($indent . $row) + 1 < $columns);
            
        }
        
    }
        
    $formatted .= $row;
    
    return($formatted);

}

sub setCursorPos {

    my ($row, $col) = @_;

    print "\033[$row;$col\H";

}

sub _getc {

    my ($getCharFunc, $c);
    $getCharFunc = sub { exists $INC{"Term/ReadKey.pm"} ? Term::ReadKey::ReadKey(0) : getc() };
    $c = $getCharFunc->();

    if ($c eq "\e") {
        
        my $c = $getCharFunc->();
        
        if ($c eq "[") {

            my $c = $getCharFunc->();
            
            if ($c =~ /\A\d/) {

                my $c1 = $getCharFunc->();

                if ($c1 ne "~") {

                    my ($col, $row);
                    $col = 0;
                    $row = 0 + $c;

                    while (1) {

                        last if ($c1 eq ";");

                        $row = 10 * $row + $c1;
                        $c1 = $getCharFunc->();

                    }

                    while (1) {
                        
                        $c1 = $getCharFunc->();
                        
                        last if ($c1 eq "R");

                        $col = 10 * $col + $c1;
                    
                    }
                    
                    return($row, $col);

                }

            }

        }

    }

}

1;