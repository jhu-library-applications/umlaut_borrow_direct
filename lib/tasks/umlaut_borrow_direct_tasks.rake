# desc "Explaining what the task does"
# task :umlaut_borrow_direct do
#   # Task goes here
# end
namespace :umlaut_borrow_direct do
  desc "BD API stats calc"
  task :api_stats, [:filename] do |t, args|

    stats = {
      "FindItem" => {
        :times    => [],
        :errors   => [],
        :timeouts => [],
        :count    => 0
      },
      "RequestItem" => {
        :times    => [],
        :errors   => [],
        :timeouts => [],
        :count    => 0
      }
    }

    if args["filename"] == "stdin"
      file = STDIN
    else
      file = File.open(File.expand_path args[:filename])
    end

    file.each_line do |line|

      if line =~ /BD API log\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)/
        action = $1
        result = $2
        timing = $3
        query  = $4
        
        if timing.present? && (timing.to_f == 0)
          raise "Timing does not look like a float: #{timingf}" 
        end
        timing = timing.to_f

        if ["FindItem", "RequestItem"].include? action
          stats[action][:count] += 1

          if line =~ /(\d\d\d\d-\d\d-\d\d)/

            date = Date.parse($1)

            stats[action][:min_date] = date if stats[action][:min_date].nil? || (date < stats[action][:min_date])
            stats[action][:max_date] = date if stats[action][:max_date].nil? || (date > stats[action][:max_date])
          end

          value_dict = {:action => action, :result => result, :timing => timing, :query => query}

          stats[action][:times] << timing unless timing == 0
          unless result == "SUCCESS"
            (exception_class, exception_message) = result.split("/")
            value_dict[:exception_class]   = exception_class
            value_dict[:exception_message] = exception_message
            if exception_class == "BorrowDirect::HttpTimeoutError"          
              stats[action][:timeouts] << value_dict 
            else
              stats[action][:errors] << value_dict
            end
          end
        else
          puts "Warning, unrecognized action: #{action}"
        end
      end
    end

    ["FindItem", "RequestItem"].each do |action|
      sorted_times = stats[action][:times].sort

      next if sorted_times.empty?
      
      puts "\n\n#{action} API: #{stats[action][:count]} requests from #{stats[action][:min_date]} to #{stats[action][:max_date]}"
      puts "  Timing (not including timeouts):"
      puts "    Min: #{sorted_times.first}"
      puts "    25th %ile: #{percentile sorted_times, 25}"
      puts "    Median: #{percentile sorted_times, 50}"
      puts "    75th %ile: #{percentile sorted_times, 75}"
      puts "    95th %ile: #{percentile sorted_times, 95}"
      puts "    Max: #{sorted_times.last}"
      puts ""
      puts "  Timeouts: #{stats[action][:timeouts].count}"
      puts "  Errors: #{stats[action][:errors].count}"

      #error_types = stats[action][:errors].group_by {|dict| dict[:exception_class]}
      #error_types.each_pair do |type, list|
      #  puts "    #{type} (#{list.count}) #{list}"
      #end

    end
    puts "\n\n"
    
    
  end

  # pass in a SORTED array a
  def percentile a, p
      rank = (p.to_f / 100) * (a.length + 1)
      
      if a.length == 0
        return nil
      elsif rank.modulo(1) != 0


        sample_0 = a[rank.truncate - 1]
        sample_1 = a[rank.truncate]


        return sample_0 if sample_1.nil?
        return (sample_1 + sample_0) / 2
      else
        return a[rank - 1]
      end    
  end
end