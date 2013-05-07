require "mongo"

require "hq/tools/check-script"
require "hq/tools/future"
require "hq/tools/getopt"
require "hq/tools/thread-pool"

module HQ
module MongoDB
module CheckCollectionSize

class Script < Tools::CheckScript

	def initialize
		super
		@name = "MongoDB collection size"
	end

	def process_args

		@opts, @args =
			Tools::Getopt.process ARGV, [

				{ :name => :timeout,
					:default => 10,
					:regex => /[0-9]+(\.[0-9]+)?/,
					:convert => :to_f },

				{ :name => :hostname,
					:default => "localhost" },

				{ :name => :port,
					:default => 27017,
					:convert => :to_i },

				{ :name => :total_warning,
					:convert => method(:decode_bytes),
					:required => true },

				{ :name => :total_critical,
					:convert => method(:decode_bytes),
					:required => true },

				{ :name => :unsharded_warning,
					:convert => method(:decode_bytes),
					:required => true },

				{ :name => :unsharded_critical,
					:convert => method(:decode_bytes),
					:required => true },

				{ :name => :efficiency_warning,
					:convert => :to_i,
					:required => true },

				{ :name => :efficiency_critical,
					:convert => :to_i,
					:required => true },

				{ :name => :efficiency_size,
					:convert => method(:decode_bytes),
					:required => true },

				{ :name => :verbose,
					:boolean => true },

				{ :name => :threads,
					:convert => :to_i,
					:default => 20 },

				{ :name => :breakdown,
					:boolean => true }

			]

		@args.empty? \
			or raise "Extra args on command line"

	end

	def get_namespace_stats db_name, namespace_name

		mongo =
			Thread.current[:mongo]

		db =
			mongo.db(db_name)

		stats =
			db.command({
				"collStats" => namespace_name
			})

		return {
			:data_size => stats["size"],
			:storage_size => stats["storageSize"],
		}

	end

	def get_collection_stats db_name, coll_name

		mongo =
			Thread.current[:mongo]

		db =
			mongo.db(db_name)

		# get collection stats

		coll_stats =
			get_namespace_stats \
				db_name,
				coll_name

		# get index stats

		prefix_size =
			db_name.length + 1 + coll_name.length + 1

		index_names =
			db["system.indexes"] \
				.find({
					"ns" => "#{db_name}.#{coll_name}",
				})
				.map { |row| row["name"] }

		index_stats = Hash[
			index_names.map do
				|index_name|
				[
					index_name,
					get_namespace_stats(
						db_name,
						"#{coll_name}.$#{index_name}")
				]
			end
		]

		# work out overall figures

		total_stats =
			index_stats.values.reduce coll_stats do
				|memo, object|
				{
					:data_size =>
						memo[:data_size] + object[:data_size],
					:storage_size =>
						memo[:storage_size] + object[:storage_size],
				}
			end

		# get sharding info

		config_db =
			mongo.db("config")

		collection_row =
			config_db["collections"]
				.find_one({
					"_id" => "#{db_name}.#{coll_name}"
				})

		sharding_enabled =
			collection_row && collection_row["key"] ? true : false

		# and return

		return {
			:total => total_stats,
			:collection => coll_stats,
			:indexes => index_stats,
			:sharding_enabled => sharding_enabled,
		}

	end

	def perform_checks

		# connect

		mongo =
			Mongo::Connection.new \
				@opts[:hostname],
				@opts[:port]

		# stats to collect

		@biggest = 0

		@warning_count = 0
		@critical_count = 0
		@ok_count = 0
		@error_count = 0

		# thread pool

		@thread_pool =
			Tools::ThreadPool.new

		@thread_pool.init_hook do

			Thread.current[:mongo] =
				Mongo::Connection.new \
					@opts[:hostname],
					@opts[:port]

		end

		@thread_pool.start \
			@opts[:threads]

		# get collection names (in parallel)

		collection_name_futures =
			mongo.database_names.map do
				|database_name|

				Tools::Future.new @thread_pool, database_name do
					|database_name|

					mongo =
						Thread.current[:mongo]

					mongo.db(database_name)
						.collection_names
						.map {
							|collection_name|
							[ database_name, collection_name ]
						}

				end

			end

		collection_names =
			collection_name_futures
				.map {
					|future|
					future.get
				}
				.flatten(1)

		# analyse collections (in parallel)

		collection_stat_futures = Hash[
			collection_names.map do
				|database_name, collection_name|

				future =
					Tools::Future.new \
						@thread_pool,
						database_name,
						collection_name do
							|database_name, collection_name|
							get_collection_stats(
								database_name,
								collection_name)
						end

				[
					"#{database_name}.#{collection_name}",
					future,
				]

			end
		]

		collection_stat_futures.each do
			|full_collection_name, future|

			stats = future.get

			analyse_collection \
				full_collection_name,
				stats

		end

		# results

		critical "#{@critical_count} critical" \
			if @critical_count > 0

		warning "#{@warning_count} warning" \
			if @warning_count > 0

		unknown "#{@error_count} errors" \
			if @error_count > 0

		message "biggest is #{byte_size @biggest}"

	end

	def analyse_collection full_collection_name, stats

		# work out total efficiency

		total_data_size =
			stats[:total][:data_size]

		total_storage_size =
			stats[:total][:storage_size]

		total_efficiency =
			total_data_size * 100 / total_storage_size

		sharding_enabled =
			stats[:sharding_enabled]

		# work out critical and warning status

		critical = false
		warning = false

		if total_data_size >= @opts[:total_critical]
			critical = true
		elsif total_data_size >= @opts[:total_warning]
			warning = true
		end

		if sharding_enabled == false
			if total_data_size >= @opts[:unsharded_critical]
				critical = true
			elsif total_data_size >= @opts[:unsharded_warning]
				warning = true
			end
		end

		if total_data_size >= @opts[:efficiency_size]
			if total_efficiency < @opts[:efficiency_critical]
				total_critical = true
			elsif total_efficiency < @opts[:efficiency_warning]
				warning = true
			end
		end

		# update counters

		if critical
			@critical_count += 1
		elsif warning
			@warning_count += 1
		else
			@ok_count += 1
		end

		@biggest = total_data_size \
			if total_data_size > @biggest

		# output message(s)

		if @opts[:verbose] && (critical || warning)

			sharding_string =
				if sharding_enabled
					"sharded"
				else
					"unsharded"
				end

			status_string =
				if critical
					"*** CRITICAL ***"
				elsif warning
					"warning"
				else
					"ok"
				end

			print_n \
				"%s %s %d%% %s %s" % [
					"#{full_collection_name}",
					byte_size(total_storage_size),
					total_efficiency,
					sharding_string,
					status_string,
				]

			if @opts[:breakdown]

				collection_data_size =
					stats[:collection][:data_size]

				collection_storage_size =
					stats[:collection][:storage_size]

				collection_efficiency =
					collection_data_size * 100 / collection_storage_size

				print_n \
					"  data %s %d%%" % [
						byte_size(collection_storage_size),
						collection_efficiency,
					]

				stats[:indexes].each do
					|index_name,
					index_stats|

					index_data_size =
						index_stats[:data_size]

					index_storage_size =
						index_stats[:storage_size]

					index_efficiency =
						index_data_size * 100 / index_storage_size

					print_n \
						"  %s %s %d%%" % [
							index_name,
							byte_size(index_storage_size),
							index_efficiency,
						]

				end

			end

		end

	end

	def print_n str
		puts "#{str}\n"
	end

	def byte_size bytes

		size = bytes.to_f

		series = [
			"bytes",
			"kilobytes",
			"megabytes",
			"gigabytes",
			"terabytes",
		]

		while size >= 1024
			size /= 1024
			series.shift
		end

		unit = series.shift

		return "%.3g %s" % [ size, unit ]

	end

	def decode_bytes string

		case string

			when /^([0-9]+)b?$/

			when /^([0-9]+)k$/
				$1.to_i * 1024

			when /^([0-9]+)m$/
				$1.to_i * 1024 * 1024

			when /^([0-9]+)g$/
				$1.to_i * 1024 * 1024 * 1024

			when /^([0-9]+)t$/
				$1.to_i * 1024 * 1024 * 1024 * 1024

			else
				raise "Invalid size: #{string}"

		end

	end

end

end
end
end
