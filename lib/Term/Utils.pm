package Term::Utils;

use strict;
use Core::Mathematics;
use Core::Utils;

use base qw(Exporter);

our @EXPORT = qw(termsize formatlongtext);

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
    elsif (which("stty") &&
           `stty -a` =~ m/rows (\d+); columns (\d+)/) {
        
        $lines = $1;
        $columns = $2;
        
    }
    else {
        
        eval { require Term::ReadKey; };
        
        if (@_) { Core::Utils::throw("Please install Term::ReadKey module to allow terminal size determination"); }
        
        ($columns, $lines) = GetTerminalSize();
        
    }
    
    return($lines, $columns);

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

1;