#!/usr/bin/perl
# alertmon package v.3, http://www.opennet.ru/dev/alertmon/
# Copyright (c) 1998-2005 by Maxim Chirkov. <mc@tyumen.ru>
#
# apache_mon.pl <log_key> <la_mon.la_name>
# ������ ��� ���������� ������ � DoS � DDoS ������� �� web ����.
# log_key - ���� �� ���� � ����������� �������������� �����.
# la_mon.la_name - ��������� ����� alertmon ��� �������� Load Average (LA).
#                  ���� la_mon.la_name = N.N - �� ������� LA � ������� 
#  	           �������������� � ������������ N.N ��� ���������� ���������� 
#                  ��������, �� ������ ������� ��� alertmon.

# ���������:
# ���� LA � �������� �����, �� ���������, � ������ ��������� ������ ����� ������������ ����������.

# C����� ��� top ���� (������ ���� �������� LA �����):
# - top ���� IP � ���� ������� � ��������� �������.
# - top ���� URL � ����.

# ���� IP �� top'� ������� �� ������������ ����� � user agent �� ��������� ��� ����� ����������, �� ��������� �� ���������� ������� ����� htaccess.
# ���������� ������������ ����� �� ���������� ������� ��������������� IP �������� ������������.
# ���� URL �� ���� ������� �� ������� ������ ��������� ��� ����� ������������ �������, �� �������� ���� URL ����� ������� � ������������� �� ���� �������� ����� mod_rewrite ������� � .htaccess.
# ���������� ������������ ��� ������ 


# ������ �������������� ��� ������.
my %cfg_targets = (
    "opennet" => {
	# ��� apache
	"log_path" => "/usr/local/apache/logs/opennet_access",
	# .htaccess ���� ��� ����������, ��������, ���� ��������� �������������.
	# ����������� ��������� (��� ������� "RewriteEngine On") ���������� �������� � .htaccess.raw
	"htaccess_file" => "/home/opennet/htdocs/.htaccess",
	# ������� (1 = 100%) ����� �������� ��� ������� IP ����� ������������,
	# �� 100% ��������� ����� �������� ������ ����� ������ ��������� � ������� �������.
	"ip_block_percent" => 0.5, # 50%, ������ �� IP ������ 2 �������
	# ������� ����� ��������, ��� ������� ���������� ����� ������.
	"ip_unblock_percent" => 0.05, # 5%
	# ������� ������ ����������� URL ����� �������.
	"url_cache_percent" => 1, # 100%
	# ������� ������ ����������� ����� �������.
	"url_cache_del_percent" => 0.7, # 70%
	# ����� ��� ����������� ���� ������� ������� ������� ����������.
	"url_cache_mask" => '\.(shtml\?|cgi)', # + php, phtml
	# ��������� ���� ��������� ����������� ����� ��������������� ��������.
	"url_cache_store_dir" => "/home/opennet/htdocs/static",
	# �������� ������.
	"url_cache_site" => "http://www.opennet.ru",
    },
);

# ����� ��� ���������� ��������� ������, ����� �� ������������� �� �� ������.
my $cfg_skip_ua_mask='(google|yandex|rambler|aport|msn\.com|altavista\.com|lycos\.com|mail\.ru)';

# ���������� ��� �������� ������������� ������-�����.
# ������ ������ �����: <target>.apache_mon, ������ - ���� ���� ����� Storable.
my $cfg_log_dir = "/usr/local/alertmon/toplogs"; 

# ���� ��� ������ ���������� ����������.
my $cfg_debug_log_file="$cfg_log_dir/apache_mon.log";
my $cfg_debug_flag=1;

# ������� ��� ������������ �������� ��� ����, ����������� ��� "������� ���� url"
my @cfg_url_fetch_command= ("/usr/local/bin/curl", "-s", "--connect-timeout", "3", "--max-time", "20", "--user-agent", '"Mozilla/4.0 (Alertmon)"', "-o");

# ������������ ������ top-����� ��� ������ �� ���������� ������.
my $cfg_max_hash_size=50000;

use strict;
use Storable;
use Digest::MD5; 

# ��� �� �������� ����������.
#  seek - ��c������ ������� � ����.
# blocked_ip => { ip => "user_agent"} - ��� ��������������� IP.
# cached_url => { url => "static_hash"}- ��� ��������������� URL.
my $status_hash = {};
my $hits_cnt=0;

###########################################################################
if (! defined $ARGV[1]){
    die "Usage: apache_mon.pl <log_key> <la_mon.la_name>\n";
}
# ������ ���������
my $in_target = $ARGV[0];
$in_target =~ s/[^\d\w_]//g;

my $in_la_id = $ARGV[1];
$in_la_id =~ s/[^\d\w\-\_\.]//g;

my $allow_block_flag = 0;

if ($in_la_id =~ /^\d+\.\d+$/){
    # ���������� ������� LA �� 5 �����.
    use Sys::CpuLoad;
    if ((Sys::CpuLoad::load())[1] > $in_la_id){
	$allow_block_flag = 1;
    }
}elsif (-f "$cfg_log_dir/$in_la_id.act"){
    # LA ���� ����������, ����� �����������.
    $allow_block_flag = 1;
}

if (! defined $cfg_targets{$in_target}){
    die "Tagret '$in_target' not defined in \%cfg_targets";
}

if (! -f $cfg_targets{$in_target}{"log_path"}){
    die "Apache log '$cfg_targets{$in_target}{log_path}' not found";
}

if (! -f "$cfg_targets{$in_target}{htaccess_file}.raw"){
    die "Raw .htaccess file '$cfg_targets{$in_target}{htaccess_file}.raw' not found";
}

# ������ ��� �� ��������, ���� �� ������ ������� � �������.
if (-f "$cfg_log_dir/$in_target.alache_log"){
    $status_hash = Storable::retrieve("$cfg_log_dir/$in_target.alache_log");
}
if (ref($status_hash) ne "HASH" || ! defined $status_hash->{"seek"}){
    # ���������� ������ ����, ������� ��� � �������.
    $status_hash={};
    $status_hash->{"seek"} = (stat($cfg_targets{$in_target}{"log_path"}))[7];
} else {
    my %top_ip=(); # cnt, ua
    my %top_url=();

    # ������ ���.
    parse_apache_log($status_hash, \%{$cfg_targets{$in_target}}, \%top_ip, %top_url, $allow_block_flag);

    # ���������� ����� � ������� ������� ��������.
    my $period_time = time() - (stat("$cfg_log_dir/$in_target.alache_log"))[9];

    #------------------------------
    # ������������� ������ ������� ����������.    
    # IP
    foreach my $blocked_ip (%{$status_hash->{"blocked_ip"}}){
	if (defined $top_ip{$blocked_ip} 
	    && $top_ip{$blocked_ip}{"cnt"} > $period_time * $cfg_targets{$in_target}{"ip_unblock_percent"}){
	
	    # ���������� �����������.
	    not $cfg_debug_flag or debug_log("IP continue $blocked_ip $top_ip{$blocked_ip}{cnt} per $period_time");
	} else {
	    # ���������� ����������.
	    delete($status_hash->{"blocked_ip"}{$blocked_ip});
	    not $cfg_debug_flag or debug_log("IP remove $blocked_ip $top_ip{$blocked_ip}{cnt} per $period_time");
	}
    }    
    # URL
    foreach my $cached_url (%{$status_hash->{"cached_url"}}){
	if (defined $top_url{$cached_url} 
	    && $top_url{$cached_url} > $period_time * $cfg_targets{$in_target}{"url_cache_del_percent"}){
	
	    # ���������� ����������
	    not $cfg_debug_flag or debug_log("URL continue $cached_url per $period_time");
	} else {
	    # ������� ���� ����.
	    if (-f "$cfg_targets{$in_target}{url_cache_store_dir}/$status_hash->{cached_url}{$cached_url}.html"){
		unlink("$cfg_targets{$in_target}{url_cache_store_dir}/$status_hash->{cached_url}{$cached_url}.html");
	    }
	    # ���������� �����������.
	    delete($status_hash->{"cached_url"}{$cached_url});
	    not $cfg_debug_flag or debug_log("URL remove $cached_url per $period_time");
	}
    }    

    #------------------------------
    # ��������� ������� � ������� �����������.
    if ($allow_block_flag == 1){
	# IP
	foreach my $cur_ip (reverse sort { $top_ip{$a}{"cnt"} <=> $top_ip{$b}{"cnt"} } keys %top_ip){

	    if ($top_ip{$cur_ip}{"cnt"} >= $period_time * $cfg_targets{$in_target}{"ip_block_percent"}){
		# ����� �����������.
		if ($top_ip{$cur_ip}{"ua"} !~ /$cfg_skip_ua_mask/o){
		    # IP �� ����������.
		    if (! defined $status_hash->{"blocked_ip"}{$cur_ip}){
			# � ������� �� ����������.
			$status_hash->{"blocked_ip"}{$cur_ip} = $top_ip{$cur_ip}{"ua"};
			not $cfg_debug_flag or debug_log("IP add_block $cur_ip $top_ip{$cur_ip}{cnt} per $period_time");
		    }
		} else {
		    not $cfg_debug_flag or debug_log("IP skip_search $cur_ip per $period_time");
		}
		
	    } else {
		# ���������� ��������, ����� ���������� �������.
		%top_ip=();
		last;
	    }
	}

	# URL
	foreach my $cur_url (reverse sort { $top_url{$a} <=> $top_url{$b} } keys %top_url){

	    if ($top_url{$cur_url} >= $period_time * $cfg_targets{$in_target}{"url_cache_percent"}){
		# ����� ����������.
		    if (! defined $status_hash->{"cached_url"}{$cur_url}){
			# � ������� �� �����������, ���������� ��� ��� URL.
			$status_hash->{"cached_url"}{$cur_url} = Digest::MD5::md5_hex($cur_url);
			not $cfg_debug_flag or debug_log("URL add_cache $cur_url $top_url{$cur_url} per $period_time");
		    }
	    } else {
		# ���������� ��������, ����� ����������� �������.
		%top_url=();
		last;
	    }
	}
    }

    #------------------------------
    # ���������� ����� .htaccess, �� ��������� $status_hash
    open(HTACCESS, ">$cfg_targets{$in_target}{htaccess_file}.new");
    flock(HTACCESS, 2);
    # �������� ��������� .htaccess
    if (open(HTACCESS_RAW, "<$cfg_targets{$in_target}{htaccess_file}.raw")){
	flock(HTACCESS_RAW, 1);
	while(<HTACCESS_RAW>){
	    print HTACCESS $_;
	}
	close (HTACCESS_RAW);
        print HTACCESS "\n# AUTOGENERATED PART ---------\n\n";
    } else {
	print HTACCESS "RewriteEngine On\n\n";
    }
    
    # IP
    foreach my $blocked_ip (%{$status_hash->{"blocked_ip"}}){
	    my $cur_ip = $blocked_ip;
	    $cur_ip =~ s/\./\\\./g;
	    print HTACCESS "\n# IP=$blocked_ip, UA=$status_hash->{blocked_ip}{$blocked_ip}\n";
	    print HTACCESS 'RewriteCond %{REMOTE_ADDR} ^' . "$cur_ip\$\n";
	    print HTACCESS 'RewriteRule .* / [F]' . "\n\n\n";
	    #print HTACCESS 'RewriteCond %{REQUEST_URI} !stop.txt';
	    #print HTACCESS "\n";
	    #print HTACCESS 'RewriteRule .* /stop.txt [R]';
	    $hits_cnt++;
    }    
    # URL
    foreach my $cached_url (%{$status_hash->{"cached_url"}}){
	if (! -f "$cfg_targets{$in_target}{url_cache_store_dir}/$status_hash->{cached_url}{$cached_url}.html"){
	    # ���������� ��� ���� ��� URL
	    if ($cached_url =~ /[\0\n\r\t\'\\]/){
		# ������������ ������� � URL.
		not $cfg_debug_flag or debug_log("Bogus URL ($cached_url), skipping.");
		delete($status_hash->{"cached_url"}{$cached_url});
	    } else {
		my @run_cmd = @cfg_url_fetch_command;
		push @run_cmd, "$cfg_targets{$in_target}{url_cache_store_dir}/$status_hash->{cached_url}{$cached_url}.html"; # ���� ���� ���������.
		push @run_cmd, "'$cfg_targets{$in_target}{url_cache_site}$cached_url'"; # URL
		if (system(@run_cmd) == 0){
		    my ($cur_uri, $cur_args) = split(/\?/, $cached_url);
		    print HTACCESS "\n# URL=$cached_url\n";
		    print HTACCESS 'RewriteCond %{REQUEST_URI} ' . "$cur_uri\n";
		    print HTACCESS 'RewriteCond %{QUERY_STRING} ' . "$cur_args\n";
		    print HTACCESS 'RewriteRule .* ' . "$cfg_targets{$in_target}{url_cache_store_dir}/$status_hash->{cached_url}{$cached_url}.html [L]\n\n\n";
		    $hits_cnt++;
		} else {
		    not $cfg_debug_flag or debug_log("exec failed for url $cached_url, skipping.");
		    delete($status_hash->{"cached_url"}{$cached_url});
		}
	    }
	}
    }
    close(HTACCESS);
    rename("$cfg_targets{$in_target}{htaccess_file}.new", "$cfg_targets{$in_target}{htaccess_file}");
    
}

# ��������� ��� �� ��������.
Storable::store($status_hash,  "$cfg_log_dir/$in_target.alache_log.new");
rename("$cfg_log_dir/$in_target.alache_log.new", "$cfg_log_dir/$in_target.alache_log");
print "$hits_cnt\n";
exit(0);

#############################################################################
# ������ ���������� ���������� � ���
sub debug_log{
    my ($str) = @_;
    my $now_time = time();
    my $now_time_str = localtime($now_time);
    $str =~ tr/\r\n/  /;
    open(LOG, ">>$cfg_debug_log_file");
    flock(LOG, 2);
    print LOG "$now_time_str:$now_time:$str\n";
    close(LOG);
    return 0;
}

##########################################################################
# ������� apache ����.
sub parse_apache_log{
    my ($status_hash, $target_param, $top_ip, $top_url, $allow_block_flag) = @_;


    my $top_ip_cnt=0;
    my $top_url_cnt=0;

    my $log_size = (stat($target_param->{"log_path"}))[7];
    
    if ($log_size < $status_hash->{"seek"}){
        # ��� ����� �������.
        $status_hash->{"seek"} = 0;
    } elsif ($log_size == $status_hash->{"seek"}){
	# ��� �� ���������.
	return 0;
    }


    open(LOG, "<$target_param->{log_path}") || return -1;
    if ($status_hash->{"seek"} > 0){
        if (seek(LOG, $status_hash->{"seek"}, 0) != 1){
	    not $cfg_debug_flag or debug_log("ERROR: seek() return error: $!");
	    die("ERROR:seek() return error: $!");
	}
    }

    while (my $cur_line = <LOG>){
	if ($cur_line =~ /^([\d\.]+).*\"GET (.*) HTTP\/\d\.\d\" \d+ (\d+) \"([^\"]+)\" \"([^\"]+)\"$/){
    	    my $s_ip=$1;
	    my $s_url=$2;
    	    my $s_size=$3;
	    my $s_refer=$4;
	    my $s_user_agent=$5;

	    if ($s_url =~ /$cfg_skip_ua_mask/o){
		# ���������, ����������.
		next;
	    }
	    if ($allow_block_flag == 0){
		# ������ ��������� ���������� � ������� ����������� � �����.
		if (defined $status_hash->{"blocked_ip"}{$s_ip}){
		    $top_ip->{$s_ip}{"cnt"}++;
		}
		if (defined $status_hash->{"cached_url"}{$s_url}){
		    $top_url->{$s_url}++;
		}
	    } else {
		# ������������ ���������, �������� ����������.
		# IP
		if (! defined $top_ip->{$s_ip}){
		    if ($top_ip_cnt < $cfg_max_hash_size){
			$top_ip->{$s_ip}{"ua"} = $s_user_agent;
			$top_ip->{$s_ip}{"cnt"} = 1;
		    }
		    $top_ip_cnt++;
		} else {
		    $top_ip->{$s_ip}{"cnt"}++;
		}

		# URL
		if ($s_url =~ /$target_param->{"url_cache_mask"}/o){
		    if (! defined $top_url->{$s_url}){
			if ($top_url_cnt < $cfg_max_hash_size){
			    $top_url->{$s_url} = 1;
			}
			$top_url_cnt++;
		    } else {
	    		$top_url->{$s_url}++;
		    }
		}
	    }
	}
    }

    $status_hash->{"seek"} = tell(LOG);
    close(LOG);
    return 0;
}
