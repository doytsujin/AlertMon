#!/usr/bin/perl -w
# ���������� �����.
# ����� ������������: 
#    find ./top_logs -type f -maxdepth 4 -mtime +20 -exec rm -f {} \;
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>

use strict;
use File::Path;

# ������� ���� �������� ��������� ����.
my $cfg_log_timetolive = 15;

# �� ������� ���� ����������� �������� ��� �� ������� �����������.
my $cfg_alertlist_timetolive = 30;

# ����� ������� ���� �� ������� �����������
my $cfg_alertlist_rotations = 3;

# ���� � ����� ���������� � ������.
my $cfg_toplogs_dir="/usr/local/alertmon/toplogs";

###############################################################################


my $cfg_alertlist_file = "$cfg_toplogs_dir/alertlist.log";
$cfg_log_timetolive = $cfg_log_timetolive * 24 * 60 * 60;
my $now_time = time();


# -------------------------------------------------
# ����� ������ ������� � ����������� � ������������.

opendir( LOGS, "$cfg_toplogs_dir") || die "Cannot open $cfg_toplogs_dir directory !";

# ������� ���������� � ������.    
while (my $dir_item = readdir LOGS){
    if (-d "$cfg_toplogs_dir/$dir_item" && $dir_item =~ /^\d\d\d\d$/){
        my $act_month_cnt = clear_year("$cfg_toplogs_dir/$dir_item");
	if ($act_month_cnt == 0){
	    # ���������� ������ ������� ��.
	    rmtree("$cfg_toplogs_dir/$dir_item");
	}
    }
}
closedir(LOGS);

# -------------------------------------------------
# ������ ��������� ���������� ����.


exit(0);

#############################################################################
# ������ ���������� � ��������.
sub clear_year {
    my ($year_dir) = @_;
    my $act_month_cnt = 0; # ����� �������������� ������� ����������.
    opendir( MLOGS, "$year_dir") || die "Cannot open $year_dir directory !";
    while (my $dir_item = readdir MLOGS){
        if (-d "$year_dir/$dir_item" && $dir_item =~ /^\d+$/){
	    my $act_day_cnt = clear_month("$year_dir/$dir_item");
	    if ($act_day_cnt == 0){
		# ���������� ������ ������� ��.
		rmtree("$year_dir/$dir_item");
	    } else {
		$act_month_cnt++;
	    }
	}
    }
    closedir(MLOGS);
    return $act_month_cnt;
}

#############################################################################
# ������ ���������� � �����.
sub clear_month {
    my ($month_dir) = @_;
    my $act_day_cnt = 0; # ����� �������������� ������� ����������.
    opendir( DLOGS, "$month_dir") || die "Cannot open $month_dir directory !";
    while (my $dir_item = readdir DLOGS){
        if (-d "$month_dir/$dir_item" && $dir_item =~ /^\d+$/){

	    my $mtime = (stat("$month_dir/$dir_item"))[9];

	    if ($cfg_log_timetolive + $mtime < $now_time){
		rmtree("$month_dir/$dir_item");
	    } else {
		$act_day_cnt++;
	    }
	}
    }
    closedir(DLOGS);
    return $act_day_cnt;
}

#sub rmtree{
#    my ($test) = @_;
#    print "rm $test\n";
#}

