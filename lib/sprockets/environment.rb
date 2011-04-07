require 'fileutils'
require 'hike'
require 'logger'
require 'sprockets/environment_index'
require 'sprockets/pathname'
require 'sprockets/server'
require 'sprockets/template_mappings'

module Sprockets
  class Environment
    extend TemplateMappings
    include Server

    attr_accessor :logger

    def initialize(root = ".")
      @trail = Hike::Trail.new(root)
      extensions = ConcatenatedAsset::DEFAULT_ENGINE_EXTENSIONS +
        ConcatenatedAsset::CONCATENATABLE_EXTENSIONS
      engine_extensions.replace(extensions)

      @logger = Logger.new($stderr)
      @logger.level = Logger::FATAL

      @static_root = nil
      @cache = {}
    end

    attr_accessor :static_root
    attr_accessor :css_compressor, :js_compressor

    def use_default_compressors
      begin
        require 'yui/compressor'
        self.css_compressor = YUI::CssCompressor.new
        self.js_compressor  = YUI::JavaScriptCompressor.new(:munge => true)
      rescue LoadError
      end

      begin
        require 'closure-compiler'
        self.js_compressor = Closure::Compiler.new
      rescue LoadError
      end

      nil
    end

    def root
      @trail.root
    end

    def paths
      @trail.paths
    end

    def engine_extensions
      @trail.extensions
    end

    def precompile(*paths)
      index.precompile(*paths)
    end

    def index
      EnvironmentIndex.new(self, @trail, @static_root)
    end

    def resolve(logical_path, options = {}, &block)
      index.resolve(logical_path, options, &block)
    end

    def find_asset(logical_path)
      logical_path = Pathname.new(logical_path)

      if asset = find_fresh_asset_from_cache(logical_path)
        asset
      elsif asset = index.find_asset(logical_path)
        @cache[logical_path.to_s] = asset
      end
    end
    alias_method :[], :find_asset

    protected
      def find_fresh_asset_from_cache(logical_path)
        if asset = @cache[logical_path.to_s]
          if logical_path.fingerprint
            asset
          elsif asset.stale?
            logger.warn "[Sprockets] #{logical_path} #{asset.digest} stale"
            nil
          else
            logger.info "[Sprockets] #{logical_path} #{asset.digest} fresh"
            asset
          end
        else
          nil
        end
      end
  end
end
