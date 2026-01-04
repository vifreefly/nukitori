# frozen_string_literal: true

module Nukitori
  class ChatFactory
    class << self
      def create(model: nil)
        options = {}
        options[:model] = model if model

        begin
          RubyLLM.chat(**options)
        rescue RubyLLM::ModelNotFoundError 
          # If custom OpenAI-compatible API is configured, add required options
          if custom_openai_api?
            options[:provider] = :openai
            options[:assume_model_exists] = true
          end

          RubyLLM.chat(**options)
        end
      end

      private

      def custom_openai_api?
        base = RubyLLM.config.openai_api_base
        base && base != 'https://api.openai.com/v1/'
      end
    end
  end
end
