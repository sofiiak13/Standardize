# Title: standardizeAlpha.pl
# made by Sofiia Khutorna
# Created: 2024-10-10
# Description: script for checking and fixing all names in Beta and Alpha 

package standardizeAlpha;

use lib './v1.0';
use API::Beta;
use API::Alpha;
use NameStandardizer;       # custom created
use Router;
use JSON;
use Logger;
use Data::Dumper qw(Dumper);

# Example use: pull_beta_data()
# Description:
#     Pulls data from BetaAPI and stores it inside of temp files
sub pull_beta_data {
    my $directory = shift;
    my $cp = API::Beta->new();
    my @pids;
    for (my $i = 0; $i < 4500; $i += 500) {
        my $pid = fork();
        if ($pid) {
            push @pids, $pid;
            next;
        } else {
            my $file_num = $i / 500;

            my $routers_data = ($cp->APIcall);
            my $netdev_data = ($cp->APIcall);

            to_file($routers_data, $directory."temp_routers".$file_num.".json");
            to_file($netdev_data, $directory."temp_netdev".$file_num.".json");
            exit(0);
        }
    }

    foreach my $id (@pids) {
        waitpid($id, 0);
    }
    $logger->logF("Pulled Beta data");
    return;
}

# Example use: access_beta_data($directory, $type)
# Description:
#     Access raw Beta information from temp files 
# Parameters: 
#     $directory - string, filepath for saving all reports
#     $type - string, defines the type of device info that we want to access
# Returns: 
#     $dev_hash - device hash with a specified device's info
sub access_beta_data {
    my ($directory, $type) = @_;
    my $path = $directory."temp_".$type."*";
    my @devices = glob($path);
    my $dev_hash = {};
    foreach my $filename (@devices) {                                                   # access information about beta devices
        open(OUTPUT, '<', $filename) or die "Cannot open file $filename\n";
        my $data = do { local $/; <OUTPUT> }; 
        close(OUTPUT);
        my $ref = JSON::decode_json($data);
        my $devices = $ref->{data};  
        $dev_hash = device_hash($devices, $dev_hash, $type);
    }
    my $fubetation = "rm $path";
    system($fubetation);                                                                # delete device temp files
    return $dev_hash;
}

# Example use: access_beta_data($arr_ref, $hash_ref, $type)   
# Parameters: 
#     $arr_ref - referebetae to array with devices info that we need to store
#     $hash_ref - referebetae to hash where we need to save selected device info 
#     $type - string, based on which we decide what values are keys in our hash
# Returns: 
#     $dev_hash - device hash with a specified device's info
sub device_hash {
    my ($arr_ref, $hash_ref, $type) = @_;
    my $key = ($type eq "routers") ? "id" : "iccid";
    my @array = @$arr_ref;
    my %hash = %{$hash_ref};
    foreach my $device (@array) {
        my $value = $device->{$key};
        if ($value) {
            $hash{$value} = $device;
        }   
    }
    return \%hash;
}

# Example use: match_by_id($routers, $netdevices, $limit)
# Description:
#     matches devices from netdev_hash to routers_hash by their id's, creates router objects with 
#     appropriate information from both hashes and stores these objects in mapped_hash
# Parameters: 
#     $routers - hash ref to routers hash
#     $netdevices - hash ref to netdevices hash
#     $limit - int, defining the limit of devices per section
# Returns: 
#     $section - int, to indicate which section we are currently mapping (used for multiprocessing)
#     $mapped_hash - ref to hash that has necessary info from routers and netdev hashes
sub match_by_id {
    my ($routers, $netdevices, $limit) = @_;
    my $i = 0;
    my $section = 0;
    my $mapped_hash = {};
    foreach my $net_iccid (keys %$netdevices) {
        if ($i % $limit == 0) {
            $section++;
        }

        my $net_url = $netdevices->{$net_iccid}{router}; 
        next unless defined $net_url;                                                   # if there is no router url in net devices, skip to the next loop
        $net_url =~ m|/(\d+)/$|; 
        my $net_id = $1;
        next unless $routers->{$net_id};                                                  
        my $description = $routers->{$net_id}{description};
        my $site_code;
        my $address;

        if (defined($description) && $description ne '') {                           # get site code and address from the description of a router
            if ($description =~ /^\[([^\]]{9})\]\s*(.+)$/) {
                $site_code = $1;
                $address = $2;
            } elsif ($description =~ /^([\w]{6}-\d{2})$/) {
                $site_code = $description;
                $address = "";
            }    
        }
        my %new_params = (                                                             # get other router parameters
                some => parameters
            );
        my $new_router = Router->new(\%new_params);
        $mapped_hash->{$section}{$net_iccid} = $new_router;                      # add new router to the hash with iccid as a key
        $i++;
    }

    $logger->logF("Matched $i beta devices in $section sections by id.");
    return $section, $mapped_hash;
}

# Example use: map_to_alpha($section)
# Description:
#     maps devices from Beta to devices in Alpha by their iccid's
#     by updating info inside of mapped_hash
# Parameters:
#     $mapped_hash: mapped hash with device info only from beta
# Returns:
#     $mapped_hash: mapped hash with device info from alpha and beta
sub map_to_alpha {
    my $mapped_hash = shift;
    my $alpha = API::Alpha->new();
    foreach my $iccid (keys %{$mapped_hash}) {                    # iterate through each router, get it's device id/name and site code from Alpha
        my $data = $alpha->getDeviceDetails($iccid);
        my $data_ref = JSON::decode_json($data); 
        my %device_hash = %{$data_ref};
        my %updated_params = (
            alpha_name => $device_hash{deviceID},
            alpha_site_code => $device_hash{accountCustom2}
        );
        $mapped_hash->{$iccid}->update_router(\%updated_params);    # update router with new parameters
    }
    $logger->logF("Mapped a section to Alpha");
    return $mapped_hash;
}

# Example use: internal_update($section)
# Description:
#     compares Beta name to Alpha name and
#     chooses the correct format one 
# Parameters:
#     $mapped_hash: mapped hash with device info from alpha and beta
# Returns:      
#     $mapped_hash: updated mapped_hash with new names
sub internal_update {
    my $mapped_hash = shift;
    my $standard = NameStandardizer->new();
    foreach my $iccid (keys %{$mapped_hash}) {
        my %cur_dev = %{$mapped_hash->{$iccid}};
        my $alpha_name = $cur_dev{alpha_name} ? $cur_dev{alpha_name} : "";
        my $beta_name = $cur_dev{router_name} ? $cur_dev{router_name} : "";

        my (%updated_params, $new_name);
        if ($cur_dev{connection_state} ne "unplugged") {        # if names look different, use the regex to identify which name follows the standard, 
        my $new_name = $standard->single_check($alpha_name);
        if ($new_name eq "ok") {next;}
        if ($new_name eq "bad") {
            my $new_beta = $standard->single_check($beta_name);
            if ($new_beta eq "ok") {
                $new_name = $beta_name;
            } elsif ($new_beta ne "bad") {
                $new_name = $new_beta;
            } else {
                $new_name = "unknown";
            }
        }
            
        %updated_params = (final_name => $new_name);
        $mapped_hash->{$iccid}->update_router(\%updated_params);  
        }
    } 
    $logger->logF("Internal update in a section");
    return $mapped_hash;
}

# Example use: update_alpha($mapped_hash)
# Description:
#     puts updates back to Alpha when there's update indicated in mapped_hash 
# Parameters:   $mapped_hash
sub update_alpha {
    my $mapped_hash = shift;
    my $alpha = API::Alpha->new();
    foreach my $iccid (keys %{$mapped_hash}) {
        my %cur_dev = %{$mapped_hash->{$iccid}};
        my $site_code = $cur_dev{site_code} ? $cur_dev{site_code} : '';
        my $alpha_site_code = $cur_dev{alpha_site_code};
        my %update;
        next unless $cur_dev{alpha_name};
        if ($cur_dev{final_name} && ($cur_dev{final_name} ne "unknown")) {
            my $new_name = uc($cur_dev{final_name});
            $update{deviceID} = $new_name;
            $update{accountCustom3} = "Used to be $cur_dev{alpha_name}";
        }

        if ($site_code && ($site_code ne $alpha_site_code)) {
            $update{accountCustom2} = $site_code;
        }
        
        if (scalar keys %update != 0) {
            my $change = $alpha->putData(\%update);
            print Dumper($change);
        }
    }
    $logger->logF("Updated Alpha in a section.");
    return;
}

# Example use: report_all($mapped_hash, $filename)
# Description:
#     writes and stores a report_all about every value that has been changed
sub report_all {
    my ($mapped_hash, $filename) = @_;
    my $content = "";
    foreach my $iccid (keys %{$mapped_hash}) {
        my $final_name = $mapped_hash->{$iccid}{final_name};
        my %cur_dev = %{$mapped_hash->{$iccid}};
        if ($cur_dev{alpha_name} && $final_name && $final_name ne "unknown") {
            my $alpha_name = $cur_dev{alpha_name};
            my $beta_name = $cur_dev{router_name};
            $content .= "$alpha_name,$beta_name,$final_name\n";
        }
    }
    $logger->logF("Reported all in a section.");
    to_file($content, $filename);
    return;
}

# Example use: report_failed($section)
# Description:
#     writes and stores a report_failed about every value that needs to change but could not be changed for some reason
sub report_failed {
    my ($mapped_hash, $filename) = @_;
    my $content = "";
    foreach my $iccid (keys %{$mapped_hash}) {
        my %cur_dev = %{$mapped_hash->{$iccid}};
        my $alpha_name = $cur_dev{alpha_name};
        my $beta_name = $cur_dev{router_name};
        my $final_name = $cur_dev{final_name};
        if ($final_name eq "unknown") {
            $content .= "$alpha_name,$beta_name,Unsure name.\n";  
        } 
    }
    $logger->logF("Reported failed in a section.");
    to_file($content, $filename);
    return;
}

# Example use: to_file($report)
# Description:
#     output report to file
# Parameters:
#     $report: sring consisting report
sub to_file {
    my $report = shift;
    my $filename = shift;
    open my $file, '>', $filename or die "Cannot write output file $filename: $!\n";
    print $file $report;
    close $file;
    return;
}

# Example use: to_file($directory, $report_type)
# Description:
#     creates a combined csv string based on the $report type and stores the file in $directory
sub combine_reports {
    my $directory = shift;
    my $report_type = shift;
    my $columns;
    if ($report_type eq "changed") {
        $columns = "Alpha Device ID:,Beta Router Name:,New name:\n";
    } else {
        $columns = "Alpha Device ID:,Beta Router Name:,Details:\n";
    }

    my $filename = $directory."alpha_".$report_type.".csv";
    my $count = 0;
    my @files = glob($directory . $report_type . '*');

    open(OUTPUT, ">", $filename) or die "Cannot write combined file\n";
    print OUTPUT $columns;

    foreach my $file (@files){
        if (-z $file) {                 # check if file is empty
            next; 
        }
        open(INPUT, $file);
        print OUTPUT <INPUT>;
        close(INPUT);
        $count++;
    }

    close(OUTPUT);
    my $command = "rm ".$directory.$report_type."*";
    system($command);
    $logger->logF("Combined all reports.");
    return $count;
}

sub main {
    my $directory = "./v1.0/reports/";
    my %params = (  rollover => 0,
                    path => $directory."log.txt");
    $logger = Logger->new(\%params);

    $logger->logF("START");
    
    pull_beta_data($directory);
    print "Pulled data\n";

    my $routers_hash = access_beta_data($directory, "routers");
    my $netdev_hash = access_beta_data($directory, "netdev");
    print "Stored data\n";

    my ($count, $mapped_hash) = match_by_id($routers_hash, $netdev_hash, $limit);
    print "Mapped by id\n";
    my @pids;
    for my $i (1..$count) {
        my $pid = fork();
        if ($pid) {
            push @pids, $pid;
            next;
        } else {
            my $cur_hash = $mapped_hash->{$i}; 
            $cur_hash = map_to_alpha($cur_hash);
            $cur_hash = internal_update($cur_hash);

            my $file_all = $directory."changed".$i.".csv";
            report_all($cur_hash, $file_all);
            my $file_fail = $directory."failed".$i.".csv";
            report_failed($cur_hash, $file_fail);  
            
            update_alpha($cur_hash);
            exit(0);
        }
    }

    foreach my $id (@pids) {
        waitpid($id, 0);
    }

    my $all = combine_reports($directory, "changed");
    my $failed = combine_reports($directory, "failed");

    print "Done";
    $logger->logF("END");
}

main();
1;