require 'rubygems'
require 'fastercsv'
require 'iconv'

class HoboModelFromSpreadsheetGenerator < Rails::Generator::Base

  attr_accessor :data_lengths
  attr_accessor :new_class_name

  default_options :header_row => false

  def get_common_row_length(list_of_lists)
    column_counts = list_of_lists.collect{ |row| row.compact.length }

    frequencies = column_counts.inject(Hash.new(0)) {|h,x| h[x]+=1; h}.to_a
    most_frequent = 0
    most_frequent_occurs = 0
    frequencies.each{ |columns, occurs|
      if columns > 1 and occurs > most_frequent_occurs
        most_frequent = columns
        most_frequent_occurs = occurs
      end
    }
    most_frequent
  end

  # Checks if path contains utf8 or compatible text, i.e. ASCII.
  def is_file_utf8(path)
    File.open(path) do |f|
      begin
        f.each do |line|
          Iconv.conv('UTF-8', 'UTF-8', line)
        end
      rescue Iconv::IllegalSequence
        return false
      end
    end
    true
  end

  def is_letter_header(list, threshold=4)
    suspect_columns = list.collect{ |e|
      if e.respond_to?('length') and e.length == 1
        e
      else
        nil
      end
    }
    suspect_columns.compact.length > threshold
  end

  def manifest
    record do |m|
      models_dir = 'app/models'
      fixtures_dir = 'test/fixtures'

      m.directory models_dir
      m.directory fixtures_dir

      if options[:header_row]
        header_row = Integer(args.shift)
      else
        header_row = nil
      end

      path = args.shift

      @data_lengths, records = parse(path, :header_row => header_row)
      @data_lengths.delete(nil) # Remove headerless columns

      base_name = File.basename(path, File.extname(path)).gsub(/ /, '_').downcase
      @new_class_name = base_name.classify()
      new_file_name = @new_class_name.underscore()
      m.template 'model.rb', File.join(models_dir, "#{new_file_name}.rb")

      fixture_file = File.join(fixtures_dir, "#{new_file_name.pluralize}.csv")
      logger.fixture fixture_file
      headers = data_lengths.keys() + ['annotations', 'imported_from_file', 'line_number']
      FasterCSV.open(fixture_file, 'w'){ |csv|
        csv << headers
        for record in records.compact
          csv << record.values_at(*headers)
        end
      }
    end
  end

  def parse(path, options={})
    if !is_file_utf8(path)
      raise 'CSV must be encoded as UTF-8 or ASCII'
    end
    csvin = FasterCSV.open(path)

    common_length = get_common_row_length(csvin)
    csvin.seek(0)

    header_row = options[:header_row]
    headers = nil
    data_lengths = Hash.new(0)

    def collect_headers(row)
      row.collect{ |header|
        if header.respond_to?('downcase')
          header.downcase.gsub(/ /, '_').gsub(/[^a-z0-9_]/, '')
        else
          header
        end
      }
    end

    records = csvin.to_enum(:each_with_index).collect{ |row, row_number|
      if headers.nil?
        if header_row.nil? and
          row.compact.length >= common_length and
          not is_letter_header(row)
          headers = collect_headers(row)
        elsif row_number + 1 == header_row
          headers = collect_headers(row)
        end
        nil
      else
        data = headers.zip(row)
        data.each{ |column, value|
          if not value.nil? and value.length > data_lengths[column]
            data_lengths[column] = value.length
          end
        }
        if row.length > common_length
          extra = row[common_length..-1].compact
          if not extra.empty?
            data << ['annotations', extra.join('; ')]
          end
        end
        data << ['imported_from_file', path]
        data << ['line_number', row_number + 1]
        mapped_data = Hash[*data.flatten]
        mapped_data.delete(nil) # Remove headerless columns
        mapped_data
      end
    }

    [data_lengths, records]
  end

  protected

    def add_options!(opt)
      opt.separator ''
      opt.separator 'Options:'
      opt.on("--header-row",
             "Force row to be recognized as the header row") { |v| options[:header_row] = v }
    end
end
