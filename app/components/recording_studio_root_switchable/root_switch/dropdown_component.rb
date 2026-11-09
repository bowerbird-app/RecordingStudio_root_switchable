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

      BADGE_BASE = "inline-flex h-6 w-6 shrink-0 items-center justify-center " \
                   "rounded-full bg-[var(--avatar-background-color)] text-[10px] " \
                   "font-semibold uppercase leading-none text-[var(--avatar-text-color)]"
      BADGE_CLASSES = {
        below_md: "#{BADGE_BASE} md:hidden",
        always: BADGE_BASE
      }.freeze

      def initialize(menu_rows:, compact: nil, **system_arguments)
        @menu_rows = menu_rows
        @compact = CompactTrigger.normalize!(compact)
        system_arguments.delete(:text)
        system_arguments.delete(:disabled)
        super(
          text: menu_rows.current_label,
          disabled: menu_rows.switch_rows.empty? && menu_rows.new_root_path.blank?,
          **with_trigger_attributes(system_arguments)
        )
      end

      attr_reader :menu_rows, :compact

      def before_render
        with_trigger_label { trigger_label_content }
        menu_html(render(RowsComponent.new(menu_rows: menu_rows)))
        super
      end

      def menu_row
        render(ListComponent.new(menu_rows: menu_rows))
      end

      private

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

      def compact?
        !compact.nil?
      end

      def trigger_label_content
        parts = [content_tag(:span, menu_rows.current_label, class: NAME_CLASSES.fetch(compact))]
        parts << compact_badge if compact?
        safe_join(parts)
      end

      def compact_badge
        content_tag(:span, class: BADGE_CLASSES.fetch(compact), aria: { hidden: true }) do
          initials = compact_initials
          if initials.present?
            initials
          else
            render(FlatPack::Shared::IconComponent.new(name: CompactTrigger::FALLBACK_ICON, size: :sm))
          end
        end
      end

      def compact_initials
        return if menu_rows.none_selected?

        CompactTrigger.initials(menu_rows.current_label)
      end
    end
  end
end
