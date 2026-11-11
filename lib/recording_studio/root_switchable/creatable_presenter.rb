# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    # Turns a declared type into the label, path, and decision the UI shows.
    class CreatablePresenter
      def initialize(scope, hook)
        @scope = scope
        @hook = hook
      end

      def present(entry, arguments, mode)
        path = resolved_path(entry, arguments)
        decision = decision_for(entry, arguments, mode)
        return if decision.hide? || path.blank?

        Presented.new(
          snapshot: snapshot(entry, arguments),
          path: path,
          decision: decision,
          disabled_reason: disabled_reason(decision)
        )
      end

      private

      attr_reader :scope, :hook

      def snapshot(entry, arguments)
        Presented::Snapshot.new(
          type_name: entry.type_name,
          label: resolved_label(entry, arguments),
          icon: resolved_icon(entry, arguments),
          description: resolved_description(entry, arguments)
        )
      end

      def decision_for(entry, arguments, mode)
        DecisionRunner.call(hook, build_context(entry, arguments, mode))
      end

      def build_context(entry, arguments, mode)
        CreateContext.new(
          actor: arguments[:actor],
          scope_key: scope.key,
          root_type: entry.type_name,
          current_root_recording: arguments[:current_root_recording],
          request: request_for(arguments, mode)
        )
      end

      def request_for(arguments, mode)
        CreateContext::Request.new(
          controller: arguments[:controller],
          return_to: arguments[:return_to],
          mode: mode
        )
      end

      def resolved_path(entry, arguments)
        return scope.new_root_path_for(**arguments) if entry.legacy

        raw = call_value(entry.path, arguments, entry.type_name)
        return if raw.blank?

        RecordingStudioRootSwitchable::RedirectSanitizer.with_return_to(raw, arguments[:return_to])
      rescue StandardError => e
        log_failure(e)
        nil
      end

      def resolved_label(entry, arguments)
        return scope.new_root_label_for(**arguments) if entry.legacy

        text(call_value(entry.label, arguments, entry.type_name)) || default_label(entry)
      end

      def default_label(entry)
        human = entry.type_name.to_s.underscore.humanize.downcase
        I18n.t("recording_studio.root_switchable.new_root.type_label", type: human, default: "New #{human}")
      end

      def resolved_icon(entry, arguments)
        return scope.new_root_icon_for(**arguments) if entry.legacy

        raw = call_value(entry.icon, arguments, entry.type_name)
        scope.new_root_icon_for(**arguments, override: raw.nil? ? nil : raw)
      end

      def resolved_description(entry, arguments)
        text(call_value(entry.description, arguments, entry.type_name))
      end

      def disabled_reason(decision)
        return unless decision.refuse?

        decision.reason.presence || fallback_reason
      end

      def fallback_reason
        RecordingStudioRootSwitchable.configuration.page_copy_for(scope: scope).fetch(:new_root_disabled_reason)
      end

      def call_value(value, arguments, type_name)
        return value unless value.respond_to?(:call)

        value.call(**arguments, root_type: type_name)
      rescue StandardError => e
        log_failure(e)
        nil
      end

      def text(value)
        return unless value.is_a?(String)

        value.strip.presence
      end

      def log_failure(error)
        return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

        Rails.logger.warn(
          "RecordingStudio::RootSwitchable creatable path on #{scope.key} raised #{error.class}: #{error.message}"
        )
      end
    end

    # One creatable type after the display hook. Hidden types are omitted.
    class Presented
      Snapshot = Data.define(:type_name, :label, :icon, :description)

      attr_reader :type_name, :path, :label, :icon, :description, :decision, :disabled_reason

      def initialize(snapshot:, path:, decision:, disabled_reason:)
        @type_name = snapshot.type_name
        @path = path
        @label = snapshot.label
        @icon = snapshot.icon
        @description = snapshot.description
        @decision = decision
        @disabled_reason = disabled_reason
      end

      def disabled?
        disabled_reason.present?
      end
    end

    # Runs the hook. A raise refuses. The page does not crash.
    module DecisionRunner
      module_function

      def call(hook, context)
        return CreateDecision.allow unless hook.respond_to?(:call)

        normalize(hook.call(context), context)
      rescue StandardError => e
        log_failure(context, e)
        CreateDecision.refuse(redirect_to: context.return_to, reason: nil)
      end

      def normalize(result, context)
        return CreateDecision.allow if allow_result?(result)
        return CreateDecision.hide if hide_result?(result)
        return result if result.respond_to?(:refuse?) && result.refuse?

        CreateDecision.refuse(redirect_to: context.return_to, reason: nil)
      end

      def allow_result?(result)
        result.nil? || result == true || result == :allow || (result.respond_to?(:allow?) && result.allow?)
      end

      def hide_result?(result)
        result == :hide || (result.respond_to?(:hide?) && result.hide?)
      end

      def log_failure(context, error)
        return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

        message = "#{context.scope_key}/#{context.root_type} raised #{error.class}: #{error.message}"
        Rails.logger.warn("RecordingStudio::RootSwitchable before_root_create #{message}")
      end
    end
  end
end
