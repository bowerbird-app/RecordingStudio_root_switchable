class HomeController < ApplicationController
  GEM_VIEWS_ROOT = RecordingStudioRootSwitchable::Engine.root.join("app/views").freeze

  def index
    @pages = if current_root_recording.present?
      current_root_recording.recordings_query(type: Page, recordable_order: "title asc")
                            .includes(:recordable)
                            .map(&:recordable)
    else
      []
    end
  end

  def setup
  end

  def configuration
    render :config
  end

  def usage
  end

  def switch_log
    @saved_sessions = RecordingStudio::RootSwitchable::Selection
      .includes(:actor, root_recording: :recordable)
      .order(last_used_at: :desc)
  end

  def method_docs
    @documented_methods = documented_methods
    render :methods
  end

  def gem_views
    @gem_views = gem_view_entries
  end

  def gem_view
    @gem_view_path = params[:view_path].to_s
    full_path = GEM_VIEWS_ROOT.join(@gem_view_path).cleanpath

    if !full_path.to_s.start_with?("#{GEM_VIEWS_ROOT}/") || full_path.extname != ".erb" || !full_path.file?
      raise ActionController::RoutingError, "Not Found"
    end

    @gem_view_source = File.read(full_path)
  end

  private

  helper_method :saved_session_user,
                :saved_session_workspace_name,
                :saved_session_device,
                :saved_session_device_context,
                :saved_session_device_key,
                :saved_session_timestamp

  def saved_session_user(selection)
    actor = selection.actor
    return actor.email if actor.respond_to?(:email) && actor.email.present?
    return actor.name if actor.respond_to?(:name) && actor.name.present?
    return actor.to_s if actor.present?

    "Anonymous"
  end

  def saved_session_workspace_name(selection)
    selection.root_recording&.recordable&.try(:name).presence ||
      selection.root_recording&.recordable&.try(:title).presence ||
      "Unknown workspace"
  end

  def saved_session_device(selection)
    selection.device_label.presence ||
      [ selection.device_browser, selection.device_platform ].compact.join(" on ").presence ||
      selection.device_platform.presence ||
      selection.device_browser.presence ||
      selection.device_type.to_s.humanize.presence ||
      "Unknown device"
  end

  def saved_session_device_context(selection)
    details = []
    device_type = selection.device_type.to_s.humanize.presence
    details << device_type if device_type.present? && device_type != saved_session_device(selection)
    details << "User agent captured" if selection.user_agent.present?

    details.join(" · ").presence || "No request metadata recorded"
  end

  def saved_session_device_key(selection)
    device_key = selection.device_key.to_s
    return "Unknown device key" if device_key.blank?
    return device_key if device_key.length <= 12

    "#{device_key.first(8)}…#{device_key.last(4)}"
  end

  def saved_session_timestamp(selection)
    return "Never" if selection.last_used_at.blank?

    helpers.time_ago_in_words(selection.last_used_at) + " ago"
  end

  def documented_methods
    [
      {
        anchor: "current-root",
        name: "Current root",
        signature: "RecordingStudio::RootSwitchable.current_root",
        code: <<~CODE
          # Read the resolved root recording for the current request.
          root_recording = RecordingStudio::RootSwitchable.current_root

          # Use safe navigation because a scope may resolve without any available root.
          root_title = root_recording&.recordable&.title
        CODE
      },
      {
        anchor: "current-root-recording",
        name: "Current root recording",
        signature: "RecordingStudio::RootSwitchable.current_root_recording",
        code: <<~CODE
          # current_root_recording is an alias for current_root.
          root_recording = RecordingStudio::RootSwitchable.current_root_recording

          # This is useful when you want the Recording row explicitly.
          root_id = root_recording&.id
        CODE
      },
      {
        anchor: "current-root-recordable",
        name: "Current root recordable",
        signature: "RecordingStudio::RootSwitchable.current_root_recordable",
        code: <<~CODE
          # Ask for the underlying recordable when your app works with the domain model.
          workspace = RecordingStudio::RootSwitchable.current_root_recordable

          # The returned object is usually the recordable attached to the selected root recording.
          workspace_name = workspace&.title
        CODE
      },
      {
        anchor: "current-root-scope-key",
        name: "Current root scope key",
        signature: "RecordingStudio::RootSwitchable.current_root_scope_key",
        code: <<~'CODE'
          # Scope keys let the host app tell which root set is active.
          scope_key = RecordingStudio::RootSwitchable.current_root_scope_key

          # Example values are host-defined, such as "all_workspaces" or "client_workspaces".
          Rails.logger.info("Active root scope: #{scope_key}")
        CODE
      },
      {
        anchor: "current-device-key",
        name: "Current device key",
        signature: "RecordingStudio::RootSwitchable.current_device_key",
        code: <<~CODE
          # The device key identifies the browser/device cookie context.
          device_key = RecordingStudio::RootSwitchable.current_device_key

          # Selections are persisted per actor, per device key, and per scope.
          cache_key = [Current.actor&.id, device_key, RecordingStudio::RootSwitchable.current_root_scope_key]
        CODE
      },
      {
        anchor: "resolve-current-root",
        name: "Resolve current root",
        signature: "RecordingStudio::RootSwitchable.resolve_current_root(...)",
        code: <<~CODE
          resolution = RecordingStudio::RootSwitchable.resolve_current_root(
            controller: self,
            actor: Current.actor,
            device_key: RecordingStudio::RootSwitchable.current_device_key,
            scope_key: "all_workspaces"
          )

          # The result includes the chosen root, scope, and the available roots list.
          selected_via = resolution.selected_via
        CODE
      },
      {
        anchor: "switch-root",
        name: "Switch root",
        signature: "RecordingStudio::RootSwitchable.switch_root(...)",
        code: <<~CODE
          result = RecordingStudio::RootSwitchable.switch_root(
            root_recording_id: params[:root_recording_id],
            scope_key: "all_workspaces",
            controller: self,
            actor: Current.actor,
            device_key: RecordingStudio::RootSwitchable.current_device_key
          )

          # Check result.errors when the requested root is not available for the scope.
          flash[:notice] = "Root updated" if result.errors.blank?
        CODE
      }
    ]
  end

  def gem_view_entries
    Dir.glob(GEM_VIEWS_ROOT.join("**/*.erb")).sort.map do |view_path|
      relative_path = Pathname(view_path).relative_path_from(GEM_VIEWS_ROOT).to_s

      {
        name: File.basename(relative_path),
        path: File.join("app/views", relative_path),
        href: gem_view_path(relative_path)
      }
    end
  end
end
