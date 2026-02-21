class AddMinRoleToColumns < ActiveRecord::Migration[8.2]
  def change
    add_column :columns, :min_role, :integer, default: 0, null: false
  end
end
