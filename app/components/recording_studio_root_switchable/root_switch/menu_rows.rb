# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RootSwitch
    # Current workspace plus the other accessible workspaces, in switcher order.
    class MenuRows
      Row = Data.define(:label, :root_recording_id, :current) do
        def current?
          current
        end
      end

      Options = Data.define(:none_selected_label, :new_root_path, :new_root_label, :new_root_icon)
      Override = Data.define(:path, :label, :icon) do
        def self.from(path, label, icon = nil)
          return if path.nil? && label.nil? && icon.nil?

          new(path: path, label: label, icon: icon)
        end
      end

      def self.build(entries:, selected:, form_action:, return_to:, options:)
        rows = build_rows(entries, selected&.fetch(:id))
        safe_new_root_path = RecordingStudioRootSwitchable::RedirectSanitizer.sanitize(options.new_root_path)
        return if nothing_to_show?(selected, rows, safe_new_root_path)

        compose(rows, selected, form_action, return_to, options.with(new_root_path: safe_new_root_path))
      end

      def self.nothing_to_show?(selected, rows, new_root_path = nil)
        return false if new_root_path.present?

        selected&.fetch(:id).blank? && selected&.fetch(:label).blank? && rows.empty?
      end
      private_class_method :nothing_to_show?

      def self.compose(rows, selected, form_action, return_to, options)
        new(
          rows: order_current_first(rows),
          selected_label: rows.any?(&:current?) ? nil : selected&.fetch(:label),
          form_action: form_action,
          return_to: RecordingStudioRootSwitchable::RedirectSanitizer.sanitize(return_to),
          options: options
        )
      end
      private_class_method :compose

      def self.build_rows(entries, selected_id)
        Array(entries).filter_map { |entry| row_for(entry, selected_id) }.uniq { |row| row.root_recording_id.to_s }
      end
      private_class_method :build_rows

      def self.row_for(entry, selected_id)
        id = entry.fetch(:id)
        label = entry.fetch(:label).to_s
        return if id.blank? || label.blank?

        Row.new(
          label: label,
          root_recording_id: id,
          current: RecordingStudio::RootSwitchable::RootId.same?(id, selected_id)
        )
      end
      private_class_method :row_for

      def self.order_current_first(rows)
        current_rows, other_rows = rows.partition(&:current?)
        current_rows + other_rows
      end
      private_class_method :order_current_first

      def initialize(rows:, selected_label:, form_action:, return_to:, options:)
        @rows = rows
        @selected_label = selected_label
        @form_action = form_action
        @return_to = return_to
        @none_selected_label = options.none_selected_label
        @new_root_path = options.new_root_path
        @new_root_label = options.new_root_label
        @new_root_icon = options.new_root_icon
      end

      attr_reader :rows, :form_action, :return_to, :new_root_path, :new_root_icon

      def current_label
        current = rows.find(&:current?)
        return current.label if current
        return selected_label if selected_label.present?

        none_selected_label
      end

      def switch_rows
        rows.reject(&:current?)
      end

      def new_root_label
        @new_root_label.presence || I18n.t(
          "recording_studio.root_switchable.dropdown.new_root",
          default: "New workspace"
        )
      end

      def form_params_for(row)
        fields = { root_recording_id: row.root_recording_id }
        fields[:return_to] = return_to if return_to.present?
        { root_switch: fields }
      end

      private

      attr_reader :selected_label, :none_selected_label
    end
  end
end
