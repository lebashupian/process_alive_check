#!/opt/ruby_2.2.3/bin/ruby -w
# coding: utf-8
# 
# 主要功能是用来检测master进程是否存在，如果不存在会发送邮件
begin
	require 'yaml'
	require 'socket'               # 获取socket标准库
	require 'net/smtp'
	require_relative "color"


## 是否已经发生报警
	有过报警=false
########### 使用$配置文件
	YAML_FILE="#{__dir__}/config/config.yml"
	$配置文件=YAML.load(File.open(YAML_FILE,'r'));

	say_hello_log=$配置文件["slave_log"]["say_hello"]

	$告警邮件地址=$配置文件["alert_email"]
	send_mail_switch    = $配置文件["email_send"]

	包发送检查延迟         = $配置文件["packet_send_check_delay"].to_i

	say_hello延迟         =$配置文件["say_hello_delay"].to_f
	say_hello_重试次数    = $配置文件["say_hello_fails_retry"].to_i
	say_hello_重试延迟=$配置文件["say_hello_fails_retry_delay"].to_i
	say_hello_最大超时    = $配置文件["say_hello_max_timeout"].to_i

	本地IP                = $配置文件["local_ip"]
	远端IP                = $配置文件["remote_ip"]	

########### 日志记录
	say_hello_log = File.new(say_hello_log,  "a+")
############

	本地IP=本地IP
	本地端口=18001
	对端IP=远端IP
	对端端口=18000
	线程list=[]


	##################
	# 报警函数
	def send_alert_email
		Net::SMTP.start('127.0.0.1', 25) do |smtp|
			smtp.open_message_stream('process@ruby', [$告警邮件地址]) do |f|
				f.puts '=?utf-8?B?Subject 服务告警?='
				f.puts
				f.puts '服务：rubycheck 双活失败'
				f.puts '所在主机：37'
			end
		end
	end

	def 删除vip
		虚拟ip=$配置文件["vip"]
		虚拟netmask=$配置文件["vip_netmask"]
		虚拟ip_dev=$配置文件["vip_dev"]
		`ip addr del "#{虚拟ip}"/"#{虚拟netmask}" dev "#{虚拟ip_dev}"`		
	end

	def 添加vip
		删除vip
		虚拟ip=$配置文件["vip"]
		虚拟netmask=$配置文件["vip_netmask"]
		虚拟ip_dev=$配置文件["vip_dev"]
		`ip addr add "#{虚拟ip}"/"#{虚拟netmask}" dev "#{虚拟ip_dev}"`
	end


	udp对象 = UDPSocket.new
	udp对象.bind 本地IP,本地端口
	udp_hello_data = {"接力数字"=>"0","接力超时"=>Time.new}

	线程list << Thread.new {
		loop {
			begin
				abc = udp对象.recvfrom(1000)
				#puts "循环"				
				#正常情况下，每次重置一下变量
				say_hello_重试次数 = $配置文件["say_hello_fails_retry"].to_i
				有过报警=false
				
				abc = abc[0].to_i
				#puts "收到 #{abc}"
				say_hello_log.syswrite("收到 #{abc}\n")
				if udp_hello_data["接力数字"].to_i >= abc and udp_hello_data["接力数字"].to_i != 0
					#puts "包重复"
					say_hello_log.syswrite("包重复\n")
					next
				end
				udp_hello_data["接力数字"] = abc + 1
				udp_hello_data["接力超时"] = Time.new
				#puts "发送 #{udp_hello_data["接力数字"]}"
				say_hello_log.syswrite("发送 #{udp_hello_data["接力数字"]}\n")
				udp对象.send "#{udp_hello_data["接力数字"]}" ,0, 对端IP ,对端端口
				sleep say_hello延迟
			rescue Exception => e
	  			puts e.message
				retry
			end
		}	
	}

	线程list << Thread.new {
		loop {
			sleep 包发送检查延迟
			落后时差 = Time.new - udp_hello_data["接力超时"]
			if 落后时差 > say_hello_最大超时 and say_hello_重试次数 > 0
				sleep say_hello_重试延迟
				#puts "落后时差 -> #{落后时差},重试"
				say_hello_log.syswrite("落后时差 -> #{落后时差},重试\n")
				udp对象.send "#{udp_hello_data["接力数字"]}" ,0, 对端IP ,对端端口
				say_hello_重试次数 -= 1
			elsif 落后时差 > say_hello_最大超时 and say_hello_重试次数 <= 0
				#puts "重试完全失败"
				say_hello_log.syswrite("重试完全失败\n")
				添加vip
				say_hello_log.syswrite("添加vip\n")
				if send_mail_switch and ! 有过报警
					send_alert_email
					有过报警=true
				end
				#exit 1
			end
		}
	}	

###################################
	线程list.each {|thr|
	  thr.join
	}
rescue Exception => e
	puts e.message
end
