#!/opt/ruby_2.2.3/bin/ruby -w
# coding: utf-8
# 
# 主要功能是用来检测master进程是否存在，如果不存在会发送邮件
begin
	require 'yaml'
	require 'socket'               # 获取socket标准库
	require 'net/smtp'
	require_relative "color"
####################
## 是否发动告警
	is_alert='N'
########### 使用配置文件
	YAML_FILE="#{__dir__}/config/config.yml"
	配置文件=YAML.load(File.open(YAML_FILE,'r'));
	say_hello_log=配置文件["slave_log"]["say_hello"]
	告警邮件地址=配置文件["alert_email"]
	初始连接延迟=配置文件["init_connect_delay"].to_i
	say_hello延迟=配置文件["say_hello_delay"].to_i
	say_hello_重试次数    = 配置文件["say_hello_fails_retry"].to_i
	say_hello_重试延迟=配置文件["say_hello_fails_retry_delay"].to_i

	本地IP                = 配置文件["local_ip"]
	远端IP                = 配置文件["remote_ip"]	
########### 日志记录
	say_hello_log = File.new(say_hello_log,  "a+")
############
	本地IP=本地IP
	本地端口=18001
	对端IP=远端IP
	对端端口=18000
	重试max=say_hello_重试次数
	线程list=[]
	服务器 = TCPServer.open(本地IP,本地端口)
	线程list << Thread.new {
	  loop {
	    Thread.start(服务器.accept) { |client|
	        abc=client.gets
	        say_hello_log.syswrite("SLAVE接受到socket信息#{abc}")
	        client.close
	    }
	  }
	}
	puts "开启网络服务"
	print "开始连接对端..."
	begin
	  客户端连接=TCPSocket.open(对端IP, 对端端口)
	rescue
	  print "..."
	  sleep 初始连接延迟
	  retry  
	end
	print "\n完成和对端的连接\n"
	线程list << Thread.new {
	  	loop {
		    begin
		    	客户端连接=TCPSocket.open(对端IP, 对端端口)
		    	客户端连接.puts("slave say hello -#{Time.new}-#{Time.new.nsec}")
		    	客户端连接.close
		    	sleep say_hello延迟
		    rescue
		      	if 重试max > 0
		        	重试max -= 1
		        	puts "say hello 发送重试"
		        	sleep say_hello_重试延迟
		        	retry
		      	elsif 重试max <= 0 and is_alert == 'N'
					Net::SMTP.start('127.0.0.1', 25) do |smtp|
						smtp.open_message_stream('process@ruby', [告警邮件地址]) do |f|
							f.puts '=?utf-8?B?Subject: 服务告警?='
							f.puts
							f.puts '服务：rubycheck 双活失败'
							f.puts '所在主机：37'
						end
					end
					is_alert='Y'
		        	puts "超过重试阀值，已经发送告警"
		        	exit
		        end 
		    end
	  	}
	}

	线程list.each {|thr|
	  thr.join
	}
rescue Exception => e
	puts e.message
end
