# frozen_string_literal: true

class CreatePages < ActiveRecord::Migration[8.1]
  def change
    create_table :pages, id: :uuid do |t|
      t.string :title, null: false
      t.text :body, null: false, default: ""

      t.timestamps
    end
  end
end
