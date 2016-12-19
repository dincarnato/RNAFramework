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
    
    my ($columns, $row, $remove, $formatted,
        @words);
    
    $columns = (termsize())[1];
    
    $row = " " x $indent if ($indent);

    $indent = " " x $indent;
    @words = split(/\s+/, $text);

    while (@words) {
        
        my $word = shift(@words);
        
        if (length($indent . $row . $word) > $columns ||
            $word =~ m/\.$/) {
            
            if (length($word) > $columns) { $row .= $word; }
            else {
                
                if ($word =~ m/\.$/) { $row .= $word . "\n" . $indent; }
                else { unshift(@words, "\n" . $indent . $word); }
            
            }
            
            $formatted .= $row;
            undef($row);
            
        }
        else { $row .= $word . " "; }
        
    }

    $formatted .= $row;
    
    return($formatted);

}

1;