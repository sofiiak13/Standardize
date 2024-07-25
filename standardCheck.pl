# made by Sofiia Khutorna
# Created: 2024-06-13

use lib '/home/';
use EMAIL;
use standardize;
use Getopt::Long;
use API::Phi;

my $fixer = standardize->new();

$fixer->pull_beta_data();
my $count = $fixer->match_by_id();

my @pids;
for my $i (1..$count) {
    my $pid = fork();
    push @pids, $pid;
    if ($pid){
      next;
    } else {
      $fixer->map_to_phi($i);
      $fixer->final_update($i);

      $fixer->report_all($i);
      $fixer->report_failed($i);
      
      $fixer->update_name($i);
      $fixer->update_location($i);
      die;
    }
}

foreach my $id (@pids) {
  waitpid($id, 0);
}

my $all = $fixer->combine_all();
my $failed = $fixer->combine_failed();

my @to_store = ('sofiia@example.com');
my @to_fix = ('khutorna@example.com');

$fixer->send_email("/home/all_changes.csv", \@to_store) if $all != 0;
$fixer->send_email("/home/failed_to_change.csv", \@to_fix) if $failed != 0;

1;