Opal::Application.configure do
  # Settings specified here will take precedence over those in config/environment.rb
  
  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true
  
  # Use a different logger for distributed setups
  # config.logger = SyslogLogger.new
  
  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local = false
  config.action_controller.perform_caching             = true
  #config.action_view.cache_template_loading            = true # Deprecated
  
  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host                  = "http://assets.example.com"
  
  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_assets = true

  # Live Compilation - On the first request the assets are compiled and cached. 
  # Causes First-time load performance hit  
  config.assets.compile = false

  # Compress JavaScripts and CSS
  config.assets.compress = true

  # Don't fallback to assets pipeline if a precompiled asset is missed
  # Run this during deploy:
  # bundle exec rake assets:precompile RAILS_ENV=production
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true
  
  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false
  config.action_mailer.default_url_options = { :host => "localhost" }

  # Deprecation notices 
  config.active_support.deprecation = :log
  
  # Add additional assets to precompile
  #config.assets.precompile += ['tiny_mce/tiny_mce.js'] # moved from vendor/assets to public/javascripts because of tinymce path resolution problem
  config.assets.precompile += [/^[a-zA-Z]*\..*/]
  config.assets.precompile += [ /\w+\.(?!js|css).+/, /application.(css|js)$/ ]
    
  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true    
end