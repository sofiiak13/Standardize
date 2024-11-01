# Title: EMAIL.pm
# Authors: Sofiia Khutorna
# Created: 2024-06-20
# Description: object to send emails
#

package EMAIL;

use lib '/home/skhutorn/misc/DataUsageAnalyst/v0.1';
use Data::Dumper qw(Dumper);
use MIME::Lite;

# Subroutine Name: new()
# Example use: EMAIL->new()
# Description:
#     Creates a new EMAIL object
# Parameters:
#     none
# Return:
#     $self: EMAIL object 
sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

# Subroutine Name: send_text()
# Example use: EMAIL->send_text(\%params)
# Description:
#     send email with just plain text
# Parameters:
#     $params = (
#                   subject => "Sofiia's report"
#                   content => "This report was generated by my script",
#                   sender => "sofiiaexample@gmail.com",
#                   recipients => ("tariqexample@gmail.com", "remexample@gmail.com")
#                   );
# Return:
#     $self: none
sub send_text {
    my $self = shift;
    my $params = shift;

    my $subject = $params->{subject};
    my $content = $params->{content};
    my $sender = $params->{sender};
    my @recipients = @{$params->{recipients}}; 

    $to = shift(@recipients);    
    my $cc = "";

    if ((scalar @recipients) > 1) { 
        while (scalar @recipients > 1) {
            $cc .= (shift(@recipients) . ", ");
        }
        $cc .= shift(@recipients)
    } 

    $msg = MIME::Lite->new(
        From     => $sender,
        To       => $to,
        Cc       => $cc,
        Subject  => $subject,
        Data     => $content
    );

    $msg->send;

    return;
}

# Subroutine Name: send_attachment()
# Example use: EMAIL->send_attachment(\%params)
# Description:
#     sends email with attachment
# Parameters:
#     $params = (
#           subject => "Jasper naming standard report",
#           path => $path_to_attachment,
#           sender => 'sofiia@example.com',
#           recipients => \@recipients_array,
#           content => $text
#           );
# Return:
#     $self: none
sub send_attachment {
    my $self = shift;
    my $params = shift;

    my $subject = $params->{subject};
    my $content = defined($params->{content})  ? $params->{content} : "This email was generated automatically.";
    my $path = $params->{path};
    my $filename = "attachment";
    if ($path =~ m|([^/]+)$|) {
        $filename = $1;
    }
    my $sender = $params->{sender};
    
    my @recipients = @{$params->{recipients}}; 
  
    $to = shift(@recipients);    
    my $cc = "";

    if ((scalar @recipients) >= 1) { 
        while (scalar @recipients > 1) {
            $cc .= (shift(@recipients) . ", ");
        }
        $cc .= shift(@recipients)
    } 

    $msg = MIME::Lite->new(
        From     => $sender,
        To       => $to,
        Cc       => $cc,
        Subject  => $subject,
        Data     => $content,
        Type     => 'multipart/mixed',

    );

    $msg->attach(
        Path        => $path,
        Filename    => $filename,
        Disposition => 'attachment'
    );

    $msg->send;

    return;
}

1;