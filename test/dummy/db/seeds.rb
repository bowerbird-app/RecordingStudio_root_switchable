# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create the admin user
admin = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

viewer = User.find_or_create_by!(email: "viewer@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

workspace_names = [
  "Studio Workspace",
  "Client Alpha",
  "Client Beta",
  "Hidden Workspace"
]

root_recordings = workspace_names.index_with do |name|
  workspace = Workspace.find_or_create_by!(name: name)
  RecordingStudio::Recording.unscoped.find_or_create_by!(recordable: workspace, parent_recording_id: nil)
end

grant_access = lambda do |actor:, role:, workspace_name:|
  access = RecordingStudio::Access.find_or_create_by!(actor: actor, role: role)
  root_recording = root_recordings.fetch(workspace_name)

  RecordingStudio::Recording.unscoped.find_or_create_by!(
    parent_recording_id: root_recording.id,
    recordable: access,
    root_recording_id: root_recording.id
  )
end

Current.actor = admin
["Studio Workspace", "Client Alpha", "Client Beta"].each do |workspace_name|
  grant_access.call(actor: admin, role: :admin, workspace_name: workspace_name)
end

["Studio Workspace", "Client Alpha"].each do |workspace_name|
  grant_access.call(actor: viewer, role: :view, workspace_name: workspace_name)
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: viewer@admin.com / Password"
puts "Seeded scopes: all_workspaces, client_workspaces"
puts "Seeded roots: #{root_recordings.keys.join(', ')}"
