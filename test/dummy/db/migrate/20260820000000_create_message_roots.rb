# frozen_string_literal: true

class CreateMessageRoots < ActiveRecord::Migration[8.1]
  def change
    create_table :message_roots, id: :uuid do |t|
      t.string :name, null: false

      t.timestamps
    end
  end
end
