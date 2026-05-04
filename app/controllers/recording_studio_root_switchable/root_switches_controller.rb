# frozen_string_literal: true

module RecordingStudioRootSwitchable
  class RootSwitchesController < ApplicationController
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
        redirect_to root_switch_path(scope: @scope.key), notice: "#{selected_root_label(result.root_recording)} is now active."
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
    end

    def selected_root_label(root_recording)
      @scope.root_label_for(
        controller: self,
        actor: RecordingStudio::RootSwitchable::Current.actor,
        device_key: RecordingStudio::RootSwitchable::Current.device_key,
        recording: root_recording
      )
    end

    def root_switch_params
      params.fetch(:root_switch, {}).permit(:root_recording_id)
    end
  end
end
