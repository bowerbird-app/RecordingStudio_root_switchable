# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class RootSwitchablePageCopyI18nTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  HOST_OVERRIDE_LOCALE = File.expand_path(
    "../locales/root_switchable_host_override.en.yml",
    __dir__
  ).freeze

  FR_PAGE_COPY_LOCALE = File.expand_path(
    "../locales/root_switchable_page_copy.fr.yml",
    __dir__
  ).freeze

  setup do
    Rails.application.load_seed unless User.exists?(email: "admin@admin.com")
    @admin = User.find_by!(email: "admin@admin.com")
    @original_load_path = I18n.load_path.dup
    @original_locale = I18n.locale
    @original_available_locales = I18n.available_locales.dup
    @original_backend = I18n.backend
    @original_page_copy = RecordingStudioRootSwitchable.configuration.instance_variable_get(:@page_copy_overrides).dup
    I18n.available_locales = Array(I18n.available_locales) | %i[en fr]
  end

  teardown do
    I18n.load_path = @original_load_path
    I18n.locale = @original_locale
    I18n.available_locales = @original_available_locales
    I18n.backend = @original_backend
    I18n.reload!
    RecordingStudioRootSwitchable.configuration.instance_variable_set(:@page_copy_overrides, @original_page_copy)
  end

  test "root switch page renders gem English page_copy with no config" do
    sign_in(@admin)

    get "/recording_studio_root_switchable/v1/root_switch",
        params: { scope: "all_workspaces" }

    assert_response :success
    assert_includes response.body, "Switch"
    assert_includes response.body, "Current"
    refute_includes response.body, "HOST Switch"
  end

  test "root switch page follows I18n.locale per request without boot memoization" do
    sign_in(@admin)
    I18n.backend.store_translations(
      :fr,
      recording_studio: {
        root_switchable: {
          page_copy: {
            title: "Changer",
            selected_badge: "Actuel",
            switch_action_label: "Changer"
          }
        }
      }
    )

    I18n.with_locale(:en) do
      get "/recording_studio_root_switchable/v1/root_switch",
          params: { scope: "all_workspaces" }

      assert_response :success
      assert_includes response.body, "Switch"
      assert_includes response.body, "Current"
      refute_includes response.body, "Changer"
      refute_includes response.body, "Actuel"
    end

    I18n.with_locale(:fr) do
      get "/recording_studio_root_switchable/v1/root_switch",
          params: { scope: "all_workspaces" }

      assert_response :success
      assert_includes response.body, "Changer"
      assert_includes response.body, "Actuel"
    end

    I18n.with_locale(:en) do
      get "/recording_studio_root_switchable/v1/root_switch",
          params: { scope: "all_workspaces" }

      assert_response :success
      assert_includes response.body, "Switch"
      assert_includes response.body, "Current"
      refute_includes response.body, "Changer"
    end
  end

  test "host locale fixture overrides gem English page_copy on a real page" do
    sign_in(@admin)

    begin
      I18n.load_path << HOST_OVERRIDE_LOCALE
      I18n.reload!

      get "/recording_studio_root_switchable/v1/root_switch",
          params: { scope: "all_workspaces" }

      assert_response :success
      assert_includes response.body, "HOST Switch"
      assert_includes response.body, "HOST Current"
      refute_includes response.body, ">Switch<"
      refute_includes response.body, ">Current<"
    ensure
      I18n.load_path = @original_load_path.dup
      I18n.reload!
      assert_equal @original_load_path, I18n.load_path
    end
  end

  test "without the test-only host override gem English page_copy still renders" do
    sign_in(@admin)

    get "/recording_studio_root_switchable/v1/root_switch",
        params: { scope: "all_workspaces" }

    assert_response :success
    assert_includes response.body, "Switch"
    assert_includes response.body, "Current"
    refute_includes response.body, "HOST Switch"
    refute_includes response.body, "HOST Current"
    assert_equal @original_load_path, I18n.load_path
  end

  test "plain string page_copy config stays fixed across locales" do
    sign_in(@admin)
    RecordingStudioRootSwitchable.configuration.page_copy = { title: "Fixed Switch Title" }

    I18n.with_locale(:fr) do
      get "/recording_studio_root_switchable/v1/root_switch",
          params: { scope: "all_workspaces" }

      assert_response :success
      assert_includes response.body, "Fixed Switch Title"
    end
  ensure
    RecordingStudioRootSwitchable.configuration.instance_variable_set(:@page_copy_overrides, {})
  end

  test "test-only fr locale fixture renders French page_copy under each locale" do
    sign_in(@admin)
    assert File.exist?(FR_PAGE_COPY_LOCALE), "expected fr fixture at #{FR_PAGE_COPY_LOCALE}"
    refute_includes File.expand_path(FR_PAGE_COPY_LOCALE), "/config/locales/"

    begin
      I18n.load_path << FR_PAGE_COPY_LOCALE
      I18n.reload!

      I18n.with_locale(:en) do
        get "/recording_studio_root_switchable/v1/root_switch",
            params: { scope: "all_workspaces" }

        assert_response :success
        assert_select "h1", text: "Switch"
        assert_select "span", text: "Current"
        refute_includes response.body, "Changer"
        refute_includes response.body, "Actuel"
      end

      I18n.with_locale(:fr) do
        get "/recording_studio_root_switchable/v1/root_switch",
            params: { scope: "all_workspaces" }

        assert_response :success
        assert_select "h1", text: "Changer"
        assert_select "span", text: "Actuel"
        refute_includes response.body, ">Switch<"
        refute_includes response.body, ">Current<"
      end

      I18n.with_locale(:en) do
        get "/recording_studio_root_switchable/v1/root_switch",
            params: { scope: "all_workspaces" }

        assert_response :success
        assert_select "h1", text: "Switch"
        assert_select "span", text: "Current"
        refute_includes response.body, "Changer"
      end
    ensure
      I18n.load_path = @original_load_path.dup
      I18n.reload!
      assert_equal @original_load_path, I18n.load_path
    end
  end

  test "per-locale page_copy hash picks the current I18n.locale on a real page" do
    sign_in(@admin)
    RecordingStudioRootSwitchable.configuration.page_copy = {
      title: { en: "Switch EN Hash", fr: "Changer Hash" },
      selected_badge: { en: "Current EN Hash", fr: "Actuel Hash" }
    }

    I18n.with_locale(:en) do
      get "/recording_studio_root_switchable/v1/root_switch",
          params: { scope: "all_workspaces" }

      assert_response :success
      assert_includes response.body, "Switch EN Hash"
      assert_includes response.body, "Current EN Hash"
      refute_includes response.body, "Changer Hash"
      refute_includes response.body, "Actuel Hash"
    end

    I18n.with_locale(:fr) do
      get "/recording_studio_root_switchable/v1/root_switch",
          params: { scope: "all_workspaces" }

      assert_response :success
      assert_includes response.body, "Changer Hash"
      assert_includes response.body, "Actuel Hash"
      refute_includes response.body, "Switch EN Hash"
      refute_includes response.body, "Current EN Hash"
    end
  ensure
    RecordingStudioRootSwitchable.configuration.instance_variable_set(:@page_copy_overrides, {})
  end

  test "symbol page_copy key resolves at render time on a real page" do
    sign_in(@admin)
    I18n.t("my_app.root_switch.title")
    I18n.backend.store_translations(
      :en,
      my_app: { root_switch: { title: "Host Symbol EN" } }
    )
    I18n.backend.store_translations(
      :fr,
      my_app: { root_switch: { title: "Host Symbol FR" } }
    )
    RecordingStudioRootSwitchable.configuration.page_copy = {
      title: :"my_app.root_switch.title"
    }

    I18n.with_locale(:en) do
      get "/recording_studio_root_switchable/v1/root_switch",
          params: { scope: "all_workspaces" }

      assert_response :success
      assert_includes response.body, "Host Symbol EN"
      refute_includes response.body, "Host Symbol FR"
    end

    I18n.with_locale(:fr) do
      get "/recording_studio_root_switchable/v1/root_switch",
          params: { scope: "all_workspaces" }

      assert_response :success
      assert_includes response.body, "Host Symbol FR"
      refute_includes response.body, "Host Symbol EN"
    end
  ensure
    RecordingStudioRootSwitchable.configuration.instance_variable_set(:@page_copy_overrides, {})
  end

  test "callable page_copy resolves per locale on a real page" do
    sign_in(@admin)
    RecordingStudioRootSwitchable.configuration.page_copy = {
      title: ->(key:, locale:, **) { locale.to_s == "fr" ? "Callable FR" : "Callable EN" }
    }

    I18n.with_locale(:en) do
      get "/recording_studio_root_switchable/v1/root_switch",
          params: { scope: "all_workspaces" }

      assert_response :success
      assert_includes response.body, "Callable EN"
      refute_includes response.body, "Callable FR"
    end

    I18n.with_locale(:fr) do
      get "/recording_studio_root_switchable/v1/root_switch",
          params: { scope: "all_workspaces" }

      assert_response :success
      assert_includes response.body, "Callable FR"
      refute_includes response.body, "Callable EN"
    end
  ensure
    RecordingStudioRootSwitchable.configuration.instance_variable_set(:@page_copy_overrides, {})
  end
end
