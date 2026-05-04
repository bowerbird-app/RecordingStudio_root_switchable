# frozen_string_literal: true

module DemoUsers
  USERS = {
    admin: {
      name: "Admin User",
      email: "admin@admin.com",
      password: "Password"
    },
    viewer: {
      name: "Viewer User",
      email: "viewer@admin.com",
      password: "Password"
    }
  }.freeze

  def self.fetch(key)
    USERS.fetch(key)
  end

  def self.all
    USERS.values
  end

  def self.primary
    fetch(:admin)
  end
end
