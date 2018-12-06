#!/opt/ruby_2.4.0/bin/ruby -w
# coding: utf-8
# 
# 用来完成接受应用的报道信息，并主动发送报警信息。
begin
	require 'yaml'
	require 'socket'               # 获取socket标准库
	require 'net/smtp'
	require_relative "color"

	require 'net/http'
	require 'uri'
	require 'json'

## 是否发动告警
	is_alert='N'
########### 使用配置文件
	YAML_FILE             ="#{__dir__}/config/config.yml"
	配置文件               =YAML.load(File.open(YAML_FILE,'r'));
	say_hello_log         = 配置文件["master_log"]["say_hello"]
	process_hash_info_log = 配置文件["master_log"]["process_hash_info"]
	告警邮件地址           = 配置文件["alert_email"]
	初始连接延迟           = 配置文件["init_connect_delay"].to_i
	say_hello延迟         = 配置文件["say_hello_delay"].to_i
	say_hello_重试次数    = 配置文件["say_hello_fails_retry"].to_i
	say_hello_重试延迟    = 配置文件["say_hello_fails_retry_delay"].to_i
	hash表检查延迟        = 配置文件["hash_table_check"].to_i
	本地IP                = 配置文件["local_ip"]
	远端IP                = 配置文件["remote_ip"]
	程序最长超时时间       = 配置文件["process_max_timeout"].to_i

	web_api_url          = 配置文件["url"]
	web_api_switch       = 配置文件["url_send"]
	web_api_rel_user     = 配置文件["rel_user"]

	send_mail_switch    = 配置文件["email_send"]

########### 日志记录
	say_hello_log = File.new(say_hello_log,  "a+")
	process_hash_info_log = File.new(process_hash_info_log,  "a+")
###########

	本地IP=本地IP
	本地端口=18000
	对端IP=远端IP
	对端端口=18001
	重试max=say_hello_重试次数
	线程list=[]
	接受消息IP=本地IP
	接受消息端口=18002
	消息接受器 = TCPServer.open(接受消息IP,接受消息端口)
	服务器 = TCPServer.open(本地IP,本地端口)

	##########################
	#用来接受say hello的消息
	##########################
	线程list << Thread.new {
	  loop {
	    Thread.start(服务器.accept) { |client|
	        abc=client.gets
	        say_hello_log.syswrite("MASTER接受到socket信息#{abc}")
	        client.close
	    }
	  }
	}


	##########################
	# 初始化双方的连接
	##########################
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



	##########################
	# 发送hello消息
	##########################
	线程list << Thread.new {
	  	loop {
		    begin
		    	客户端连接=TCPSocket.open(对端IP, 对端端口)
		    	客户端连接.puts("master say hello -#{Time.new}-#{Time.new.nsec}")
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
					#sleep 1
		        else
		        	中断期=3600*24*365*10
		        	puts "say_hello线程进入长期中断"
		        	sleep 中断期  #让程序进入一个漫长的中断期
		        end
		    end    
	  	}
	}

	##########################
	# 接受进程信息，更新hash表
	##########################

	hello_table=Hash.new
	线程list << Thread.new {
	  	loop {
		    Thread.start(消息接受器.accept) { |client|
		        hello_msg=client.gets.chomp
		        process_hash_info_log.syswrite("接受到#{hello_msg}\n")
		        hello_array=hello_msg.split(/-----/)
		        hello_ip      = hello_array[0]
		        hello_program = hello_array[1]
		        hello_pid     = hello_array[2]
		        hello_time    = Time.new
		        hello_table["#{hello_ip}-#{hello_program}-#{hello_pid}"]=hello_time
		        process_hash_info_log.syswrite("hash表:#{hello_table}\n")
		        client.close
		    }
		}
	}

	##########################
	# 检查是否有超时的进程并报警
	##########################

	线程list << Thread.new {
	  	loop {
	  		puts "------------------------------"
	  		hello_table.each_pair {|hello_table_k,hello_table_v|
	  			落后时差=Time.new - hello_table_v
	  			puts "#{hello_table_k} #{落后时差}"
	  			if 落后时差 >= 程序最长超时时间
	  				puts "#{多色显示("发现超时进程 : #{hello_table_k}","黄色","蓝色","")}";

	  				if send_mail_switch
	  					begin
					        Net::SMTP.start('127.0.0.1', 25) { |smtp|
								smtp.open_message_stream('process@ruby', ['734300535@qq.com']) { |f|
									f.puts '=?utf-8?B?Subject: 服务告警?='
									f.puts
									f.puts '服务：进程长时间未报告'
									f.puts "程序信息：    #{hello_table_k}"
									f.puts "上次报道时间：#{hello_table_v}"
								}
								puts "#{多色显示("通知邮件发送完毕","黄色","蓝色","")}"
			  				}		  						
	  					rescue Exception => e
	  						puts e.message
	  						sleep 2
	  						retry	  						
	  					end

	  				end

	  				if web_api_switch
	  					begin
							Net::HTTP.post_form  URI(web_api_url),{"时间" => "#{Time.new.to_s[0,19]}" , "来源" => "process-check" , "内容" => "#{hello_table_k} 超时","确认" => "N","关联用户" => "#{web_api_rel_user}"}
							puts "#{多色显示("web-api通知发送完毕","黄色","蓝色","")}"
	  					rescue Exception => e
	  						puts e.message
	  						sleep 2
	  						retry
	  					end

					end

			        hello_table.delete("#{hello_table_k}")
			    else
			    	nil
			    	#puts "没有超时"
	  			end
	  		}
	  		sleep hash表检查延迟
		}
	}

	##########################
	# 命令调试
	##########################
	线程list << Thread.new {
		控制台 = UDPSocket.new
		控制台.bind("127.0.0.1", 4913)
		loop {
			udp数组 = 控制台.recvfrom(1024) #接受两百字节的数据
			udp数组_命令 = udp数组[0].force_encoding("UTF-8")
			p udp数组_命令
			begin
				eval udp数组_命令
			rescue Exception => e
				puts "未能正确执行,执行异常"
			end
			
		}
	}
	##############################
	# 等待所有线程的执行
	##############################
	线程list.each {|thr|
	  thr.join
	}
rescue Exception => e
	puts e.message
end
