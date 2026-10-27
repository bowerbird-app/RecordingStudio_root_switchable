# frozen_string_literal: true

require "uri"

module RecordingStudioRootSwitchable
  module RedirectSanitizer
    module_function

    def sanitize(target)
      RecordingStudio::RootSwitchable::InternalPath.sanitize(target)
    end

    def with_return_to(path, return_to)
      safe_path = sanitize(path)
      return if safe_path.blank?

      append_return_to(safe_path, sanitize(return_to))
    end

    def append_return_to(safe_path, safe_return)
      return safe_path if safe_return.blank? || query_has_return_to?(safe_path)

      uri = URI.parse(safe_path)
      pairs = URI.decode_www_form(uri.query.to_s) << ["return_to", safe_return]
      uri.query = URI.encode_www_form(pairs)
      sanitize(uri.to_s)
    rescue URI::InvalidURIError
      safe_path
    end

    def query_has_return_to?(path)
      URI.decode_www_form(URI.parse(path).query.to_s).any? { |key, _value| key == "return_to" }
    rescue URI::InvalidURIError
      false
    end
  end
end
