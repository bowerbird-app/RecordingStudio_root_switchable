# frozen_string_literal: true

module RecordingStudioRootSwitchable
  class NewRootsController < ApplicationController
    before_action :set_scope
    before_action :authorize_page!

    def index
      @page_copy = page_copy
      @safe_return_to = safe_return_to
      @choices = page_choices
      @picker_title = @page_copy.fetch(:new_root_picker_title)
      @picker_body = @page_copy.fetch(:new_root_picker_body).presence
    end

    def show
      outcome = RecordingStudio::RootSwitchable::CreateGate.call(
        scope: @scope,
        type_name: params[:type].to_s,
        arguments: creation_arguments,
        fallback_location: root_switch_path(scope: @scope.key)
      )
      return head(:not_found) if outcome.missing?
      return redirect_to(outcome.location, alert: outcome.reason) if outcome.refuse?

      redirect_to outcome.location
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
      actor = RecordingStudio::RootSwitchable::Current.actor
      recording = current_root_recording
      configuration = RecordingStudioRootSwitchable.configuration
      allowed = configuration.default_mounted_page_authorized?(actor: actor, root_recording: recording)
      return head(:forbidden) unless allowed
      return if configuration.authorize_mounted_page?(
        controller: self, actor: actor, scope: @scope, current_root_recording: recording
      )

      head :forbidden
    end

    def page_choices
      RecordingStudio::RootSwitchable::NewRootMenu.page_choices(
        scope: @scope,
        arguments: creation_arguments,
        controller: self
      )
    end

    def creation_arguments
      {
        controller: self,
        actor: RecordingStudio::RootSwitchable::Current.actor,
        device_key: RecordingStudio::RootSwitchable::Current.device_key,
        scope: @scope,
        current_root_recording: current_root_recording,
        return_to: safe_return_to
      }
    end

    def safe_return_to
      RecordingStudioRootSwitchable::RedirectSanitizer.sanitize(params[:return_to])
    end
  end
end
