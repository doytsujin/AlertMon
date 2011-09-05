#!/usr/bin/perl
# ��. DoS_prevent.txt
# ��� ������ ���� ��������

my $cfg_cache_dir="/usr/local/alertmon/cache";

my %cfg_apache_server = (
    "apache1" => {
	log_path => "/usr/local/apache/logs/",
	htaccess_file => "/usr/local/apache/htdocs/.htaccess";
	log_file_mask => "^access_.*";
	    },
);
# ����� ������� 10 ���.
# ����� �������� � ������ IP (act:ip-block).
my $cfg_max_one_ip
# ����� �������� ������ CGI � ����������� ����������� (act:cgi-cache).
my $max_one_cgi_param_requiets 
# ����� �������� ������ CGI (act:cgi-limit).
my $max_one_cgi_requiets 
# ����� �������� ������ �� CGI URL (act:url-rate-limit).
my $max_one_url_requiets 
# ����� �������� cgi-�������� (act:all-rate-limit).
my $max_cgi_requiets 
# ����� �������� (act:all-rate-limit).
my $max_all_requests 
# ����� ������ IP �� �� ������ (act:all-rate-limit).
my $max_diff_ip 
# ������� �� max_traffic ��� ������ URL (act:url-rate-limit).
my $max_traffic_url_percent 
# ������������ �������� ������� (act:all-rate-limit).
my $max_traffic 
