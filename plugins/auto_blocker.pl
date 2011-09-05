#!/usr/bin/perl
# alertmon package v.3, http://www.opennet.ru/dev/alertmon/
# Copyright (c) 1998-2004 by Maxim Chirkov. <mc@tyumen.ru>
#
# auto_blocker.pl <ip> <la_mon.la_name>
# �������������� IP �������������� � �����, ������ ����� ������ ����������� �����
# �������� ����� �������� LA � ������ <la_file>
# ������������ �� ���� ������ � ������� �������� ����������� %ip%
# ��������:
#<netstat_mon 1ip_overflow>
#    group_by ip
#    max_limit 50
#    email_after_probe 1
#    comment ����� �� ������ 50 ���������� � ������ ip (%ip%)
#    action_cmd /usr/local/alertmon/plugins/auto_blocker.pl %ip% la_mon.la5
#</netstat_mon>

use strict;

# ���������� ��� �������� ������������� ������-�����.
my $cfg_log_dir = "/usr/local/alertmon/toplogs"; 

# ������ ������� (regex �����) ������� �� ������ ������������� �� ��� ����� ��������.
my $cfg_ignore_ip='(192\.168\.10\.|127\.0\.0\.1|10\.0\.0\.)';

# ��� ���������� � ���������.
my $cfg_firewall_type = "htaccess"; # iptables|ipfw|htaccess (��������� ������ � .htaccess)
my $firewall_ipfw_cmd = '/sbin/ipfw add 444 deny ip from %IP%/32 to any';
my $firewall_iptables_cmd = '/sbin/iptables -I INPUT -s %IP%/255.255.255.255 -d 0.0.0.0/0.0.0.0 -p all -j REJECT';
my $firewall_htaccess_file = "/home/host1/htdocs/.htaccess";
# � .htaccess ������������ ������ (� ����� ��� ������ ���� RewriteEngine On)
# RewriteCond %{REMOTE_ADDR} IP
# RewriteRule .* / [F]

###########################################################################
if (! defined $ARGV[0] || ! defined $ARGV[0]){
    die "Usage: auto_blocker.pl <ip> <la_mon.la_name>\n";
}
my $in_ip = $ARGV[0];
$in_ip =~ s/[^\d\.]//g;
my $in_la_id = $ARGV[1];
$in_la_id =~ s/[^\d\w\-\_\.]//g;

if (-f "$cfg_log_dir/$in_la_id.act"){
    # LA ���� ����������, ���������.
    if ($in_ip =~ /^$cfg_ignore_ip/){
	# ���������� ����������.
	exit(0);
    }elsif ($cfg_firewall_type eq "ipfw"){
	$firewall_ipfw_cmd =~ s/\%IP\%/$in_ip/gi;
	system($firewall_ipfw_cmd);
    } elsif ($cfg_firewall_type eq "iptables"){
	$firewall_iptables_cmd =~ s/\%IP\%/$in_ip/gi;
	system($firewall_iptables_cmd);
    } elsif ($cfg_firewall_type eq "htaccess"){
	if (open(HTACCESS, ">>$firewall_htaccess_file")){
	    flock(HTACCESS,2);
	    $in_ip =~ s/\./\\./g;
	    my $cur_time_str = localtime();
	    print HTACCESS qq~\n# Auto blocked at $cur_time_str\n~;
	    print HTACCESS qq~RewriteCond %{REMOTE_ADDR} $in_ip\n~;
	    print HTACCESS qq~RewriteRule .* / [F]\n~;
	    close(HTACCESS);
	}
    } else {
	die "Incorrect firewall type '$cfg_firewall_type'\n";
    }
}