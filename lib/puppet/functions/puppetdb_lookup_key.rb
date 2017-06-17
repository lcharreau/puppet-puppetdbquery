# The `puppetdb_lookup_key` is a hiera 5 `lookup_key` data provider function.
# See (https://docs.puppet.com/puppet/latest/hiera_custom_lookup_key.html) for
# more info.
#
# See README.md#hiera-backend for usage.
#
Puppet::Functions.create_function(:puppetdb_lookup_key) do
  require 'puppet/util/puppetdb'

  # This is needed if the puppetdb library isn't pluginsynced to the master
  $LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
  begin
    require 'puppetdb/connection'
  ensure
    $LOAD_PATH.shift
  end

  dispatch :puppetdb_lookup_key do
    param 'String[1]', :key
    param 'Hash[String[1],Any]', :options
    param 'Puppet::LookupContext', :context
  end

  def parser
    @parser ||= PuppetDB::Parser.new
  end

  def puppetdb
    @uri ||= URI(Puppet::Util::Puppetdb.config.server_urls.first)
    @puppetdb ||= PuppetDB::Connection.new(
      @uri.host,
      @uri.port,
      @uri.scheme == 'https'
    )
  end

  def puppetdb_lookup_key(key, options, context)
    return context.cached_value(key) if context.cache_has_key(key)

    if !key.end_with?('::_nodequery') && nodequery = call_function('lookup', "#{key}::_nodequery", 'merge' => 'first', 'default_value' => nil)
      # Support specifying the query in a few different ways
      query, fact = case nodequery
                    when Hash then [nodequery['query'], nodequery['fact']]
                    when Array then nodequery
                    else [nodequery.to_s, nil]
                    end

      if fact
        result = call_function('query_nodes', query, fact)
      else
        result = call_function('query_nodes', query)
      end
      context.cache(key, result)
    else
      context.not_found
    end
  end
end
