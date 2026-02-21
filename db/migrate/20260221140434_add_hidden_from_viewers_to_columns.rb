class AddHiddenFromViewersToColumns < ActiveRecord::Migration[8.2]
  def change
    add_column :columns, :hidden_from_viewers, :boolean, default: false, null: false
  end
end
