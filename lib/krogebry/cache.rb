##
# Simple cache handler.
##
module Krogebry

  class FileCache
    @cache_dir = ""

    def initialize(cache_dir)
      @cache_dir = cache_dir
      FileUtils::mkdir_p(@cache_dir) unless File.exist?(@cache_dir)
    end

    def get_json(key, force=false)
      fs_cache_file = format('%s/%s', @cache_dir, key)
      data = unless File.exist?( fs_cache_file ) || force 
        Log.info(format('Getting from source: [%s]', key))
        data = yield

        f = File.open(fs_cache_file, 'w')
        f.puts(data)
        f.close

        data

      else
        File.read(fs_cache_file)

      end
      JSON::parse(data)
    end

    def clear_all
      Dir.glob(File.join(@cache_dir, '*')).each{|f| File.unlink(f)}
    end

    def set(key, value)
      fs_cache_file = File.join(@cache_dir, key) 
      f = File.open(fs_cache_file, 'w')
      f.puts(value)
      f.close
    end

  end
end
