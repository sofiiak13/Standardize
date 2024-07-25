# Title: Router.pm
# Authors: Sofiia Khutorna, Rem D'Ambrosio
# Created: 2024-06-06
# Description: object to hold router info
#


package Router;

use Data::Dumper qw(Dumper);

# Subroutine Name: new()
# Example use: Router->new(\%params)
# Description:
#     creates a new Router object
# Parameters:
#     %params: hash with router's parameters
# Return:
#     $self: new Router object
sub new {
    my $class = shift;
    my $param = shift;

    # Default values
    my $net_dev_name = defined($param->{net_dev_name}) ? $param->{net_dev_name} : 'no_net_dev_name';
    my $router_name = defined($param->{router_name}) ? $param->{router_name} : 'no_router_name';
    my $final_name = defined($param->{final_name}) ? $param->{final_name} : 'no_name';
    my $router_id = defined($param->{router_id}) ? $param->{router_id} : 'no_router_id';
    my $iccid = defined($param->{iccid}) ? $param->{iccid} : 'no_iccid';
    my $phi_name = defined($param->{phi_name}) ? $param->{phi_name} : 'no_phi_name';
    my $site_code = defined($param->{site_code}) ? $param->{site_code} : 'no_site_code';
    my $phi_code = defined($param->{phi_code}) ? $param->{phi_code} : 'no_phi_code';
    my $address = defined($param->{address}) ? $param->{address} : 'no_address';
    my $changed = defined($param->{changed}) ? $param->{changed} : 'no_change';


    my $self = {
        net_dev_name => $net_dev_name,
        router_name => $router_name,
        final_name => $final_name,
        router_id => $router_id,
        iccid => $iccid,
        phi_name => $phi_name,
        site_code => $site_code,
        phi_code => $phi_code,
        address => $address,
        changed => $changed
    };

    bless $self, $class;
    return $self;
}

# Subroutine Name: TO_JSON
# Example use: 
# Description:
#     allows Router objects to be converted to a json with convert_blessed(1)
# Parameters:
#     none
# Return:
#     none
sub TO_JSON { return { %{ shift() } }; }

# Subroutine Name: update_router()
# Example use: router->update_router(\%params)
# Description:
#     updates all values in router's attribute hash
# Parameters:
#     %params: hash with new parameters
# Return:
#     none
sub update_router {
    my $self = shift;
    my $param = shift;
    
    $self->{net_dev_name} = $param->{net_dev_name} if defined($param->{net_dev_name});
    $self->{router_name} = $param->{router_name} if defined($param->{router_name});
    $self->{final_name} = $param->{final_name} if defined($param->{final_name});
    $self->{router_id} = $param->{router_id} if defined($param->{router_id});
    $self->{iccid} = $param->{iccid} if defined($param->{iccid});
    $self->{phi_name} = $param->{phi_name} if defined($param->{phi_name});
    $self->{site_code} = $param->{site_code} if defined($param->{site_code});
    $self->{phi_code} = $param->{phi_code} if defined($param->{phi_code});
    $self->{address} = $param->{address} if defined($param->{address});
    $self->{changed} = $param->{changed} if defined($param->{changed});

}

sub get_router_info {
    $self = shift;
    return $self;
}

1;
