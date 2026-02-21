class AddViewerRestrictedToColumns < ActiveRecord::Migration[8.2]
  def change
    add_column :columns, :viewer_restricted, :boolean, default: false, null: false
  end
end
