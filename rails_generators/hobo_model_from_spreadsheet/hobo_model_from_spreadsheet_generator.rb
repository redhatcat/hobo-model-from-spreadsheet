require 'rubygems'
require 'fastercsv'

class HoboModelFromSpreadsheetGenerator < Rails::Generator::Base

  attr_accessor :data_lengths
  attr_accessor :new_class_name

  def manifest
    record do |m|
      models_dir = File.join(RAILS_ROOT, 'app/models')
      fixtures_dir = File.join(RAILS_ROOT, 'test/fixtures')

      m.directory models_dir
      m.directory fixtures_dir

      for path in args
        @data_lengths, records = parse(path)
        @data_lengths.delete(nil) # Remove headerless columns

        base_name = File.basename(path, File.extname(path))
        @new_class_name = base_name.classify()
        m.template 'model.rb', File.join(models_dir, "#{base_name}.rb")
      end
    end
  end

  def parse(path)
    csvin = FasterCSV.open(path)

    common_length = get_common_row_length(csvin)
    csvin.seek(0)

    headers = nil
    data_lengths = Hash.new(0)

    records = csvin.collect{ |row|
      if headers.nil?
        if row.length == common_length
          headers = row.collect{ |header|
            if header.respond_to?('downcase')
              header.downcase.gsub(/ /, '_')
            else
              header
            end
          }
        end
        nil
      else
        data = headers.zip(row)
        data.each{ |column, value|
          if value.length > data_lengths[column]
            data_lengths[column] = value.length
          end
        }
        if row.length > common_length
          extra = row[common_length..-1].compact
          if not extra.empty?
            data << ['annotations', extra.join('; ')]
          end
        end
        mapped_data = Hash[*data.flatten]
        mapped_data.delete(nil) # Remove headerless columns
        mapped_data
      end
    }

    [data_lengths, records]
  end

  def get_common_row_length(list_of_lists)
    column_counts = list_of_lists.collect{ |row| row.length }

    frequencies = column_counts.inject(Hash.new(0)) {|h,x| h[x]+=1; h}.to_a
    most_frequent = 0
    most_frequent_occurs = 0
    frequencies.each{ |columns, occurs|
      if occurs > most_frequent_occurs
        most_frequent = columns
        most_frequent_occurs = occurs
      end
    }
    most_frequent
  end
end
