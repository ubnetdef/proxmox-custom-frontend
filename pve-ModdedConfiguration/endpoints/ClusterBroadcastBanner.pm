package PVE::API2::ClusterBroadcastBanner;

use strict;
use warnings;

use PVE::RESTHandler;
use PVE::JSONSchema qw(get_standard_option);

use base qw(PVE::RESTHandler);

__PACKAGE__->register_method({
    name => 'list_broadcasts',
    path => '',
    method => 'GET',
    permissions => { user => 'world' },
    description => "Get login broadcast messages",
    parameters => {
        additionalProperties => 0,
        properties => {},
    },
    returns => {
        type => 'array',
        items => {
            type => 'object',
        },
    },
    code => sub {
        my ($param) = @_;
    
        my $file = "/etc/pve/broadcast-banner.json";
    
        warn "BANNER API HIT\n";
    
        if (! -e $file) {
            warn "FILE MISSING\n";
            return [];
        }
    
        my $raw = PVE::Tools::file_get_contents($file);
    
        warn "RAW CONTENT: $raw\n";
    
        my $data;
    
        eval {
            require JSON;
            $data = JSON::decode_json($raw);
        };
    
        if ($@) {
            warn "JSON ERROR: $@\n";
            return [];
        }
    
        warn "PARSED OK\n";
    
        return $data;
    },
});

1;