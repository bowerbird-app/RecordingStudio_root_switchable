# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RootSwitch
    # FlatPack dropdown labelled with the current workspace.
    # The phone row for a collapsing button group is the same collapse hosts
    # drop into their own menu.
    class DropdownComponent < FlatPack::Button::Dropdown::Component
      NAME_CLASSES = {
        nil => "inline-block max-w-[9rem] truncate align-middle",
        below_md: "max-w-[9rem] truncate align-middle hidden md:inline-block",
        always: "hidden"
      }.freeze

      BADGE_WRAP_CLASSES = {
        below_md: "inline-flex items-center md:hidden",
        always: "inline-flex items-center"
      }.freeze

      def initialize(menu_rows:, compact: nil, compact_chrome: nil, badge_size: nil, **system_arguments)
        @menu_rows = menu_rows
        @compact = CompactTrigger.normalize!(compact)
        @compact_chrome = CompactTrigger.normalize_chrome!(compact_chrome)
        @button_size = CompactTrigger.resolved_button_size(system_arguments[:size])
        @badge_size = CompactTrigger.resolve_badge_size!(
          badge_size: badge_size,
          compact_chrome: @compact_chrome,
          button_size: @button_size
        )
        super(**parent_dropdown_arguments(system_arguments))
      end

      attr_reader :menu_rows, :compact, :compact_chrome, :badge_size

      def before_render
        with_trigger_label { trigger_label_content }
        menu_html(render(RowsComponent.new(menu_rows: menu_rows)))
        super
      end

      def menu_row
        render(ListComponent.new(menu_rows: menu_rows))
      end

      private

      def parent_dropdown_arguments(system_arguments)
        system_arguments.delete(:text)
        system_arguments.delete(:disabled)
        system_arguments[:show_chevron] = false if @compact == :always
        {
          text: menu_rows.current_label,
          disabled: menu_rows.switch_rows.empty? && menu_rows.new_root_path.blank?,
          **with_trigger_attributes(system_arguments)
        }
      end

      def wrapper_classes
        extra = compact_wrapper_class
        extra ? "#{super} #{extra}" : super
      end

      def with_trigger_attributes(system_arguments)
        attrs = (system_arguments[:trigger_attributes] || {}).dup
        attrs[:title] = menu_rows.current_label if attrs[:title].blank?
        apply_compact_aria(attrs) if compact?
        system_arguments.merge(trigger_attributes: attrs)
      end

      def apply_compact_aria(attrs)
        aria = (attrs[:aria] || {}).dup
        aria[:label] = menu_rows.current_label if aria[:label].blank?
        attrs[:aria] = aria
      end

      def compact_wrapper_class
        CompactTrigger.wrapper_class(compact: compact, chrome: compact_chrome, size: @button_size)
      end

      def compact?
        !compact.nil?
      end

      def trigger_label_content
        parts = [content_tag(:span, menu_rows.current_label, class: NAME_CLASSES.fetch(compact))]
        parts << compact_badge if compact?
        safe_join(parts)
      end

      def compact_badge
        content_tag(:span, class: compact_badge_wrap_class, aria: { hidden: true }) do
          render(FlatPack::Avatar::Component.new(**compact_avatar_arguments))
        end
      end

      def compact_badge_wrap_class
        classes = [BADGE_WRAP_CLASSES.fetch(compact)]
        classes << "rs-root-switch-compact-badge" if compact_chrome == :button
        classes.join(" ")
      end

      def compact_avatar_arguments
        initials = compact_initials
        {
          size: badge_size,
          show_tooltip: false,
          **compact_avatar_identity(initials)
        }
      end

      def compact_avatar_identity(initials)
        if initials.present?
          { initials: initials }
        else
          { icon: CompactTrigger::FALLBACK_ICON }
        end
      end

      def compact_initials
        return if menu_rows.none_selected?

        CompactTrigger.initials(menu_rows.current_label)
      end
    end
  end
end
