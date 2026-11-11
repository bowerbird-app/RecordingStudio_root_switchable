# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    # One type a scope can offer. path is the host create form, not a recording write.
    CreatableRoot = Data.define(:type_name, :label, :icon, :path, :description, :legacy)
  end
end
