# frozen_string_literal: true

require "uri"

module RecordingStudioRootSwitchable
  # rubocop:disable Metrics/ClassLength
  class RootSwitchesController < ApplicationController
    DEFAULT_LAYOUT = "recording_studio_root_switchable/blank"

    layout :resolved_layout

    before_action :set_scope
    before_action :authorize_page!

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

    def prepare_page(result: current_root_resolution)
      @resolution = result
      @available_roots = result.available_roots
      @selected_root = result.root_recording
      @supported_scopes = RecordingStudioRootSwitchable.configuration.supported_scopes(
        controller: self,
        actor: RecordingStudio::RootSwitchable::Current.actor,
        device_key: RecordingStudio::RootSwitchable::Current.device_key
      )
      @page_copy = page_copy
      @root_type_label = root_type_label
    end

    def root_type_label
      recordable = @selected_root&.recordable || @available_roots.first&.recordable
      return "root" unless recordable

      recordable.class.model_name.human.downcase
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
    rescue StandardError
      DEFAULT_LAYOUT
    end

    def after_switch_redirect_location(result)
      configured_target = RecordingStudioRootSwitchable.configuration.after_switch_redirect_for(
        controller: self,
        actor: RecordingStudio::RootSwitchable::Current.actor,
        device_key: RecordingStudio::RootSwitchable::Current.device_key,
        scope: @scope,
        root_recording: result.root_recording,
        return_to: root_switch_params[:return_to]
      )

      sanitize_after_switch_redirect(configured_target) || default_after_switch_redirect_location
    rescue StandardError
      default_after_switch_redirect_location
    end

    def default_after_switch_redirect_location
      root_switch_path(scope: @scope.key)
    end

    def sanitize_after_switch_redirect(target)
      return if target.blank?

      candidate = target.to_s
      return unless candidate.start_with?("/")
      return if candidate.start_with?("//")

      parsed = URI.parse(candidate)
      return if parsed.scheme.present? || parsed.host.present?

      candidate
    rescue URI::InvalidURIError
      nil
    end

    def root_switch_params
      params.fetch(:root_switch, {}).permit(:root_recording_id, :return_to)
    end
  end
  # rubocop:enable Metrics/ClassLength
end
