#!/usr/bin/perl -w
# alertmon package v.3, http://www.opennet.ru/dev/alertmon/
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>
#
# � ������������ snmpd ������������� ���
# exec .1.3.6.1.4.1.2021.57 alertmon /usr/local/alertmon/snmp_export.pl
#
# ������ ����� ���������� � ������������ ����� �����������, ����� snmp_lookup.pl
# 
# ���������:
# .1.3.6.1.4.1.2021.57.101.1 - ����������� ^ ����� ������
# .1.3.6.1.4.1.2021.57.101.2 - ����������� ^ ����� �������
# .1.3.6.1.4.1.2021.57.101.3 - ����������� ^ ����� id
# .1.3.6.1.4.1.2021.57.101.4 - ����������� ^ ������� ��������
# .1.3.6.1.4.1.2021.57.101.5..N - ������ ���������������� �������� ������ (���������� ^):
# 	���_�����.id
#	�����_�_���������_����
#	�����_���������
#	�����_epoch
#       ���_�����
#
##############################################################################
my $cfg_log_dir = "/usr/local/alertmon/toplogs";
my ($glob_graph_name, $glob_graph_type, $glob_graph_id, $glob_graph_counter);
my ($cur_alert);

if ( defined $ARGV[0]){
    $cfg_log_dir = $ARGV[0];
}
if (! -d $cfg_log_dir){
    die "$cfg_log_dir not found.\nUsage: snmp_export.pl <���� � ���������� � ������ alertmon>\n";
}

# �������� ��� ��������� ��������.
open (TOP, "<$cfg_log_dir/snmp.status") || print STDERR "Can't open top file: $cfg_log_dir/snmp.status\n";
flock(TOP, 2);
    $glob_graph_name = <TOP> || "";
    $glob_graph_type = <TOP> || "";
    $glob_graph_id = <TOP> || ""; 
    $glob_graph_counter = <TOP> ||"";
close(TOP);

print remove_syschar($glob_graph_name);
print remove_syschar($glob_graph_type);
print remove_syschar($glob_graph_id);
print remove_syschar($glob_graph_counter);

# ������ �������.
opendir (LOGDIR, "$cfg_log_dir");
while ($cur_alert = readdir(LOGDIR)){
    if ($cur_alert =~ /^([^\/]+)\.act$/){
	my $tmp;
	my $alert_comment;
	open (ALERT, "<$cfg_log_dir/$cur_alert") || print STDERR "Can't open .act file ($cur_alert).\n";
	$tmp = <ALERT>;
	$tmp = <ALERT>;	
	$tmp = <ALERT>;	
	$tmp = <ALERT>;
	$alert_comment = <ALERT>;
	close(ALERT);
	print remove_syschar($alert_comment);
    }
}
closedir(LOGDIR);
exit 0;

#########################################################################
# ������ ��������� �� ":"
sub remove_syschar{
    my ($str) = @_;
    
    $str =~ tr/^/ /;
    $str =~ tr/\t/^/;

    return $str;    
}

