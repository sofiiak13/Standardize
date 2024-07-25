# Title: Standardize.pm 
# made by Sofiia Khutorna
# Created: 2024-05-23
# Description: script for checking and fixing all names in Beta and Phi 
#

package Standardize;

use lib '/home/';

use BetaAPI;
use API::Phi;
use Router;
use LWP::UserAgent;             # An object for holding requests
use HTTP::Request::Common;      # For structuring the request
use JSON;


# Subroutine Name: new()
# Example use: Standardize->new()
# Description:
#     Creates a new Standardize object
# Parameters:
#     none
# Return:
#     $self: Standardize object 
sub new {
    my $class = shift;
    my $self = {
        mapped_hash => {},
        routers_hash => {},
        netdev_hash => {}
    };
    bless $self, $class;
    return $self;
}

# Subroutine Name: pull_beta_data()
# Example use: Standardize->pull_beta_data()
# Description:
#     Pulls data from BetaAPI and stores it inside of routers_hash and netdev_hash
# Parameters:
#     none
# Return:
#     none
sub pull_beta_data {
    my $self = shift;
    my $beta = BetaAPI->new();

    for (my $i = 0; $i < 4500; $i += 500) {
        my $routers_data = ($beta->getData("some api call"));
        my $netdevices_data = ($beta->getData("some api call"));
        my $routers_ref = JSON::decode_json($routers_data);
        my $netdevices_ref = JSON::decode_json($netdevices_data);
        my $routers = $routers_ref->{data};                         
        my $netdevices = $netdevices_ref->{data};

        $self->routers_hash($routers);
        $self->netdev_hash($netdevices);
        sleep(2);
    }

    return;
}

# Subroutine Name: netdev_hash()
# Example use: Standardize->netdev_hash($netdevices)
# Description:
#     takes json with netdevices and stores it into netdev_hash with iccid's as keys
# Parameters:
#     $netdevices: array reference to netdevices
# Return:
#     none
sub netdev_hash {
    my $self = shift;
    my $netdevices = shift;
    my @netdev_array = @$netdevices;
    foreach my $netdev (@netdev_array) {
        my $netdev_iccid = $netdev->{iccid};
        if ($netdev_iccid) {
            $self->{netdev_hash}{$netdev_iccid} = $netdev;
        }   
    }
    print "Netdevices have ".(scalar keys %{$self->{netdev_hash}}) . " objects \n";
    return;
}

# Subroutine Name: routers_hash()
# Example use: Standardize->routers_hash($routers)
# Description:
#     takes json with routers and stores it into routers_hash with router name's as keys
# Parameters:
#     $routers: array reference to routers
# Return:
#     none
sub routers_hash {
    my $self = shift;
    my $routers = shift;
    my @routers_array = @$routers;

    foreach my $router (@routers_array) {
        my $router_id = $router->{id};
        if ($router_id){
            $self->{routers_hash}{$router_id} = $router;
        }
    }

    print "Routers have ".(scalar keys %{$self->{routers_hash}}) . " objects \n";
    return;
}

# Subroutine Name: match_by_id()
# Example use: Standardize->match_by_id()
# Description:
#     matches devices from netdev_hash to routers_hash by their id's
#     creates router objects with appropriate information from both hashes and
#     stores these objects in mapped_hash
# Parameters:
#     none
# Return:
#     none
sub match_by_id {
    my $self = shift;
    my $routers = $self->{routers_hash};
    my $netdevices = $self->{netdev_hash};
    my $i = 0;
    my $section = 0;
    foreach my $net_iccid (keys %$netdevices) {
        if ($i % 200 == 0) {
            $section++;
        }

        my $net_url = $netdevices->{$net_iccid}{router}; 
        if (!defined($net_url)) {                                                       # if there is no router url in net devices, skip to the next loop
            next;
        }
        $net_url =~ m|/(\d+)/$|; 
        my $net_id = $1;

        if (($routers->{$net_id})) {                                                    
            my $description = $routers->{$net_id}{description};
            my $site_code;
            my $address;

            if (!defined($description) || $description eq ''){                           # get site code and address from the description of a router
                $site_code = "no_site_code";
                $address = "no_address";
            } elsif ($description =~ /^my regex$/) {
                $site_code = $1;
                $address = $2;
            } elsif ($description =~ /^my regex$/) {
                $site_code = $description;
                $address = "no_address";
            } 
            
            my %new_params = (                                                             # get other router parameters
                    net_dev_name => $netdevices->{$net_iccid}{name},
                    router_name => $routers->{$net_id}{name},
                    router_id => $routers->{$net_id}{id},
                    iccid => $netdevices->{$net_iccid}{iccid},
                    site_code => $site_code,
                    address => $address,
                );
            my $new_router = Router->new(\%new_params);
            $self->{mapped_hash}{$section}{$net_iccid} = $new_router;                      # add new router to the hash with iccid as a key
            $i++;
        }
    }
    print "Done with Beta, it matched has $i iccids \n";
    return $section;
    
}

# Subroutine Name: map_to_phi()
# Example use: Standardize->map_to_phi($section)
# Description:
#     maps devices from Beta to devices in Phi by their iccid's
#     by updating info inside of mapped_hash
# Parameters:
#     $section: indicates which section needs to be grabbed from mapped_hash
# Return:
#     none
sub map_to_phi {
    my $self = shift;
    my $section = shift;
    my $phi = API::Phi->new();
    foreach my $iccid (keys %{$self->{mapped_hash}{$section}}) {                    # iterate through each router, get it's device id/name and site code from Phi
        my $data = $phi->getData('api call');
        my $data_ref = JSON::decode_json($data); 
        my %device_hash = %{$data_ref};
        my %updated_params = (
            phi_name => $device_hash{deviceID},
            phi_code => $device_hash{accountCustom2}
        );
        $self->{mapped_hash}{$section}{$iccid}->update_router(\%updated_params);    # update router with new parameters
    }
    print ("mapped to Phi!\n");
    return;
}

# Subroutine Name: final_update()
# Example use: Standardize->final_update($section)
# Description:
#     compares Beta name to Phi name and
#     chooses the correct format one 
# Parameters:
#     $section: indicates which section is updated in mapped_hash
# Return:
#     none
sub final_update {
    my $self = shift;
    my $section = shift;

    foreach my $iccid (keys %{$self->{mapped_hash}{$section}}) {
        
        my %cur_dev = %{$self->{mapped_hash}{$section}{$iccid}};
        my $phi_name = $cur_dev{phi_name} ? $cur_dev{phi_name} : "not found";
        my $beta_name = $cur_dev{router_name} ? $cur_dev{router_name} : "not found";

        my %updated_params;
        my ($new_name, $change);
        if ($phi_name ne $beta_name) {                                   # if names look different, use the regex to identify which name follows the standard, 
            if ($beta_name =~ /my regex/) {                              # store this info in $change and $new_name that follows standard
                $new_name = $1;
                $change = "Phi and Beta";
                if ($beta_name =~ /^my regex$/) {
                    $change = "Phi";   
                } elsif ($phi_name =~ /^my regex$/) {
                    $change = "Beta";
                }
            } elsif ($phi_name =~ /my regex/) {
                $new_name = $1;
                $change = "Phi and Beta";
                if ($phi_name =~ /^my regex$/) {
                    $change = "Beta";
                } 
            } else {
                $new_name = "";
                $change = "Unsure name";
            }
            
            %updated_params = (
                final_name => $new_name,
                changed => $change
                );
                
            $self->{mapped_hash}{$section}{$iccid}->update_router(\%updated_params);    
        }
    }
    return;
}

# Subroutine Name: update_name()
# Example use: Standardize->update_name($section)
# Description:
#     updates names in Phi
# Parameters:
#     $section: indicates which section needs to be grabbed from mapped_hash
# Return:
#     none
sub update_name {
    $self = shift;
    my $section = shift;
    my $phi = API::Phi->new();
    foreach my $iccid (keys %{$self->{mapped_hash}{$section}}) {
        my %cur_dev = %{$self->{mapped_hash}{$section}{$iccid}};
        if ($cur_dev{changed} =~ "Phi") {
            my $new_name = uc($cur_dev{final_name});
            my %update = (
                    deviceID => $new_name
                    );
            my $change = $phi->putData('id', \%update);
            print "NEW NAME $new_name in $cur_dev{changed}\n";
        } 
    }
    return;
}

# Subroutine Name: update_location()
# Example use: Standardize->update_location($section)
# Description:
#     updates site codes in Phi
# Parameters:
#     $section: indicates which section needs to be grabbed from mapped_hash
# Return:
#     none
sub update_location {
    $self = shift;
    my $section = shift;
    my $phi = API::Phi->new();
    foreach my $iccid (keys %{$self->{mapped_hash}{$section}}) {
        my %cur_dev = %{$self->{mapped_hash}{$section}{$iccid}};
        my $site_code = $cur_dev{site_code} ? $cur_dev{site_code} : "no_site_code";
        my $phi_code = $cur_dev{phi_code};
        if ($cur_dev{phi_name} eq "no_phi_name") {
            next;
        }
        if (($site_code ne $phi_code) && ($site_code ne "no_site_code")){                           # update phi site code if there it does not equal to site code from beta
            my %update = (
                    accountCustom2 => $site_code
                    );
            $phi->putData('data', \%update);
            print "Updated location code to $site_code for $iccid device\n";
        }    
    }
    return;
}

# Subroutine Name: report_all()
# Example use: Standardize->report_all($section)
# Description:
#     writes and stores a report_all about every value that has been changed
# Parameters:
#     $section: indicates which section gets reported
# Return:
#     none
sub report_all {
    my $self = shift;
    my $section = shift;
    my $content = "";
    foreach my $iccid (keys %{$self->{mapped_hash}{$section}}) {
        my $change = $self->{mapped_hash}{$section}{$iccid}{changed};
        if ($change =~ "Phi") {
            my %cur_dev = %{$self->{mapped_hash}{$section}{$iccid}};
            my $phi_name = $cur_dev{phi_name};
            my $beta_name = $cur_dev{router_name};
            my $new_name = $cur_dev{final_name};
            $change = $cur_dev{changed};
            $content .=  "$phi_name,$beta_name,$new_name,$change\n";
        }
    }

    my $filename = "report_all_".$section.".csv";
    $self->to_file($content, $filename);
    return;
}


# Subroutine Name: report_failed()
# Example use: Standardize->report_failed($section)
# Description:
#     writes and stores a report_failed about every value that needs to change but could not be changed for some reason
# Parameters:
#     $section: int, indicates which section is reported from mapped_hash
# Return:
#     none
sub report_failed {
    my $self = shift;
    my $section = shift;
    my $content = "";
    foreach my $iccid (keys %{$self->{mapped_hash}{$section}}) {
        my %cur_dev = %{$self->{mapped_hash}{$section}{$iccid}};
        my $phi_name = $cur_dev{phi_name};
        my $beta_name = $cur_dev{router_name};
        my $new_name = $cur_dev{final_name};
        my $change = $cur_dev{changed};
        if ($phi_name eq "no_phi_name") {
            $change = "Corresponding device does not exist in Phi. Add at iccid $iccid";
            $content .= "$phi_name,$beta_name,$change\n";  
        } elsif ($change =~ "Beta") {
            $change = "Name in Beta does not follow our standard. Change to $new_name.";
            $content .= "$phi_name,$beta_name,$change\n";  
        } elsif ($change eq "Unsure name") {
            $change = "Unsure name. Both failed to follow our standard.";
            $content .= "$phi_name,$beta_name,$change\n";  
        } 
    }
    my $filename = "report_failed_changes_".$section.".csv";
    $self->to_file($content, $filename);
    return;
}

# Subroutine Name: to_file()
# Example use: Standardize->to_file($report)
# Description:
#     output report to file
# Parameters:
#     $report: sring consisting report
# Return:
#     none
sub to_file {
    my $self = shift;
    my $report = shift;
    my $filename = "/home/".shift;
    open my $file, '>', $filename or die "Cannot write output file: $!\n";
    print $file $report;
    close $file;
    return;
}

# Subroutine Name: combine_all()
# Example use: Standardize->combine_all()
# Description:
#     combines all report files and deletes temporary report files
# Parameters:
#     none
# Return:
#     \@array: array reference with file paths of new combined files
sub combine_all {
    my $self = shift;

    my $header_all = "Report of all changes made to Phi\n";
    my $columns_all = "Phi Device ID:,Beta Router Name:,New name:,Changed in:\n";
    my $filename_all = "/home/all_changes.csv";
    my $count_all = 0;
    my @all = glob('/home/report_all_*');


    open(OUTPUT, ">", $filename_all) or die "Cannot write combined file\n";
    print OUTPUT $header_all;
    print OUTPUT $columns_all;

    foreach my $filename (@all){
        if (-z $filename) {                 # check if file is empty
            next; 
        }
        open(INPUT, $filename);
        print OUTPUT <INPUT>;
        close(INPUT);
        $count_all++;
    }

    close(OUTPUT);
    system("rm /home/report_all_*");
    return $count_all;
}

sub combine_failed {
    my $self = shift;

    my $header_failed = "Report of all issues that could not be changed in Phi \n";
    my $columns_failed = "Phi Device ID:,Beta Router Name:,Details:\n";
    my $filename_failed = "/home/failed_to_change.csv";
    my $count_fail = 0;
    my @failed = glob('/home/report_failed_*');

    open(OUTPUT, ">", $filename_failed) or die "Cannot write combined file\n";
    print OUTPUT $header_failed;
    print OUTPUT $columns_failed;

    foreach my $filename (@failed){
        if (-z $filename) {                 # check if file is empty
            next; 
        }
        open(INPUT, $filename);
        print OUTPUT <INPUT>;
        close(INPUT);
        $count_fail++;
    }

    close(OUTPUT);
    system("rm /home/report_failed_*");
    return $count_fail;
}

# Subroutine Name: send_email()
# Example use: Standardize->send_email($path, $to)
# Description:
#     emails report files to recipient(s)
# Parameters:
#     $path : path to a file you want to attach to email
#     $to: email address of recipient(s) passed as an array reference
# Return:
#     none
sub send_email {
    my $self = shift;
    my $path = shift;
    my $recipients = shift;
    my $email = EMAIL->new();

    my $text = "Hello!\nThis is the report of all the things that need to be fixed in Phi or in Beta database. Thank you! Have a nice day!";
    my %params = (
        subject => "Phi naming standard report",
        path => $path,
        sender => 'sofiia@example.com',
        recipients => $recipients,
        content => $text
    );

    $email->send_attachment(\%params); 
    print "Email Sent Successfully\n";      
    return;
}

1;