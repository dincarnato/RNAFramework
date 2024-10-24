package Net::DB::MySQL;

use strict;
use IO::Socket;
use Digest::SHA;

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ host            => undef,
                   port            => 3306,
                   user            => undef,
                   password        => undef,
                   database        => undef,
                   timeout         => 60,
                   _error          => undef,
                   _socket         => undef,
                   _protoVer       => undef,
                   _serverVer      => undef,
                   _threadId       => undef,
                   _salt           => undef,
                   _client         => undef,
                   _response       => undef,
                   _responsePos    => 0,
                   _responseColLen => 0,
                   _responseCols   => [] }, \%parameters);

    return($self);

}

sub connect {
    
    my $self = shift;

    my ($socket, $msg, $i, $length,
        $end, $loginMsg, $eval);

    $eval = do {

        local $@;

        $socket = IO::Socket::INET->new( PeerAddr => $self->{host},
                                         PeerPort => $self->{port},
                                         Proto    => "tcp",
                                         Timeout  => $self->{timeout} );

        $@;

    };

    if ($eval) {

        $self->{_error} = "Cannot connect to host ($eval)";

        return;

    }

    $socket->autoflush(1);
    $socket->recv($msg, 1460, 0);
    
    $i = 0;
    $length = ord(substr($msg, 0, 1));
    $i += 4;
    $self->{_protoVer} = ord(substr($msg, $i, 1));
    $self->{_client} = 1 if ($self->{_protoVer} == 10);

    ++$i;
    $end = index($msg, "\0", $i) - $i;
    $self->{_serverVer} = substr($msg, $i, $end);
    $i += $end + 1;
    $self->{_threadId} = unpack("v", substr($msg, $i, 2));
    $i += 4;
    $self->{_salt} = substr($msg, $i, 8);
    $i += 9;
    $i++ if (length($msg) >= $i + 1);
    $i += 17;
    $self->{_salt} .= substr($msg, $i, 12) if (length($msg) >= $i + 11);

    $loginMsg = "\0\0\x01\x0d\xa6\03\0\0\0\0\x01\x21\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0" .
                "\0\0\0\0\0\0". $self->{user} . "\0" . 
                ($self->{password} =~ /^$/ ? "\0" : "\x14" . $self->_scramblePassword()) .
                $self->{database} . "\0"; 
    $loginMsg = chr(length($loginMsg) - 3) . $loginMsg;
    $socket->send($loginMsg, 0);

    undef($msg);

    $socket->recv($msg, 1460, 0);

    if (my ($errCode, $errMsg) = $self->_isSQLError($msg)) {

        $socket->close();
        $self->{_error} = "SQL error ($errCode): $errMsg";

        return;

    }

    $self->{_socket} = $socket;

    return(1);

}

sub error {

    my $self = shift;

    my $error = $self->{_error};
    undef($self->{_error});

    return($error);

}

sub _isSQLError {

    my $self = shift;
    my $packet = shift;

    if (length($packet) < 4 || ord(substr($packet, 4)) == 255) {

        my ($errMsg, $errCode);
        $errMsg = length($packet) < 7 ? "Undefined error" : substr($packet, 13);
        $errCode = unpack("v", substr($packet, 5, 2)) // "-";
        

        return($errCode, $errMsg);

    }

    return;

}

sub _scramblePassword {

    my $self = shift;

    my ($ctx, $stage1, $stage2, $result, 
        $length);
    $ctx = Digest::SHA->new(1);
    $ctx->reset();
    $ctx->add($self->{password});
    $stage1 = $ctx->digest();
    $ctx->reset();
    $ctx->add($stage1);
    $stage2 = $ctx->digest();
    $ctx->reset();
    $ctx->add($self->{_salt});
    $ctx->add($stage2);
    $result = $ctx->digest();
    $length = length($result) - 1;

    return(join("", map { pack 'C', (unpack('C', substr($result, $_, 1)) ^ unpack("C", substr($stage1, $_, 1))) } 0 .. $length));

}

sub _clearResponse {

    my $self = shift;

    undef($self->{_response});
    $self->{_responsePos} = 0;
    $self->{_responseColLen} = 0;
    $self->{_responseCols} = [];

}

sub query {

    my $self = shift;
    my $query = shift;

    $self->_clearResponse();

    if ((defined $self->{_socket} && !$self->{_socket}->connected()) || !defined $self->{_socket}) { $self->throw("Socket is not connected to host"); }
    elsif (!defined $query) { $self->warn("Empty query"); }
    else { 
        
        if (my $response = $self->_send("\x03", $query)) {

            $self->{_response} = $response;

            return(1);

        }
        
    }

    return;

}

sub columns {

    my $self = shift;

    $self->read() if (defined $self->{_response} && !$self->{_responsePos});

    return(wantarray() ? @{$self->{_responseCols}} : $self->{_responseCols});

}

sub read {

    my $self = shift;

    if (!defined $self->{_response}) { 
        
        $self->warn("Nothing to read"); 
        
        return; 
        
    }
    else {

        if (!$self->{_responsePos}) {

            $self->{_responsePos} += 4;
            $self->{_responseColLen} = ord(substr($self->{_response}, $self->{_responsePos}, 1)); 
            $self->{_responsePos} += 5;

            for my $i (1 .. $self->{_responseColLen}) {

                my ($column);
                $self->_getAndSeek() for (1 .. 4);
                $column = $self->_getAndSeek();
                $self->_getAndSeek() for (1 .. 2);
                $self->{_responsePos} += 4;

                push(@{$self->{_responseCols}}, $column);

            }

            $self->{_responsePos} += 9;

        }

        if (substr($self->{_response}, $self->{_responsePos}, 5) eq "\xFE\x00\x00\x22\x00") {

            $self->_clearResponse();

            return;

        }

        my (@record, %record);
        @record = map { $self->_getAndSeek() } 1 .. $self->{_responseColLen};
        %record = map { $self->{_responseCols}->[$_] => $record[$_] } 0 .. $#record;

        $self->{_responsePos} += 4;

        return(wantarray() ? %record : \%record);
            
    }

}

sub _getAndSeek {

    my $self = shift;

    my ($length, $text); 
    $length = $self->_fieldLen();

    return if (!defined $length);

    $text = substr($self->{_response}, $self->{_responsePos}, $length);
    $self->{_responsePos} += $length;

    return($text);

}

sub _fieldLen {
    
    my $self = shift;

    my ($head);
    $head = ord(substr($self->{_response}, $self->{_responsePos}, 1));
    $self->{_responsePos}++;

    if ($head == 251) { return; }
    elsif ($head < 251) { return($head); }
    elsif ($head == 252) {

        my $length = unpack("v", substr($self->{_response}, $self->{_responsePos}, 2));
        $self->{_responsePos} += 2;

        return($length);

    }
    elsif ($head == 253) {

        my ($int24, $length);
        $int24 = substr($self->{_response}, $self->{_responsePos}, 3);
        $length = unpack("C", substr($int24, 0, 1)) + (unpack("C", substr($int24, 1, 1)) << 8) + (unpack("C", substr($int24, 2, 1)) << 16);
        $self->{_responsePos} += 3;

        return($length);

    }
    else {

        my ($int32, $length);
        $int32 = substr($self->{_response}, $self->{_responsePos}, 4);
        $length = unpack("C", substr($int32, 0, 1)) + (unpack("C", substr($int32, 1, 1)) << 8) + 
                 (unpack("C", substr($int32, 2, 1)) << 16) + (unpack("C", subst($int32, 3, 1)) << 24);
        $self->{_responsePos} += 8;
        
        return($length);

    }

}

sub _send {

    my $self = shift;
    my ($command, $query) = @_;

    my ($socket, $msg, $response);
    $socket = $self->{_socket};
    $msg = pack("V", length($query) + 1) . $command . $query;
    $socket->send($msg, 0);
    $socket->recv($response, 1460, 0);

    if (my ($errCode, $errMsg) = $self->_isSQLError($response)) {

        $self->{_error} = "SQL query error ($errCode): $errMsg";

        return;

    }
    else {

        my $colLen = ord(substr($response, 4));

        if ($colLen >= 1) { # Response to a SELECT query

            while (substr($response, -5) ne "\xFE\x00\x00\x22\x00") {

                my ($nextResponse);
                $socket->recv($nextResponse, 1460, 0);
                $response .= $nextResponse;

            }

        }

        return($response);

    }

}

sub close {
    
    my $self = shift;

    my $socket = $self->{_socket};

    if (!$socket->connected()) { $self->warn("No open socket"); }
    else {

        $socket->send(chr(1) . "\x00\x00\x00\x01", 0);
        $socket->close();

    }

}

1;