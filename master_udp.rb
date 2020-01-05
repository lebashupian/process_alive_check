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
	require "zlib"
## 是否已经发生报警
	有过报警=false
########### 使用$配置文件
	YAML_FILE             ="#{__dir__}/config/config.yml"
	$配置文件               =YAML.load(File.open(YAML_FILE,'r'));

	say_hello_log         = $配置文件["master_log"]["say_hello"]
	process_hash_info_log = $配置文件["master_log"]["process_hash_info"]
	check_hash_info_log = $配置文件["master_log"]["check_hash_info"]

	$告警邮件地址           = $配置文件["alert_email"]
	send_mail_switch    = $配置文件["email_send"]

	包发送检查延迟         = $配置文件["packet_send_check_delay"].to_i

	say_hello延迟         = $配置文件["say_hello_delay"].to_f
	say_hello_重试次数    = $配置文件["say_hello_fails_retry"].to_i
	say_hello_最大超时    = $配置文件["say_hello_max_timeout"].to_i
	hash表检查延迟        = $配置文件["hash_table_check"].to_i


	本地IP                = $配置文件["local_ip"]
	远端IP                = $配置文件["remote_ip"]
	程序最长超时时间       = $配置文件["process_max_timeout"].to_i

	同步数据本地IP            = $配置文件["data_local_ip"] 
	同步数据本地端口            = $配置文件["data_local_port"] 
	同步数据远端IP            = $配置文件["data_remote_ip"] 
	同步数据远端端口            = $配置文件["data_remote_port"]
	同步数据延迟                = $配置文件["data_sync_delay"].to_f

	web_api_url          = $配置文件["url"]
	web_api_switch       = $配置文件["url_send"]
	web_api_rel_user     = $配置文件["rel_user"]


	角色='null' 



########### 日志记录
	say_hello_log = File.new(say_hello_log,  "a+")
	process_hash_info_log = File.new(process_hash_info_log,  "a+")
	check_hash_info_log = File.new(check_hash_info_log,  "a+")
############
	


	
	本地IP=本地IP
	本地端口=18000
	对端IP=远端IP
	对端端口=18001
	线程list=[]

	接受消息IP=本地IP
	接受消息端口=18002




	udp接受消息=UDPSocket.new
	udp接受消息.bind 接受消息IP , 接受消息端口

	udp同步=UDPSocket.new
	udp同步.bind 同步数据本地IP,同步数据本地端口

	##################
	# 报警函数
	def send_alert_email
		puts "发送报警邮件"
		Net::SMTP.start('127.0.0.1', 25) do |smtp|
			smtp.open_message_stream('process@ruby', [$告警邮件地址]) do |f|
				f.puts '=?utf-8?B?Subject: 服务告警?='
				f.puts
				f.puts '服务：rubycheck 双活失败'
				f.puts '所在主机：37'
			end
		end
		puts "发送完毕"
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

	#添加vip



	udp对象 = UDPSocket.new
	udp对象.bind 本地IP,本地端口
	udp_hello_data = {"接力数字"=>"0","接力超时"=>Time.new}
	udp对象.send "#{udp_hello_data["接力数字"]}" ,0, 对端IP ,对端端口


	线程list << Thread.new {
		loop {
			begin
				abc = udp对象.recvfrom(1000)

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
				sleep say_hello_最大超时
				#puts "落后时差 -> #{落后时差}"
				say_hello_log.syswrite("落后时差 -> #{落后时差}\n")
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
				#udp对象.send "#{udp_hello_data["接力数字"]}" ,0, 对端IP ,对端端口
			end
		}
	}



	##########################
	# 接受进程信息，更新hash表
	##########################

	消息表=Hash.new
	线程list << Thread.new {
		loop {
			进程消息 = udp接受消息.recvfrom(2048)
			进程消息 = 进程消息[0].chomp
			process_hash_info_log.syswrite("接受到#{进程消息}\n")
	        消息数组=进程消息.split(/-----/)
	        消息_ip      = 消息数组[0]
	        消息_程序     = 消息数组[1]
	        消息_pid     = 消息数组[2]
	        消息时间    = Time.new
	        消息表["#{消息_ip}-#{消息_程序}-#{消息_pid}"]=消息时间



	        process_hash_info_log.syswrite("hash表:#{消息表}\n")
		}
	}

	线程list << Thread.new {
		loop {
			if 角色 == 'master'
	        	json数据=JSON.generate(消息表)
	        	json压缩数据 = Zlib::Deflate.deflate(json数据)
				udp同步.send json压缩数据 ,0, 对端IP ,对端端口
			end
				sleep 同步数据延迟
		}
	}

	##########################
	# 检查是否有超时的进程并报警
	##########################

	线程list << Thread.new {
	  	loop {
	  		循环时间=Time.new.to_s[0,19]
	  		#puts "------------------------------"
	  		check_hash_info_log.syswrite("----------------------------------------\n")
	  		hello_table.each_pair {|hello_table_k,hello_table_v|
	  			落后时差=Time.new - hello_table_v
	  			#puts "程序：#{hello_table_k} 时差：#{落后时差} 阀值：#{程序最长超时时间}"
	  			check_hash_info_log.syswrite("#{循环时间} 程序：#{hello_table_k} 时差：#{落后时差} 阀值：#{程序最长超时时间}\n")
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
			rescue
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
