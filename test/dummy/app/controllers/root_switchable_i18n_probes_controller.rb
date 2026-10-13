# frozen_string_literal: true

# Test-only probe: renders the rarely shown page_copy.device_label so the
# boot-loaded host override can be asserted on a real page without changing
# the default switch UI.
class RootSwitchableI18nProbesController < ApplicationController
  def show
    render layout: false
  end
end
