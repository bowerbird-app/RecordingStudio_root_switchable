# frozen_string_literal: true

module RecordingStudioRootSwitchable
  # rubocop:disable Metrics/ClassLength
  class RootSwitchesController < ApplicationController
    DEFAULT_LAYOUT = "recording_studio_root_switchable/blank"

    layout :resolved_layout

    before_action :set_scope
    before_action :authorize_page!
    before_action :enforce_switch_rate_limit!, only: :update

    def show
      prepare_page
    end

    def update
      result = RecordingStudio::RootSwitchable::Services::SwitchRoot.call(
        controller: self,
        actor: RecordingStudio::RootSwitchable::Current.actor,
        device_key: RecordingStudio::RootSwitchable::Current.device_key,
        root_recording_id: root_switch_params[:root_recording_id],
        scope_key: @scope.key
      )

      if result.success?
        redirect_to after_switch_redirect_location(result), notice: switch_success_notice(result.root_recording)
      else
        prepare_page(result: result)
        flash.now[:alert] = result.errors.to_sentence
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_scope
      @scope = RecordingStudioRootSwitchable.configuration.resolve_scope(
        key: params[:scope],
        controller: self,
        actor: RecordingStudio::RootSwitchable::Current.actor,
        device_key: RecordingStudio::RootSwitchable::Current.device_key
      )
      head :not_found unless @scope
    end

    def authorize_page!
      return if RecordingStudioRootSwitchable.configuration.authorize_mounted_page?(
        controller: self,
        actor: RecordingStudio::RootSwitchable::Current.actor,
        scope: @scope,
        current_root_recording: current_root_recording
      )

      head :forbidden
    end

    def enforce_switch_rate_limit!
      return if SwitchRateLimiter.allowed?(
        actor: RecordingStudio::RootSwitchable::Current.actor,
        device_key: RecordingStudio::RootSwitchable::Current.device_key
      )

      head :too_many_requests
    end

    def prepare_page(result: current_root_resolution)
      @resolution = result
      @selected_root = result.root_recording
      @available_roots = prioritize_selected_root(result.available_roots, @selected_root)
      @page_copy = page_copy
      @safe_return_to = safe_return_to_param
      @return_anchor_url = return_anchor_url
    end

    def prioritize_selected_root(available_roots, selected_root)
      roots = Array(available_roots)
      return roots unless selected_root

      selected_roots, other_roots = roots.partition do |root_recording|
        RecordingStudio::RootSwitchable::RootId.same?(root_recording.id, selected_root.id)
      end

      selected_roots + other_roots
    end

    def selected_root_label(root_recording)
      @scope.root_label_for(
        controller: self,
        actor: RecordingStudio::RootSwitchable::Current.actor,
        device_key: RecordingStudio::RootSwitchable::Current.device_key,
        recording: root_recording
      )
    end

    def switch_success_notice(root_recording)
      "#{selected_root_label(root_recording)} is now active."
    end

    def resolved_layout
      layout_value = RecordingStudioRootSwitchable.configuration.layout_for(
        controller: self,
        actor: RecordingStudio::RootSwitchable::Current.actor,
        device_key: RecordingStudio::RootSwitchable::Current.device_key,
        scope: @scope,
        current_root_recording: current_root_recording
      )

      case layout_value
      when nil
        DEFAULT_LAYOUT
      when Symbol
        send(layout_value).presence || DEFAULT_LAYOUT
      else
        layout_value.presence || DEFAULT_LAYOUT
      end
    rescue StandardError => e
      log_controller_rescue("layout", e)
      DEFAULT_LAYOUT
    end

    def after_switch_redirect_location(result)
      safe_return_to = RedirectSanitizer.sanitize(root_switch_params[:return_to])
      configured_target = RecordingStudioRootSwitchable.configuration.after_switch_redirect_for(
        controller: self,
        actor: RecordingStudio::RootSwitchable::Current.actor,
        device_key: RecordingStudio::RootSwitchable::Current.device_key,
        scope: @scope,
        root_recording: result.root_recording,
        return_to: safe_return_to
      )

      RedirectSanitizer.sanitize(configured_target) || default_after_switch_redirect_location
    rescue StandardError => e
      log_controller_rescue("after_switch_redirect", e)
      default_after_switch_redirect_location
    end

    def default_after_switch_redirect_location
      root_switch_path(scope: @scope.key)
    end

    def return_anchor_url
      safe_return_to_param || default_return_anchor_url
    end

    def default_return_anchor_url
      main_app.root_path
    rescue StandardError
      default_after_switch_redirect_location
    end

    def safe_return_to_param
      RedirectSanitizer.sanitize(root_switch_params[:return_to]) ||
        RedirectSanitizer.sanitize(params[:return_to])
    end

    def root_switch_params
      raw_params = params.fetch(:root_switch, ActionController::Parameters.new)
      return ActionController::Parameters.new.permit unless raw_params.respond_to?(:permit)

      raw_params.permit(:root_recording_id, :return_to)
    end

    def log_controller_rescue(hook_name, error)
      return unless defined?(Rails) && Rails.respond_to?(:env) && !Rails.env.production?
      return unless Rails.respond_to?(:logger) && Rails.logger

      Rails.logger.warn(
        "RecordingStudioRootSwitchable::RootSwitchesController #{hook_name} raised #{error.class}: #{error.message}"
      )
    end
  end
  # rubocop:enable Metrics/ClassLength
end
